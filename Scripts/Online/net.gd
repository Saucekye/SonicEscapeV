extends Node
## Online multiplayer (up to 4 players; Player 1 hosts). Autoload "Net".
##
## Players meet through a small relay server (server/relay.js) using a 4-letter
## room code: the host creates a room, the others join with the code, everyone
## picks a character in the lobby (online_lobby.gd) and the host starts.
##
## How a game stays in sync:
##  - Every floor is generated from the same seed on every machine, so everyone
##    plays the same level.
##  - Each player runs their own character locally (no input lag) and sends its
##    position and animation frame ~20 times a second; the other players appear
##    as copies of their characters ("puppets") with a coloured 1P-4P tag.
##  - The host is in charge of the run: the floor ends when the host reaches the
##    goal or beats the boss, and everyone moves to the next floor together.
##    Other players who reach the goal first wait for the host.
##  - Each player has their own rings, meter and score.
##  - A player (not the host) who loses with no rings spectates the host until
##    the next floor. If the host loses, it's game over for everyone.
## Enemies, rings and bosses run separately on each machine; only the host's
## progress decides when a floor is done.

signal room_created(code: String)
signal joined_room(code: String, id: int)
signal peers_changed
signal lobby_message(msg: Dictionary)
signal net_error(text: String)
signal net_status(text: String)   # "Waking up the online server..." while it retries
signal disconnected

## Relay server address. Set this to where you deploy server/relay.js (use wss://
## for the web build on itch.io, which is served over https). Can be overridden in
## user://settings.cfg ([online] server_url) or with the SONIC_RELAY env variable.
const DEFAULT_SERVER_URL := "wss://sonic-escape-relay-cf.saucekye.workers.dev"   # the relay on Cloudflare (server/cloudflare/). Render (wss://sonic-escape-relay.onrender.com) also works in browsers. To test with one on your PC, type localhost:8080 in the lobby's SERVER box
const SEND_RATE := 20.0            # player updates per second
const GRAB_RADIUS := 60.0          # how close you need to be to grab a flying/gliding player (world px)
const FX_SKIP := ["Sprite2D", "Arrow"]   # the body itself is synced separately; the pick-up arrow isn't shown to others
const TAG_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.18, 0.18), Color(0.25, 0.9, 0.35), Color(1.0, 0.85, 0.15)]

var online := false        # true from the moment the host starts the game
var is_host := false
var my_id := 0
var room_code := ""
var peers := {}            # id -> {"char": String}
var run_seed := 0
var spectating := false
var salvage_seed := 0      # the Salvage mini game's layout, from the host (salvage.gd)
var last_error := ""       # shown by the lobby (e.g. after the host left)

var _ws: WebSocketPeer
var _ws_state := WebSocketPeer.STATE_CLOSED
var _pending: Array = []   # messages to send once connected
## Free servers (Render) sleep when unused and take up to a minute to wake, so a
## failed first connection is retried for a while before giving up
const WAKE_RETRY_SECONDS := 75.0
const RETRY_EVERY := 3.0
var _first_msg := {}       # the host/join request, sent again on each retry
var _retry_until := 0.0    # (engine time) keep retrying until then
var _retry_at := -1.0      # when to try again (-1 = not waiting)
## Some players' Godot builds fail the server's certificate check (a TLS
## handshake error, close code -1) even though browsers accept it. Retries then
## alternate with an encrypted connection that skips that check; only room codes
## and game positions go over it.
var _tls_relaxed := false
## "HOST ON MY PC" (player to player): the relay runs inside the host's game
## (local_relay.gd) and the host connects to it on this PC
const LOCAL_RELAY := preload("res://Scripts/Online/local_relay.gd")
var local_relay: Node = null
## Direct connections between players (p2p.gd, WebRTC); the server still
## introduces everyone and carries the lobby
const P2P := preload("res://Scripts/Online/p2p.gd")
var p2p: Node
## Boss fights the same for everyone (boss_sync.gd): the host runs the boss
const BOSS_SYNC := preload("res://Scripts/Online/boss_sync.gd")
var boss_sync: Node
## Always through the server: joining, the lobby and the start (the server keeps
## track of those), and the setup messages for the direct connections
const SERVER_ONLY := ["host", "join", "pick", "start", "rtc_sdp", "rtc_ice"]
var _session_url := ""     # overrides server_url() while hosting on this PC
var _send_timer := 0.0
var _puppets := {}         # id -> {"node": Node2D, "tag": Label, "target": Vector2, ...}
var _scene: Node = null
## Reaching the goal online: whoever gets there first starts a countdown for
## everyone; when it runs out, the host ends the floor and everyone moves on
const GOAL_WAIT := 10.0
var _goal_left := -1.0        # < 0: no countdown running
var _goal_by := 0
var _goal_done := false     # this floor's countdown already ran out
var _at_goal := {}            # player id -> true: who has reached the goal this floor
## Who is down on this floor (id -> true). A downed player watches the others
## until the next floor; it's game over only when everyone is down.
var _down := {}
var _over_shown := false
var _remote_over := false   # (the game over came from another player: don't send it back)
var _goal_label: Label
## Level objects shared between players (rings, enemies, Miku): every machine builds
## the same floor, so an object is named by its chunk's number and its path inside
## that chunk. While a message from another player is being applied, nothing is
## sent back (no echo).
var applying_remote := false
var _gen_cache: Node = null
var _miku_holder := 0         # another player carrying Miku (their id), or 0
var _end_allowed := false  # a client may only end a floor when the host says so
var _spectate_cam: Camera2D
var _my_tag: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep talking while paused
	p2p = P2P.new()
	p2p.name = "P2P"
	add_child(p2p)
	p2p.setup(func(m: Dictionary) -> void: _send_server(m))
	boss_sync = BOSS_SYNC.new()
	boss_sync.name = "BossSync"
	add_child(boss_sync)
	boss_sync.setup(self)
	# Game over only once every player is down (player_died); whoever goes down
	# last has the game over and tells everyone else
	GlobalSignals.game_over.connect(func(): if online and not _remote_over: send({"t": "over"}))
	GlobalSignals.complete.connect(func(): if online and is_host: send({"t": "complete"}))
	GlobalSignals.vision.connect(func(): if online and is_host: send({"t": "vision"}))


func server_url() -> String:
	if _session_url != "":
		return _session_url
	var env := OS.get_environment("SONIC_RELAY")
	if env != "":
		return env
	var cfg := ConfigFile.new()
	if cfg.load(Test.SETTINGS_PATH) == OK:
		return str(cfg.get_value("online", "server_url", DEFAULT_SERVER_URL))
	return DEFAULT_SERVER_URL


## Use another relay server from now on (the lobby's SERVER box). Saved in
## user://settings.cfg, so it's remembered. Takes what people tend to paste:
## "https://x.trycloudflare.com" or just "x.onrender.com" become wss://...,
## "http://..." becomes ws://... Empty goes back to the built-in address.
func set_server_url(url: String) -> String:
	url = url.strip_edges().trim_suffix("/")
	if url.begins_with("https://"):
		url = "wss://" + url.substr(8)
	elif url.begins_with("http://"):
		url = "ws://" + url.substr(7)
	elif url != "" and not url.begins_with("ws://") and not url.begins_with("wss://") and url.get_slice(":", 0).is_valid_ip_address():
		# Another player's PC (player to player): "100.101.102.103" or "1.2.3.4:8080"
		url = "ws://" + url + ("" if ":" in url else ":%d" % LOCAL_RELAY.PORT)
	elif url != "" and not url.begins_with("ws://") and not url.begins_with("wss://"):
		url = ("ws://" if url.begins_with("localhost") or url.begins_with("127.") else "wss://") + url
	var cfg := ConfigFile.new()
	cfg.load(Test.SETTINGS_PATH)          # keep anything else that's in there
	if url == "" or url == DEFAULT_SERVER_URL:
		if cfg.has_section_key("online", "server_url"):
			cfg.erase_section_key("online", "server_url")
	else:
		cfg.set_value("online", "server_url", url)
	cfg.save(Test.SETTINGS_PATH)
	return server_url()


# --------------------------------------------------
# CONNECTION
# --------------------------------------------------

## Player to player: run the relay in this game and host on it. Returns "" when it
## started, or what went wrong.
func host_on_my_pc() -> String:
	stop_local_relay()
	local_relay = LOCAL_RELAY.new()
	local_relay.name = "LocalRelay"
	add_child(local_relay)
	var err: int = local_relay.start()
	if err != OK:
		stop_local_relay()
		return "Couldn't host on this PC: port %d is in use (is another copy hosting?)" % LOCAL_RELAY.PORT
	_session_url = "ws://127.0.0.1:%d" % LOCAL_RELAY.PORT
	host_room()
	return ""


func hosting_on_my_pc() -> bool:
	return local_relay != null


func stop_local_relay() -> void:
	_session_url = ""
	if local_relay:
		local_relay.stop()
		local_relay.queue_free()
		local_relay = null


func host_room() -> void:
	_start({"t": "host"})


func join_room(code: String) -> void:
	_start({"t": "join", "code": code.strip_edges().to_upper()})


func _start(first: Dictionary) -> void:
	_first_msg = first
	_tls_relaxed = false
	_retry_until = _now() + WAKE_RETRY_SECONDS
	_retry_at = -1.0
	_connect()
	send(first)


## When connecting has failed: print what the game can find out about the server
## to the Output panel ([Net] lines), to tell a network problem from a server one
var _diagnosed := false
func _diagnose() -> void:
	if _diagnosed:
		return
	_diagnosed = true
	var url := server_url()
	var host := url.get_slice("://", 1).get_slice("/", 0).get_slice(":", 0)
	print("[Net] diagnose: host %s resolves to %s" % [host, IP.resolve_hostname_addresses(host)])
	print("[Net] diagnose: IPv4 only: %s" % [IP.resolve_hostname_addresses(host, IP.TYPE_IPV4)])
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var page := ("https://" if url.begins_with("wss://") else "http://") + url.get_slice("://", 1)
	http.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray) -> void:
		print("[Net] diagnose: plain request to %s -> result %d, HTTP %d, '%s'" % [page, result, code, body.get_string_from_utf8().strip_edges().left(80)])
		http.queue_free())
	var err := http.request(page)
	if err != OK:
		print("[Net] diagnose: plain request couldn't start: %s" % error_string(err))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func leave() -> void:
	stop_local_relay()
	_retry_at = -1.0
	_first_msg = {}
	if _ws:
		_ws.close()
	_reset()


func _reset() -> void:
	online = false
	is_host = false
	my_id = 0
	room_code = ""
	peers.clear()
	spectating = false
	_pending.clear()
	_clear_puppets()
	if p2p:
		p2p.drop_all()


func _connect() -> void:
	_reset()
	_ws = WebSocketPeer.new()
	# Hosting services sit behind Cloudflare and the like, which can turn away
	# connections that don't say what program they are (browsers always do)
	_ws.handshake_headers = PackedStringArray(["User-Agent: SonicEscape/1.0 (Godot)"])
	# A small "still here" every 20 s, so hosts that close quiet connections
	# (Cloudflare) don't drop a lobby where nobody is doing anything
	_ws.heartbeat_interval = 20.0
	_ws_state = WebSocketPeer.STATE_CONNECTING
	var url := server_url()
	var err: int
	if _tls_relaxed and url.begins_with("wss://"):
		err = _ws.connect_to_url(url, TLSOptions.client_unsafe())
	else:
		err = _ws.connect_to_url(url)
	print("[Net] connecting to %s%s" % [url, " (skipping the certificate check)" if _tls_relaxed else ""])
	if err != OK:
		print("[Net] connect_to_url(%s) failed: %s" % [server_url(), error_string(err)])
		net_error.emit("Couldn't reach the online server\n%s (%s)" % [server_url(), error_string(err)])
		_ws = null


func send(msg: Dictionary) -> void:
	# In the game, once everyone is directly connected: straight to the players
	if online and not str(msg.get("t", "")) in SERVER_ONLY and p2p.open_to_all(_others()):
		msg["from"] = my_id
		if msg.has("to"):
			p2p.send_to(int(msg.to), msg)
		else:
			for id in _others():
				p2p.send_to(id, msg)
		return
	_send_server(msg)


## The other players in the room
func _others() -> Array:
	var out: Array = []
	for id in peers:
		if int(id) != my_id:
			out.append(int(id))
	return out


## How the direct connections are doing, for the lobby ("" if not available)
func direct_status() -> String:
	if p2p == null or not p2p.available or _others().is_empty():
		return ""
	return p2p.summary(_others())


func _send_server(msg: Dictionary) -> void:
	if _ws == null:
		return
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))
	else:
		_pending.append(msg)


func _process(delta: float) -> void:
	if _retry_at >= 0.0 and _now() >= _retry_at and _ws == null:
		_retry_at = -1.0
		_connect()
		send(_first_msg)
	if _ws:
		_ws.poll()
		var state := _ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if _ws_state != WebSocketPeer.STATE_OPEN:
				_first_msg = {}   # connected: no more wake-up retries
				print("[Net] connected to %s%s" % [server_url(), " (without the certificate check)" if _tls_relaxed else ""])
				for m in _pending:
					_ws.send_text(JSON.stringify(m))
				_pending.clear()
			while _ws.get_available_packet_count() > 0:
				var data = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
				if data is Dictionary:
					_handle(data)
		elif state == WebSocketPeer.STATE_CLOSED and _ws_state != WebSocketPeer.STATE_CLOSED:
			var was_in_room := room_code != ""
			var why := "closed, code %d %s" % [_ws.get_close_code(), _ws.get_close_reason()]
			print("[Net] connection to %s %s (was %s)" % [server_url(), why, ["connecting", "open", "closing", "closed"][_ws_state]])
			_ws = null
			if was_in_room:
				last_error = "Lost connection to the online server"
				net_error.emit(last_error)
				_drop_to_title()
			elif not _first_msg.is_empty() and _now() < _retry_until:
				# Probably asleep (free hosting): try again in a moment
				_reset()
				_tls_relaxed = not _tls_relaxed   # (see _tls_relaxed)
				_retry_at = _now() + RETRY_EVERY
				net_status.emit("Waking up the online server...\n(this can take up to a minute)")
				_ws_state = WebSocketPeer.STATE_CLOSED
				return
			else:
				_first_msg = {}
				_diagnose()
				last_error = "Couldn't reach the online server\n%s (%s)" % [server_url(), why]
				net_error.emit(last_error)
			_reset()
			disconnected.emit()
		_ws_state = state
	if p2p:
		for m in p2p.poll():
			_handle(m)
	if online:
		_update_game(delta)


func _handle(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"room":
			room_code = m.code
			my_id = 1
			is_host = true
			peers = {1: {"char": "Sonic"}}
			room_created.emit(room_code)
			peers_changed.emit()
		"joined":
			room_code = m.code
			my_id = int(m.id)
			is_host = false
			peers.clear()
			for id in m.ids:
				peers[int(id)] = {"char": "Sonic"}
			joined_room.emit(room_code, my_id)
			peers_changed.emit()
			send({"t": "pick", "char": peers[my_id]["char"]})
		"error":
			last_error = str(m.msg)
			net_error.emit(last_error)
		"peer_join":
			peers[int(m.id)] = {"char": "Sonic"}
			peers_changed.emit()
			p2p.call_peer(int(m.id))   # open a direct connection to the newcomer
			# Tell the newcomer what we picked
			if peers.has(my_id):
				send({"t": "pick", "char": peers[my_id]["char"]})
		"pick":
			var who := int(m.get("from", 0))
			if peers.has(who):
				peers[who]["char"] = str(m.char)
				peers_changed.emit()
		"start":
			if not is_host:
				_begin(int(m.seed), m.picks)
		"rtc_sdp", "rtc_ice":
			p2p.on_signal(m)
		"peer_left":
			var id := int(m.id)
			p2p.drop(id)
			peers.erase(id)
			_remove_puppet(id)
			peers_changed.emit()
		"host_left":
			last_error = "The host left the game"
			net_error.emit(last_error)
			_ws.close()
			_drop_to_title()
		"goal":
			_at_goal[int(m.get("from", 0))] = true
			_start_goal_countdown(int(m.get("from", 0)))
			_check_everyone_at_goal()
		"obj":
			_on_obj(m)
		"miku":
			_on_miku(m)
		"boss":
			boss_sync.on_snapshot(m)
		"bhit":
			boss_sync.on_hit(m)
		"st":
			_on_state(m)
		"next":
			_on_next(m)
		"over":
			if online and not _over_shown:
				_over_shown = true
				_remote_over = true
				GlobalSignals.game_over.emit()
				_remote_over = false
		"down":
			_down[int(m.get("from", 0))] = true
			_check_everyone_at_goal()   # (the rest may all be at the goal already)
		"complete":
			if online and not is_host:
				GlobalSignals.complete.emit()
		"vision":
			# The host chose Watch Vision at the rest tree: everyone watches it,
			# starting at the same moment as the host (tree.gd waits ~3.3 s)
			if online and not is_host:
				GlobalSignals.vision.emit()
				get_tree().create_timer(3.3).timeout.connect(func() -> void:
					if online:
						get_tree().change_scene_to_file("res://FinalCutscene/vision.tscn"))
		"endless":
			# The host picked Continue on the results screen: on to the next floor together
			if online and not is_host:
				Test.level = int(m.get("level", 24))
				get_tree().change_scene_to_file("res://Scenes/Level/test3.tscn")
		"salvage":
			# The host picked Salvage at the rest tree: everyone goes in together
			if online and not is_host:
				salvage_seed = int(m.seed)
				_go_salvage()
		_:
			lobby_message.emit(m)


## Host: take everyone into the Salvage mini game (Scenes/Salvage/salvage.gd)
func start_salvage() -> void:
	if not online or not is_host:
		return
	salvage_seed = randi()
	send({"t": "salvage", "seed": salvage_seed})
	_go_salvage()


func _go_salvage() -> void:
	# Static, a title card, then in (Scenes/Salvage/salvage_transition.gd)
	preload("res://Scenes/Salvage/salvage_transition.gd").go(get_tree())


func _drop_to_title() -> void:
	# Back to the online menu, which shows last_error
	var was_playing := online
	_reset()
	if was_playing:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/Menu/online_lobby.tscn")


# --------------------------------------------------
# STARTING A GAME
# --------------------------------------------------

## Host: start the run for everyone
func start_game() -> void:
	if not is_host:
		return
	run_seed = randi() % 1000000 + 1
	var picks := {}
	for id in peers:
		picks[str(id)] = peers[id]["char"]
	send({"t": "start", "seed": run_seed, "picks": picks})
	_begin(run_seed, picks)


## Everyone: set up the run and go to the first floor
func _begin(seed_value: int, picks: Dictionary) -> void:
	run_seed = seed_value
	for k in picks:
		if peers.has(int(k)):
			peers[int(k)]["char"] = str(picks[k])
	online = true
	spectating = false
	Test.characterone = str(peers[my_id]["char"]) if peers.has(my_id) else "Sonic"
	Test.charactertwo = ""
	Test.characterthree = ""
	Test.current_character_index = 0
	Test.rings = 0
	Test.meter = 100
	Test.mikus_saved = 0
	Test.tricks_done = 0
	Test.elapsed_sesion_time = 0.0
	Test.level = 0
	Test.boss_rotation_order = []
	get_tree().change_scene_to_file("res://Scenes/Level/test3.tscn")


## Seed for this floor: the same on every machine
func floor_seed() -> int:
	var lg = load("res://Scripts/Level/level_generator.gd")
	var rest_visit := 1 if lg.rest_done_level != Test.level else 0
	return run_seed * 1000 + Test.level * 2 + rest_visit


## Change our character in the lobby
func pick(char_name: String) -> void:
	if peers.has(my_id):
		peers[my_id]["char"] = char_name
		peers_changed.emit()
	send({"t": "pick", "char": char_name})


# --------------------------------------------------
# FLOOR CHANGES (the host decides)
# --------------------------------------------------

## Random numbers that come out the same for every player on this floor (online),
## e.g. which Miku or OC appears. Offline: just random.
func shared_rng(what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	if online:
		r.seed = hash([floor_seed(), what])
	else:
		r.randomize()
	return r


## The host chose Continue on the results screen (after beating the game):
## everyone goes on to the next floor
func endless_continue() -> void:
	if online and is_host:
		send({"t": "endless", "level": Test.level})


## Called by the level-end fade (Scripts/Obstacles/Goal/results.gd) when a floor
## ends. Returns false if this player has to wait for the host instead.
func floor_ended() -> bool:
	if not online:
		return true
	if is_host:
		var lg = load("res://Scripts/Level/level_generator.gd")
		send({"t": "next", "level": Test.level, "rest_done": lg.rest_done_level,
				"rest": Test.rest, "final": Test.final, "rot": Test.boss_rotation_order})
		return true
	if _end_allowed:
		_end_allowed = false
		return true
	return false


func _on_next(m: Dictionary) -> void:
	if not online or is_host:
		return
	var lg = load("res://Scripts/Level/level_generator.gd")
	Test.level = int(m.level)
	lg.rest_done_level = int(m.rest_done)
	Test.rest = bool(m.rest)
	Test.final = bool(m.final)
	Test.boss_rotation_order = Array(m.rot)
	_end_allowed = true
	Test.end = true


# --------------------------------------------------
# IN GAME: SENDING OUR PLAYER, SHOWING THE OTHERS
# --------------------------------------------------

func _local_player() -> Node2D:
	var pc := _scene.find_child("PlayerController", true, false) if _scene else null
	if pc and pc.get("current_character"):
		return pc.current_character
	return null


func _update_game(delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _scene:
		_scene = cs
		_puppets.clear()   # the old scene freed them
		_goal_left = -1.0
		_goal_done = false
		_at_goal.clear()
		_down.clear()
		_over_shown = false
		_goal_label = null
		_gen_cache = null
		_miku_holder = 0
		_spectate_cam = null
		_my_tag = null
		spectating = false
	if _scene == null or not _scene.scene_file_path.ends_with("test3.tscn"):
		return
	var me := _local_player()
	# Our own tag, so you can tell which character is you
	if me:
		if _my_tag == null or not is_instance_valid(_my_tag):
			_my_tag = _new_tag(my_id)
		_my_tag.visible = me.visible and not spectating
		_my_tag.global_position = me.global_position + Vector2(-_my_tag.size.x * 0.5, -150.0)
	# Send our player
	_send_timer -= delta
	if me and _send_timer <= 0.0:
		_send_timer = 1.0 / SEND_RATE
		var sp := me.get_node_or_null("Sprite2D") as Sprite2D
		if sp and sp.texture:
			send({"t": "st", "l": Test.level, "x": snappedf(me.global_position.x, 0.1), "y": snappedf(me.global_position.y, 0.1),
					"r": snappedf(me.rotation, 0.01), "tx": sp.texture.resource_path, "h": sp.hframes, "v": sp.vframes,
					"f": sp.frame, "fh": sp.flip_h, "px": sp.position.x, "py": sp.position.y, "sx": sp.scale.x, "sy": sp.scale.y,
					"sr": snappedf(sp.rotation, 0.01), "vis": me.visible and not spectating, "fx": _visible_effects(me),
					"fl": bool(me.get("flying"))})   # flying or gliding: others can grab on
	_update_goal_countdown(delta)
	_update_carried_miku()
	boss_sync.update(delta)
	# Move the puppets smoothly towards their latest positions
	for id in _puppets:
		var p: Dictionary = _puppets[id]
		var node: Node2D = p.node
		if not is_instance_valid(node):
			continue
		node.global_position = node.global_position.lerp(p.target, clampf(delta * 15.0, 0.0, 1.0))
		if node.global_position.distance_to(p.target) > 600.0:
			node.global_position = p.target
		if p.has("grab") and is_instance_valid(p.grab):
			p.grab.global_position = node.global_position
		var tag: Label = p.tag
		tag.visible = node.visible
		tag.global_position = node.global_position + Vector2(-tag.size.x * 0.5, -150.0)
	# Spectating: the camera follows the host
	if spectating and _spectate_cam:
		var watch := _watch_target()
		if watch:
			_spectate_cam.global_position = watch.global_position


## The character's effect sprites showing right now (swipe, boost, parry...), as
## [name, frame, alpha]. The copies on other screens only show these.
func _visible_effects(me: Node2D) -> Array:
	var out := []
	for c in _effect_nodes(me):
		var ci := c as CanvasItem
		if ci.is_visible_in_tree() and ci.modulate.a * ci.self_modulate.a > 0.05:
			out.append([str(me.get_path_to(c)), int(c.get("frame")), snappedf(ci.modulate.a, 0.05)])
	return out


## A character's effect sprites: the ones beside its body sprite, and the ones
## attached to the body sprite itself (like Tails' swipe ring, Sprite2D/Effect)
func _effect_nodes(character: Node) -> Array:
	var out := []
	for c in character.get_children():
		if (c is Sprite2D or c is AnimatedSprite2D) and not c.name in FX_SKIP:
			out.append(c)
	var body := character.get_node_or_null("Sprite2D")
	if body:
		for c in body.get_children():
			if c is Sprite2D or c is AnimatedSprite2D:
				out.append(c)
	return out


func _on_state(m: Dictionary) -> void:
	if not online or _scene == null or not _scene.scene_file_path.ends_with("test3.tscn"):
		return
	var id := int(m.from)
	if int(m.get("l", -1)) != Test.level:
		_remove_puppet(id)   # they're on another floor (loading, or waiting)
		return
	if not _puppets.has(id):
		if not _make_puppet(id):
			return
	var p: Dictionary = _puppets[id]
	var node: Node2D = p.node
	p.target = Vector2(float(m.x), float(m.y))
	# Flying or gliding: hold up next to them to grab on (player_base.gd's hang)
	node.set("flying", bool(m.get("fl", false)) and bool(m.vis))
	node.rotation = float(m.r)
	node.visible = bool(m.vis)
	var sp := node.get_node_or_null("Sprite2D") as Sprite2D
	if sp:
		var tex_path := str(m.tx)
		if sp.texture == null or sp.texture.resource_path != tex_path:
			if ResourceLoader.exists(tex_path):
				sp.texture = load(tex_path)
		sp.hframes = maxi(1, int(m.h))
		sp.vframes = maxi(1, int(m.v))
		sp.frame = clampi(int(m.f), 0, sp.hframes * sp.vframes - 1)
		sp.flip_h = bool(m.fh)
		sp.position = Vector2(float(m.px), float(m.py))
		sp.scale = Vector2(float(m.sx), float(m.sy))
		sp.rotation = float(m.sr)
	# Effect sprites: only the ones the player's own screen is showing
	var shown := {}
	for e in m.get("fx", []):
		shown[str(e[0])] = e
	for c in _effect_nodes(node):
		var ci := c as CanvasItem
		var key := str(node.get_path_to(c))
		if shown.has(key):
			var e: Array = shown[key]
			ci.visible = true
			ci.modulate.a = float(e[2])
			c.set("frame", int(e[1]))
		else:
			ci.visible = false


func _make_puppet(id: int) -> bool:
	var char_name: String = peers[id]["char"] if peers.has(id) else "Sonic"
	var scene := Content.character_scene(char_name)
	if scene == null:
		scene = Content.characters()[0].scene
	var node := scene.instantiate() as Node2D
	# Just for show: no physics, no scripts running, no collisions
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject2D:
		(node as CollisionObject2D).collision_layer = 0
		(node as CollisionObject2D).collision_mask = 0
	for g in node.get_groups():
		node.remove_from_group(g)
	# Nothing but the character itself until the player's updates say otherwise
	# (effect sprites are saved in whatever state the editor left them)
	# (anything drawn that isn't the body: effects, homing reticle, meters, arrows...)
	for c in node.find_children("*", "CanvasItem", true, false):
		if c.name != "Sprite2D" or c.get_parent() != node:
			(c as CanvasItem).visible = false
	node.scale = Vector2(125, 125)
	node.z_index = 5
	node.name = "OnlinePlayer%d" % id
	_scene.add_child(node)
	var tag := _new_tag(id)
	# Something to grab when they fly or glide. (The copy itself is paused, which
	# takes its own hitbox out of the physics, so it gets this small area instead.
	# Its own group, so rings and enemies don't take it for a real player.)
	var grab := Area2D.new()
	grab.name = "OnlineGrab%d" % id
	grab.add_to_group("net_grab")
	grab.set_meta("puppet", node)
	grab.monitoring = false
	grab.monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GRAB_RADIUS
	shape.shape = circle
	grab.add_child(shape)
	_scene.add_child(grab)
	_puppets[id] = {"node": node, "tag": tag, "target": Vector2.ZERO, "grab": grab}
	return true


func _remove_puppet(id: int) -> void:
	if not _puppets.has(id):
		return
	var p: Dictionary = _puppets[id]
	if is_instance_valid(p.node):
		p.node.queue_free()
	if is_instance_valid(p.tag):
		p.tag.queue_free()
	if p.has("grab") and is_instance_valid(p.grab):
		p.grab.queue_free()
	_puppets.erase(id)


func _clear_puppets() -> void:
	for id in _puppets.keys():
		_remove_puppet(id)


## A coloured "1P".."4P" label over a character
func _new_tag(id: int) -> Label:
	var tag := Label.new()
	tag.text = "%dP" % id
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 40)
	tag.add_theme_color_override("font_color", TAG_COLORS[clampi(id - 1, 0, 3)])
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tag.add_theme_constant_override("outline_size", 12)
	tag.size = Vector2(120, 56)
	tag.z_index = 110
	tag.z_as_relative = false
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(tag)
	return tag


# --------------------------------------------------
# SPECTATING (a player, not the host, ran out of rings)
# --------------------------------------------------

## Called by player_base.gd instead of a game over. Returns true if handled.
func player_died(player: Node2D) -> bool:
	if not online:
		return false
	_down[my_id] = true
	send({"t": "down"})
	if _all_down():
		_over_shown = true
		return false   # everyone's down: the normal death and game over (sent to all)
	spectating = true
	_check_everyone_at_goal()
	player.visible = false
	player.set_physics_process(false)
	if player is CollisionObject2D:
		(player as CollisionObject2D).collision_layer = 0
	# Take the camera away from our character and follow the host
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		for c in player.get_children():
			if c is Camera2D:
				cam = c
	if cam:
		var gp := cam.global_position
		cam.reparent(_scene)
		cam.global_position = gp
		cam.process_mode = Node.PROCESS_MODE_ALWAYS
		_spectate_cam = cam
	_show_banner("YOU'RE DOWN - watching your team, back in on the next floor")
	return true


func _all_down() -> bool:
	for id in peers:
		if not _down.has(int(id)):
			return false
	return true


## While down: the first player still playing (the host if they're up)
func _watch_target() -> Node2D:
	var ids := _puppets.keys()
	ids.sort()
	for id in ids:
		if not _down.has(int(id)) and is_instance_valid(_puppets[id].node):
			return _puppets[id].node
	for id in ids:
		if is_instance_valid(_puppets[id].node):
			return _puppets[id].node
	return null


func _show_banner(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	_scene.add_child(layer)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1600, 60)
	l.position = Vector2(0, 600)
	layer.add_child(l)


# --------------------------------------------------
# SHARED LEVEL OBJECTS: RINGS, ENEMIES, MIKU
# --------------------------------------------------

func _level_gen() -> Node:
	if _gen_cache and is_instance_valid(_gen_cache):
		return _gen_cache
	if _scene == null:
		return null
	for n in _scene.find_children("*", "Node2D", true, false):
		var sc: Script = n.get_script()
		if sc and sc.resource_path.ends_with("level_generator.gd"):
			_gen_cache = n
			return n
	return null


## A name for a level object that's the same on every player's machine
func obj_id(node: Node) -> String:
	var gen := _level_gen()
	if gen and "chunks" in gen:
		var chunks: Array = gen.chunks
		for i in chunks.size():
			var c = chunks[i]
			if is_instance_valid(c) and c.is_ancestor_of(node):
				return "c%d:%s" % [i, c.get_path_to(node)]
	return "s:%s" % _scene.get_path_to(node) if _scene else ""


func _obj(id: String) -> Node:
	if _scene == null:
		return null
	if id.begins_with("c"):
		var gen := _level_gen()
		if gen == null or not "chunks" in gen:
			return null
		var i := int(id.substr(1, id.find(":") - 1))
		var chunks: Array = gen.chunks
		if i < 0 or i >= chunks.size() or not is_instance_valid(chunks[i]):
			return null
		return chunks[i].get_node_or_null(NodePath(id.substr(id.find(":") + 1)))
	return _scene.get_node_or_null(NodePath(id.substr(2)))


## This machine collected a ring / defeated an enemy: it goes for everyone.
## (kind: "ring" or "enemy"; the object's net_remove() does it on the others.)
func obj_gone(node: Node, kind: String) -> void:
	if not online or applying_remote or not is_instance_valid(node):
		return
	send({"t": "obj", "k": kind, "id": obj_id(node)})


func _on_obj(m: Dictionary) -> void:
	var n := _obj(str(m.get("id", "")))
	if n and n.has_method("net_remove"):
		applying_remote = true
		n.net_remove(str(m.get("k", "")))
		applying_remote = false


## Miku (or an OC in her place): picked up, thrown, dropped, saved or knocked off
## on this machine. e: "held", "throw", "free", "saved", "lost".
func miku_event(miku: Node2D, e: String, extra: Dictionary = {}) -> void:
	if not online or applying_remote or not is_instance_valid(miku):
		return
	if miku.has_meta("net_remote_throw"):
		miku.remove_meta("net_remote_throw")   # ours now
	var msg := {"t": "miku", "e": e, "x": snappedf(miku.global_position.x, 0.1), "y": snappedf(miku.global_position.y, 0.1)}
	msg.merge(extra)
	send(msg)


func _miku_node() -> Node2D:
	if _scene == null:
		return null
	var saved := preload("res://Scripts/Effects/miku_saved.gd")
	# (only a real Miku / OC: anything else in those groups doesn't have her script)
	for n in get_tree().get_nodes_in_group("item") + get_tree().get_nodes_in_group("Miku"):
		if n is Node2D and saved.is_rescue(n) and "is_being_held" in n and not n.is_queued_for_deletion():
			return n
	var gen := _level_gen()
	if gen:
		for n in gen.get_children():
			if n is Node2D and saved.is_rescue(n) and "is_being_held" in n and not n.is_queued_for_deletion():
				return n
	return null


func _on_miku(m: Dictionary) -> void:
	var miku := _miku_node()
	if miku == null:
		return
	applying_remote = true
	match str(m.get("e", "")):
		"held":
			_miku_holder = int(m.get("from", 0))
			if miku.has_meta("net_remote_throw"):
				miku.remove_meta("net_remote_throw")
			miku.set("is_being_held", true)
			miku.set("velocity", Vector2.ZERO)
			miku.set("is_spinning", false)
			miku.rotation = 0.0
			if miku.has_method("set_item_group"):
				miku.set_item_group(false)   # nobody else can pick her up while she's carried
		"free", "throw":
			_miku_holder = 0
			miku.global_position = Vector2(float(m.x), float(m.y))
			if miku.has_method("enable_physics"):
				miku.enable_physics()
			if str(m.e) == "throw":
				# Another player threw her: she only hurts a boss on THEIR screen
				# (that hit reaches everyone through the boss sync); here she just bounces off
				miku.set_meta("net_remote_throw", true)
				miku.velocity = Vector2(float(m.get("vx", 0)), float(m.get("vy", 0)))
				if miku.has_method("start_spinning"):
					miku.start_spinning(Vector2(float(m.get("dx", 1)), float(m.get("dy", 0))))
		"saved":
			_miku_holder = 0
			preload("res://Scripts/Effects/miku_saved.gd").save(miku)
		"lost":
			_miku_holder = 0
			if miku.has_method("knock_off"):
				miku.set("spawn_safe", 0.0)
				miku.knock_off(float(m.get("d", 1)))
	applying_remote = false


## Another player is carrying Miku: keep her with their character on this screen
func _update_carried_miku() -> void:
	if _miku_holder == 0 or not _puppets.has(_miku_holder):
		return
	var miku := _miku_node()
	var holder = _puppets[_miku_holder].node
	if miku and is_instance_valid(holder):
		miku.global_position = holder.global_position + Vector2(0, -30)


## A player on this machine touched the goal (goal.gd). Online, that starts the
## countdown for everyone. Returns true when online (the countdown takes over).
func goal_reached() -> bool:
	if not online:
		return false
	if not _at_goal.has(my_id) and not _goal_done:
		_at_goal[my_id] = true
		_start_goal_countdown(my_id)
		send({"t": "goal"})   # (everyone counts who's there)
		_check_everyone_at_goal()
	return true


## Everyone still playing has reached the goal: no need to wait, next floor now
func _check_everyone_at_goal() -> void:
	if _goal_left < 0.0 or _goal_done:
		return
	for id in peers:
		if not _at_goal.has(int(id)) and not _down.has(int(id)):
			return
	_goal_left = 0.0
	_update_goal_countdown(0.0)


func _start_goal_countdown(by: int) -> void:
	if _goal_left >= 0.0 or _goal_done or _scene == null:
		return
	_goal_left = GOAL_WAIT
	_goal_by = by
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "NetGoalCountdown"
	_scene.add_child(layer)
	_goal_label = Label.new()
	_goal_label.add_theme_font_size_override("font_size", 36)
	_goal_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_goal_label.add_theme_constant_override("outline_size", 10)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.size = Vector2(1600, 120)
	_goal_label.position = Vector2(0, 560)
	layer.add_child(_goal_label)
	_update_goal_countdown(0.0)


func _update_goal_countdown(delta: float) -> void:
	if _goal_left < 0.0:
		return
	_goal_left -= delta
	if is_instance_valid(_goal_label):
		var who := "YOU" if _goal_by == my_id else "%dP" % _goal_by
		_goal_label.add_theme_color_override("font_color", TAG_COLORS[(_goal_by - 1) % 4] if _goal_by > 0 else Color.WHITE)
		_goal_label.text = "%s REACHED THE GOAL!\n%d" % [who, maxi(ceili(_goal_left), 0)]
	if _goal_left <= 0.0:
		_goal_left = -1.0
		_goal_done = true
		if is_instance_valid(_goal_label):
			_goal_label.text = "NEXT FLOOR..."
		if is_host:
			_finish_floor()


## Host: the countdown ran out, end the floor (as if the host reached the goal)
func _finish_floor() -> void:
	for g in get_tree().get_nodes_in_group("goal"):
		if g.has_method("finish_level"):
			g.finish_level()
			return
	Test.end = true
	if not Test.rest and not Test.final:
		Test.level += 1


## Shown when a client reaches the goal before the host
func show_waiting() -> void:
	if _scene and not _scene.has_node("NetWaiting"):
		_show_banner("WAITING FOR 1P")
		_scene.get_child(_scene.get_child_count() - 1).name = "NetWaiting"
