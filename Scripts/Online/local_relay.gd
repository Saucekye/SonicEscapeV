extends Node
## The relay server (server/relay.js) built into the game, for "HOST ON MY PC":
## player to player, no outside server. The host's game listens on PORT; its own
## connection and its friends' all go through here, with the same room codes and
## messages as the online relay, so the rest of the online code doesn't change.
## Friends reach it on your home network, through a virtual LAN app (Tailscale,
## Radmin VPN, ZeroTier) or, if your router allows it, over the internet: the
## port is opened on the router automatically (UPnP) when possible.
## Created by net.gd (Net.host_on_my_pc()).

signal router_result(external_ip: String)   # "" if the router wouldn't open the port

const PORT := 8080
const MAX_PLAYERS := 4
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ"   # no I or O, easy to read out

var _server := TCPServer.new()
var _clients: Array = []      # {"ws": WebSocketPeer, "room": String, "id": int}
var _rooms := {}              # code -> {"players": {id: client}, "started": bool}
var _upnp: UPNP
var _upnp_thread: Thread
var _mapped := false


## Start listening. Returns OK, or an error if the port is already taken.
func start() -> int:
	var err := _server.listen(PORT, "*")
	if err == OK:
		print("[Net] hosting on this PC, port %d" % PORT)
		_open_router_port()
	return err


func stop() -> void:
	for c in _clients:
		c.ws.close()
	_clients.clear()
	_rooms.clear()
	_server.stop()
	_close_router_port()


## This PC's addresses that friends might use (home network, Tailscale, Radmin...)
static func local_addresses() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		if a.is_valid_ip_address() and not ":" in a and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	out.sort_custom(func(x, y): return _rank(x) < _rank(y))
	return out


static func _rank(a: String) -> int:
	if a.begins_with("100."):
		return 0   # Tailscale (100.64-100.127)
	if a.begins_with("26."):
		return 1   # Radmin VPN
	if a.begins_with("192.168.") or a.begins_with("10."):
		return 2   # home network
	return 3


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 64 * 1024
		if ws.accept_stream(_server.take_connection()) == OK:
			_clients.append({"ws": ws, "room": "", "id": 0})
	for c in _clients.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var data = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if data is Dictionary:
					_on_message(c, data)
		elif state == WebSocketPeer.STATE_CLOSED:
			_on_close(c)
			_clients.erase(c)


func _send(c: Dictionary, msg: Dictionary) -> void:
	var ws: WebSocketPeer = c.ws
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func _broadcast(room: Dictionary, msg: Dictionary, except_id: int = 0) -> void:
	for id in room.players:
		if id != except_id:
			_send(room.players[id], msg)


func _new_code() -> String:
	var code := ""
	while code == "" or _rooms.has(code):
		code = ""
		for i in 4:
			code += CODE_CHARS[randi() % CODE_CHARS.length()]
	return code


func _on_message(c: Dictionary, msg: Dictionary) -> void:
	if c.room == "":
		if msg.get("t") == "host":
			var code := _new_code()
			_rooms[code] = {"players": {1: c}, "started": false}
			c.room = code
			c.id = 1
			_send(c, {"t": "room", "code": code, "id": 1})
		elif msg.get("t") == "join":
			var code := str(msg.get("code", "")).to_upper().strip_edges()
			if not _rooms.has(code):
				_send(c, {"t": "error", "msg": "No room with that code"})
				return
			var room: Dictionary = _rooms[code]
			if room.players.size() >= MAX_PLAYERS:
				_send(c, {"t": "error", "msg": "Room is full"})
				return
			if room.started:
				_send(c, {"t": "error", "msg": "That game has already started"})
				return
			var id := 2
			while room.players.has(id):
				id += 1
			room.players[id] = c
			c.room = code
			c.id = id
			_send(c, {"t": "joined", "code": code, "id": id, "ids": room.players.keys()})
			_broadcast(room, {"t": "peer_join", "id": id}, id)
		return
	if not _rooms.has(c.room):
		return
	var room: Dictionary = _rooms[c.room]
	if msg.get("t") == "start" and c.id == 1:
		room.started = true
	msg["from"] = c.id
	if msg.has("to"):
		var target = room.players.get(int(msg.to))
		if target:
			_send(target, msg)
	else:
		_broadcast(room, msg, c.id)


func _on_close(c: Dictionary) -> void:
	if not _rooms.has(c.room):
		return
	var room: Dictionary = _rooms[c.room]
	room.players.erase(c.id)
	if c.id == 1:
		# The host left: the game can't go on
		_broadcast(room, {"t": "host_left"})
		for id in room.players:
			room.players[id].ws.close()
		_rooms.erase(c.room)
	else:
		_broadcast(room, {"t": "peer_left", "id": c.id})
		if room.players.is_empty():
			_rooms.erase(c.room)


# ── Opening the port on the router (UPnP), in the background ──────────────────
func _open_router_port() -> void:
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_open)


func _upnp_open() -> void:
	var upnp := UPNP.new()
	var external := ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		var gw := upnp.get_gateway()
		if gw and gw.is_valid_gateway():
			if upnp.add_port_mapping(PORT, PORT, "Sonic Escape", "TCP") == UPNP.UPNP_RESULT_SUCCESS:
				external = upnp.query_external_address()
				_upnp = upnp
				_mapped = true
	print("[Net] router port %d %s" % [PORT, ("opened, internet address " + external) if external != "" else "not opened (no UPnP); use a virtual LAN app or forward it by hand"])
	call_deferred("emit_signal", "router_result", external)


func _close_router_port() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if _mapped and _upnp:
		_upnp.delete_port_mapping(PORT, "TCP")
	_mapped = false
	_upnp = null


func _exit_tree() -> void:
	stop()
