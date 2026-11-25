extends Node
# How a Salvage visit plays out, like a horror film

var game: Node3D

const SLENDER := preload("res://Scenes/Salvage/slender.gd")
const FREDDY := preload("res://Scenes/Salvage/freddy.gd")
const TAILS_DOLL := preload("res://Scenes/Salvage/tails_doll.gd")
const ROOM := preload("res://Scenes/Salvage/room.gd")
const MX := preload("res://Scenes/Salvage/mx.gd")
const MIMIC := preload("res://Scenes/Salvage/mimic.gd")
const SPIDER := preload("res://Scenes/Salvage/spider.gd")

var _hum: AudioStreamPlayer
var _dread: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _beat_in := 0.0
var _event_in := -1.0
var _quiet := 0.0               # 0..1: how far everything has dropped out
var _last_seen := {}            # hunter -> when a local player last saw it
var _stung_at := {}             # hunter -> when it last got the sting
var _loops := {}                # hunter -> its own sound, following it around
var _cue_in := {}               # hunter -> seconds until its next sound cue
var _steps: Dictionary = {}     # footsteps behind you, while they're happening
var _last_kind := ""
var _was := {}                  # Bracken -> what it was doing last frame
var _angry := {}                # Bracken -> its angry sound, while it's coming for you
var _hissed := {}               # Bracken -> when it last hissed
const BRACKEN := preload("res://Scenes/Salvage/bracken.gd")
var _gone := false
var _maze_time := 0.0           # seconds since someone here first went down into the maze


func setup(game_node: Node3D) -> void:
	game = game_node
	_hum = _loop_player(game.dread_hum)
	_dread = _loop_player(game.dread_layer)
	_heart = AudioStreamPlayer.new()
	_heart.stream = game.dread_heartbeat
	_heart.bus = _bus()
	add_child(_heart)
	_hum.volume_db = -80.0
	_dread.volume_db = -80.0
	if _hum.stream:
		_hum.play(randf() * _hum.stream.get_length())
	if _dread.stream:
		_dread.play(randf() * _dread.stream.get_length())


func _process(delta: float) -> void:
	if game == null or game.dread_volume <= 0.0:
		_set_vol(_hum, 0.0)
		_set_vol(_dread, 0.0)
		return
	if game.leaving:
		_fade_out(delta)
		return
	# Up on the deck it's just the deck
	var below := _anyone_below()
	if below or _maze_time > 0.0:
		_maze_time += delta
	var t: float = _maze_time - game.dread_silent_for
	var amb := clampf(t / 8.0, 0.0, 1.0) if below else 0.0   # the hum fades in over 8 seconds
	# How far along the film are we
	var start: float = game.dread_calm_time
	var unease := clampf((t - start) / maxf(game.first_hunter_after - start, 1.0), 0.0, 1.0)
	var hunters := _hunters_out()
	if not hunters.is_empty():
		unease = 1.0
	if not below:
		unease = 0.0
	var near := _nearest_hunter(hunters)          # [hunter, distance, seen now]
	var fear := 0.0
	if near[0] != null:
		fear = clampf(1.0 - float(near[1]) / game.dread_heartbeat_distance, 0.0, 1.0)
	# Too quiet: one's close and you haven't seen it
	var want_quiet := 1.0 if near[0] != null and not near[2] and float(near[1]) < game.dread_quiet_distance else 0.0
	_quiet = move_toward(_quiet, want_quiet, delta * (0.6 if want_quiet > 0.0 else 2.5))
	var duck := 1.0 - 0.8 * _quiet
	_set_vol(_hum, game.dread_volume * game.dread_hum_volume * duck * amb)
	_set_vol(_dread, game.dread_volume * game.dread_layer_volume * clampf(unease * 0.5 + fear * 0.7 + (0.2 if not hunters.is_empty() and below else 0.0), 0.0, 1.0) * duck * (amb if fear <= 0.0 else 1.0))
	_dread.pitch_scale = lerpf(1.0, 0.85, fear)
	_heartbeat(delta, fear)
	_check_sightings(hunters)
	_hunter_cues(delta, hunters)
	_footsteps(delta)
	# Things that happen
	if below and unease > 0.0 and t > start:
		if _event_in < 0.0:
			_event_in = randf_range(2.0, 6.0)
		_event_in -= delta
		if _event_in <= 0.0:
			var every: Vector2 = game.dread_events_every.lerp(game.dread_events_every_late, unease)
			_event_in = randf_range(every.x, every.y)
			if _quiet < 0.5:
				_happen(unease)


# THE BUILDING

func _happen(unease: float) -> void:
	var p = _someone()
	if p == null:
		return
	# Early on just noises far off
	var kinds := ["knock", "creak", "creak", "knock", "slam"]
	if unease > 0.3:
		kinds += ["whisper", "steps", "lights"]
	if unease > 0.6:
		kinds += ["whisper", "steps", "music_box", "lights"]
	kinds.erase(_last_kind)   # never the same thing twice running
	var kind: String = kinds[randi() % kinds.size()]
	_last_kind = kind
	match kind:
		"knock":
			_at(_pick(game.dread_knocks), _around(p, 10.0, 18.0), 0.8)
		"creak":
			_at(_pick(game.dread_creaks), _around(p, 8.0, 16.0), 0.7, randf_range(0.8, 1.15))
		"slam":
			_at(game.dread_slam, _around(p, 16.0, 24.0), 0.9)
		"whisper":
			_at(_pick(game.dread_whispers), _behind(p, 1.6), 0.6, randf_range(0.85, 1.05))
		"steps":
			if _steps.is_empty() and not game.top_down:
				_steps = {"p": p, "at": _behind(p, 7.0), "left": randi_range(4, 7), "next": 0.0}
		"lights":
			game._dip_left = maxf(game._dip_left, game.dread_lights_out_time)
			_flat(game.dread_lights_out, 0.6)
		"music_box":
			_at(game.dread_music_box, _around(p, 14.0, 22.0), 0.6, randf_range(0.9, 1.0))


# Someone's walking up behind you
func _footsteps(delta: float) -> void:
	if _steps.is_empty():
		return
	var p = _steps.p
	if not is_instance_valid(p) or p.dead:
		_steps = {}
		return
	_steps.next -= delta
	if _steps.next > 0.0:
		return
	var at: Vector3 = _steps.at
	var to: Vector3 = at - p.head.global_position
	if (-p.head.global_transform.basis.z).dot(to.normalized()) > 0.2:
		_steps = {}   # you looked
		return
	_at(_pick(game.dread_steps), at, 0.75, randf_range(0.9, 1.05))
	# ...a little closer each time
	_steps.at = p.head.global_position + (at - p.head.global_position) * 0.82
	_steps.left -= 1
	_steps.next = randf_range(0.55, 0.7)
	if _steps.left <= 0:
		_steps = {}


# THE HUNTERS

func _hunters_out() -> Array:
	var out: Array = []
	for m in game.monsters:
		if is_instance_valid(m) and m.visible and _shown_here(m):
			out.append(m)
	return out


# Tails Doll is only there for whoever it's haunting
func _shown_here(m) -> bool:
	if m.get("disguised"):
		return false
	if m is MIMIC and m.state != m.ANGRY:
		return false
	return not (m is TAILS_DOLL) or m.layers != 0


# The closest one to any of our players
func _nearest_hunter(hunters: Array) -> Array:
	var best = null
	var best_d := INF
	var seen := false
	for m in hunters:
		for p in game.players:
			if p.dead:
				continue
			var d: float = p.head.global_position.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = m
				seen = _seen_by_us(m)
	return [best, best_d, seen]


func _seen_by_us(m) -> bool:
	for i in game.players.size():
		var w = game.watchers.get("local%d" % i)
		if w and not game.players[i].dead and m._sees_me(w):
			return true
	return false


# The first good look at one
func _check_sightings(hunters: Array) -> void:
	var now: float = game.time
	for m in hunters:
		if not _seen_by_us(m):
			continue
		var fresh: bool = now - float(_last_seen.get(m, -100.0)) > 3.0
		_last_seen[m] = now
		if fresh and now - float(_stung_at.get(m, -100.0)) > game.dread_sting_cooldown:
			_stung_at[m] = now
			if not game.dread_stings.is_empty():
				_flat(_pick(game.dread_stings), 1.0)
				_quiet = 0.0
			for p in game.players:
				if not p.dead:
					p.add_shake(0.35 * game.camera_shake)


func _heartbeat(delta: float, fear: float) -> void:
	if fear <= 0.0 or _heart.stream == null:
		_beat_in = 0.0
		return
	_beat_in -= delta
	if _beat_in <= 0.0:
		_beat_in = lerpf(1.3, 0.36, fear)   # faster the closer it is
		_heart.volume_db = linear_to_db(clampf(fear * 1.6, 0.08, 1.4) * game.dread_volume * game.dread_heartbeat_volume)
		_heart.play()


# Each hunter gives itself away before you see it
func _hunter_cues(delta: float, hunters: Array) -> void:
	for m in _loops.keys():
		if not is_instance_valid(m) or not hunters.has(m):
			if is_instance_valid(_loops[m]):
				_loops[m].queue_free()
			_loops.erase(m)
	for m in hunters:
		# Slender Man hums like a bad power line, all the time
		if m is SLENDER and not _loops.has(m) and game.dread_slender_hum:
			var s := AudioStreamPlayer3D.new()
			s.stream = _looping(game.dread_slender_hum)
			s.bus = _bus()
			s.unit_size = 4.0
			s.max_distance = game.dread_heartbeat_distance * 1.5
			s.volume_db = linear_to_db(game.dread_volume)
			m.add_child(s)
			s.position = Vector3(0, m.height * 0.6, 0)
			s.play()
			_loops[m] = s
		# Freddy's music box plays from him the whole time he's out, and stops dead
		if m is FREDDY and game.freddy_music_box:
			if not _loops.has(m):
				var mb := AudioStreamPlayer3D.new()
				mb.stream = _looping(game.freddy_music_box)
				mb.bus = _bus()
				mb.unit_size = 5.0
				mb.max_distance = game.dread_heartbeat_distance * 2.0
				mb.volume_db = -80.0
				m.add_child(mb)
				mb.position = Vector3(0, m.height * 0.8, 0)
				mb.play()
				_loops[m] = mb
			var box: AudioStreamPlayer3D = _loops[m]
			var want: float = 0.0001 if _seen_by_us(m) else game.dread_volume * game.freddy_music_box_volume
			box.volume_db = move_toward(box.volume_db, linear_to_db(want), delta * (200.0 if want < 0.001 else 12.0))
		# ROOM's theme plays from it, louder the closer it is
		if m is ROOM and game.room_theme and not _loops.has(m):
			var th := AudioStreamPlayer3D.new()
			th.stream = _looping(game.room_theme)
			th.bus = _bus()
			th.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			th.max_distance = game.room_hear_distance
			m.add_child(th)
			th.position = Vector3(0, m.height * 0.6, 0)
			th.play()
			_loops[m] = th
		if m is ROOM and _loops.has(m):
			var th: AudioStreamPlayer3D = _loops[m]
			var near := INF
			for p in game.players:
				if not p.dead:
					near = minf(near, p.head.global_position.distance_to(m.global_position))
			var k := clampf(1.0 - near / game.room_hear_distance, 0.0, 1.0)
			th.volume_db = linear_to_db(maxf(k * k * game.dread_volume * game.room_theme_volume, 0.0001)) if m.visible else -80.0
		if m.get_script() == BRACKEN:
			_bracken_sounds(m)
		_cue_in[m] = float(_cue_in.get(m, randf_range(3.0, 6.0))) - delta
		if _cue_in[m] > 0.0:
			continue
		_cue_in[m] = randf_range(5.0, 10.0)
		var near := INF
		for p in game.players:
			if not p.dead:
				near = minf(near, p.head.global_position.distance_to(m.global_position))
		if near > game.dread_heartbeat_distance * 1.3 or _seen_by_us(m):
			continue
		var at: Vector3 = m.global_position + Vector3(0, m.height * 0.8, 0)
		if m is FREDDY:
			pass   # his music box, above
		elif m is TAILS_DOLL:
			_at(_pick(game.dread_whispers), at, 0.6, randf_range(1.15, 1.3))   # a child's whisper
		elif not (m is SLENDER or m is ROOM or m is MX or m is MIMIC or m is SPIDER):
			_at(game.dread_breathing, at, 0.8, randf_range(0.8, 0.95))   # the Bracken, breathing


# The Bracken hisses when you catch it
func _bracken_sounds(m) -> void:
	var was: int = _was.get(m, m.state)
	_was[m] = m.state
	var at: Vector3 = m.global_position + Vector3(0, m.height * 0.8, 0)
	if m.state != was and (m.state == m.SPOTTED or m.state == m.ANGRY) \
			and (m.state == m.ANGRY or game.time - float(_hissed.get(m, -100.0)) > 8.0):
		_hissed[m] = game.time
		_at(_pick(game.bracken_hiss_sounds), at, 1.2, randf_range(0.95, 1.05))
	var angry: bool = m.state == m.ANGRY
	if angry and not _angry.has(m) and game.bracken_angry_sound:
		var s := AudioStreamPlayer3D.new()
		s.stream = _looping(game.bracken_angry_sound)
		s.bus = _bus()
		s.unit_size = 8.0
		s.max_distance = 50.0
		s.volume_db = linear_to_db(game.dread_volume)
		m.add_child(s)
		s.position = Vector3(0, m.height * 0.7, 0)
		s.play()
		_angry[m] = s
	elif not angry and _angry.has(m):
		if is_instance_valid(_angry[m]):
			var s: AudioStreamPlayer3D = _angry[m]
			s.create_tween().tween_property(s, "volume_db", -60.0, 0.6).finished.connect(s.queue_free)
		_angry.erase(m)


# PLAYING THINGS

func _at(stream: AudioStream, pos: Vector3, vol: float, pitch := 1.0) -> void:
	if stream == null:
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.bus = _bus()
	s.unit_size = 10.0
	s.max_distance = 50.0
	s.attenuation_filter_cutoff_hz = 4000.0   # far off: a bit muffled, through the walls
	s.attenuation_filter_db = -10.0
	s.pitch_scale = pitch
	s.volume_db = linear_to_db(vol * game.dread_volume)
	game.add_child(s)
	s.global_position = pos
	s.play()
	s.finished.connect(s.queue_free)


func _flat(stream: AudioStream, vol: float) -> void:
	if stream == null:
		return
	var s := AudioStreamPlayer.new()
	s.stream = stream
	s.bus = _bus()
	s.volume_db = linear_to_db(vol * game.dread_volume)
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _loop_player(stream: AudioStream) -> AudioStreamPlayer:
	var s := AudioStreamPlayer.new()
	s.stream = _looping(stream)
	s.bus = _bus()
	add_child(s)
	return s


# The same sound, set to loop
func _looping(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var s := stream.duplicate()
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif "loop" in s:
		s.loop = true
	return s


func _set_vol(s: AudioStreamPlayer, v: float) -> void:
	if s and s.stream:
		s.volume_db = lerpf(s.volume_db, linear_to_db(maxf(v, 0.0001)), 0.08)


func _fade_out(delta: float) -> void:
	if _gone:
		return
	for s in [_hum, _dread]:
		if s:
			s.volume_db -= delta * 30.0
	if _hum and _hum.volume_db < -70.0:
		_gone = true
		_hum.stop()
		_dread.stop()


func _bus() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


func _pick(list: Array) -> AudioStream:
	var ok := list.filter(func(s): return s != null)
	return ok[randi() % ok.size()] if not ok.is_empty() else null


# A local player down in the maze
func _anyone_below() -> bool:
	for p in game.players:
		if not p.dead and not p.escaped and game.below_deck(p):
			return true
	return false


func _someone():
	var alive: Array = game.players.filter(func(p): return not p.dead and game.below_deck(p))
	return alive[randi() % alive.size()] if not alive.is_empty() else null


# Somewhere around a player, this far away
func _around(p, near: float, far: float) -> Vector3:
	var a := randf() * TAU
	return p.head.global_position + Vector3(cos(a), randf_range(-0.5, 1.0), sin(a)) * randf_range(near, far)


# Just behind a player's head
func _behind(p, dist: float) -> Vector3:
	var back: Vector3 = p.head.global_transform.basis.z
	back.y = 0.0
	back = back.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	return p.head.global_position + back * dist
