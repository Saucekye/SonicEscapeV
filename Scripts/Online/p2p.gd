extends Node
## Direct connections between players (WebRTC, the same thing video calls use).
## Players still meet through the relay server (room codes, the lobby); then each
## pair of players opens a direct connection, and once everyone is connected to
## everyone, the game's messages go straight between players instead of through
## the server: quicker, and the server only has to introduce people.
## If a direct connection can't be made (some strict networks), the game simply
## keeps using the server, so nothing breaks.
##
## Browsers have WebRTC built in (the itch.io web version). Desktop builds use
## Godot's official WebRTC plugin in res://webrtc/. Created by net.gd.

## Public STUN servers: they tell each player their address as seen from the
## internet, so the two can find a way through their routers to each other
const ICE_SERVERS := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]
## Messages sent many times a second, where a lost one is better skipped than
## resent late (positions): they go on the fast, unreliable channel
const FAST_TYPES := ["st", "sv", "boss"]

signal changed   # a direct connection opened or closed

var available := true          # false if this build has no WebRTC (no plugin), or turned off
var supported := true          # this build has WebRTC at all
var _peers := {}               # id -> {"pc", "rel", "fast", "open"}
var _send_signal: Callable     # net.gd's way to pass setup messages via the server


func setup(send_signal: Callable) -> void:
	_send_signal = send_signal
	var probe := WebRTCPeerConnection.new()
	supported = probe.initialize({"iceServers": ICE_SERVERS}) == OK
	probe.close()
	available = supported and is_enabled()
	print("[Net] direct connections (WebRTC) %s" % ("on" if available else ("turned off; using the server only" if supported else "not available in this build; using the server only")))


## The ONLINE screen's "DIRECT CONNECTIONS" switch (saved in settings.cfg).
## Default: on in the web version (the browser's own WebRTC), off in desktop
## builds, where the WebRTC plugin crashed a joining player's game in the lobby
## on Windows. Turn it on there to try it.
static func default_enabled() -> bool:
	return OS.has_feature("web")


static func is_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Test.SETTINGS_PATH) == OK:
		return bool(cfg.get_value("online", "direct_connections_v2", default_enabled()))
	return default_enabled()


func set_enabled(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Test.SETTINGS_PATH)
	cfg.set_value("online", "direct_connections_v2", on)
	cfg.save(Test.SETTINGS_PATH)
	available = supported and on
	if not available:
		drop_all()
	print("[Net] direct connections turned %s" % ("on" if on else "off"))


## Start a direct connection to another player (the one already in the room
## calls the newcomer; the newcomer answers)
func call_peer(id: int) -> void:
	if not available or _peers.has(id):
		return
	_new_peer(id)
	_peers[id].pc.create_offer()


func _new_peer(id: int) -> void:
	var pc := WebRTCPeerConnection.new()
	pc.initialize({"iceServers": ICE_SERVERS})
	pc.session_description_created.connect(func(type: String, sdp: String) -> void:
		pc.set_local_description(type, sdp)
		_send_signal.call({"t": "rtc_sdp", "to": id, "type": type, "sdp": sdp}))
	pc.ice_candidate_created.connect(func(media: String, index: int, cand: String) -> void:
		_send_signal.call({"t": "rtc_ice", "to": id, "media": media, "index": index, "name": cand}))
	# Both sides make the same two channels with fixed ids, so neither has to announce them
	var rel := pc.create_data_channel("rel", {"negotiated": true, "id": 1})
	var fast := pc.create_data_channel("fast", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	_peers[id] = {"pc": pc, "rel": rel, "fast": fast, "open": false}


## A setup message from another player (passed on by the server)
func on_signal(m: Dictionary) -> void:
	if not available:
		return
	var id := int(m.get("from", 0))
	if id == 0:
		return
	if str(m.t) == "rtc_sdp":
		if not _peers.has(id):
			_new_peer(id)   # they called us: answering is automatic after this
		_peers[id].pc.set_remote_description(str(m.type), str(m.sdp))
	elif str(m.t) == "rtc_ice" and _peers.has(id):
		_peers[id].pc.add_ice_candidate(str(m.media), int(m.index), str(m.name))


func is_open(id: int) -> bool:
	return _peers.has(id) and _peers[id].open


## Direct connections to all of these players are open
func open_to_all(ids: Array) -> bool:
	if not available or ids.is_empty():
		return false
	for id in ids:
		if not is_open(int(id)):
			return false
	return true


func send_to(id: int, msg: Dictionary) -> void:
	if not is_open(id):
		return
	var ch: WebRTCDataChannel = _peers[id].fast if str(msg.get("t", "")) in FAST_TYPES else _peers[id].rel
	if ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		ch.put_packet(JSON.stringify(msg).to_utf8_buffer())


func drop(id: int) -> void:
	if _peers.has(id):
		_peers[id].pc.close()
		_peers.erase(id)
		changed.emit()


func drop_all() -> void:
	for id in _peers.keys():
		_peers[id].pc.close()
	_peers.clear()
	changed.emit()


## How many direct connections are open, out of how many players
func summary(ids: Array) -> String:
	if not available:
		return ""
	var n := 0
	for id in ids:
		if is_open(int(id)):
			n += 1
	return "%d/%d" % [n, ids.size()]


## Poll the connections; returns the messages that arrived directly
func poll() -> Array:
	var got: Array = []
	for id in _peers.keys():
		var p: Dictionary = _peers[id]
		var pc: WebRTCPeerConnection = p.pc
		pc.poll()
		var rel: WebRTCDataChannel = p.rel
		var now_open := rel.get_ready_state() == WebRTCDataChannel.STATE_OPEN \
				and pc.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED
		if now_open != p.open:
			p.open = now_open
			print("[Net] direct connection with %dP %s" % [id, "open" if now_open else "closed"])
			changed.emit()
		for ch in [p.rel, p.fast]:
			while ch.get_available_packet_count() > 0:
				var data = JSON.parse_string(ch.get_packet().get_string_from_utf8())
				if data is Dictionary:
					data["from"] = id
					got.append(data)
		if pc.get_connection_state() in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED]:
			print("[Net] direct connection with %dP failed; using the server for them" % id)
			_peers.erase(id)
			changed.emit()
	return got
