extends "res://Scenes/Salvage/bracken.gd"
# MX: harmless NES Mario wandering about, until it turns

var disguised := true            # still Mario
var target = null
var last_seen := Vector3.ZERO
var lost_for := 0.0
var voice_left := 0.0
var rest_left := 0.0
var respot_left := 0.0
var facing := Vector3.FORWARD
var _born := 0.0
var _anim := 0.0
var _last_pos := Vector3.ZERO
var _voice: AudioStreamPlayer3D
var _was_state := -1

# Set from the Salvage node's MX settings
var mario_frames: Array[Texture2D] = []   # standing, then the walk
var mario_height := 1.1
var mario_speed := 1.8
var mx_texture: Texture2D
var mx_chase_texture: Texture2D
var transform_after := 60.0      # seconds after it turns up
var transform_sound: AudioStream
var roam_speed := 2.6
var chase_speed := 4.0           # you walk at 4.2
var spot_range := 22.0
var spot_angle := 70.0           # degrees either side of where it faces
var lose_time := 3.0             # out of its sight this long and it gives up
var voicelines: Array[AudioStream] = []
var voice_time := 1.0
var rest_time := 4.0
var mx_height := 2.6


func setup(game_node: Node3D, tex: Texture2D) -> void:
	super.setup(game_node, mario_frames[0] if not mario_frames.is_empty() else tex)
	height = mario_height
	_fit()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 8.0
	_voice.max_distance = 60.0
	_voice.volume_db = 4.0
	add_child(_voice)
	_voice.position = Vector3(0, mx_height * 0.85, 0)


func spawn(at: Vector3) -> void:
	super.spawn(at)
	_born = game.time
	_last_pos = global_position


func update(delta: float, watchers: Array) -> void:
	if not visible:
		return
	_shade()
	var alive := _alive(watchers)
	if disguised:
		# Harmless Mario, wandering
		if game.time - _born > transform_after:
			_transform()
		else:
			_roam_at(mario_speed, delta)
			_animate(delta)
			return
	if rest_left > 0.0:
		rest_left -= delta
		return
	if voice_left > 0.0:
		voice_left -= delta   # says its line, standing there, then comes for you
		return
	respot_left -= delta
	if target != null and not (target in alive):
		target = null
	if target == null:
		state = STALK
		# Looking for someone
		for w in alive:
			if _spots(w) and respot_left <= 0.0:
				target = w
				last_seen = w.feet
				lost_for = 0.0
				state = ANGRY
				voice_left = voice_time
				_say()
				break
		if target == null:
			_roam_at(roam_speed, delta)
	else:
		state = ANGRY
		if _spots(target):
			last_seen = target.feet
			lost_for = 0.0
		else:
			lost_for += delta
		if lost_for > lose_time:
			target = null   # lost you
			respot_left = 1.5
			path.clear()
		else:
			_chase({"feet": last_seen}, chase_speed, delta)
	# Run into it and that's it
	for w in alive:
		if _reach(w) and not settling():
			_kill(w)
			break
	_animate(delta)


# Can it see them? In front of it, near enough, nothing in the way, not hiding
func _spots(w) -> bool:
	if w.get("hidden", false):
		return false
	var eye := global_position + Vector3(0, height * 0.85, 0)
	var to: Vector3 = w.eye - eye
	var d := to.length()
	if d > minf(spot_range, w.get("sight", spot_range)) or d < 0.05:
		return false
	var flat := Vector3(to.x, 0, to.z)
	if d > 3.0 and flat.length() > 0.01 and facing.dot(flat.normalized()) < cos(deg_to_rad(spot_angle)):
		return false   # behind it
	return _clear(w.eye, eye)   # from them: a ray into their own body would hit it


func _roam_at(speed: float, delta: float) -> void:
	if path.is_empty():
		var c: Vector2i = game.maze_lo + Vector2i(randi() % game.maze_size.x, randi() % game.maze_size.y)
		path = _route(_cell(global_position), c)
	_walk_path(speed, delta)


func _transform() -> void:
	disguised = false
	height = mx_height
	texture = mx_texture
	_fit()
	if transform_sound:
		var s := AudioStreamPlayer3D.new()
		s.stream = transform_sound
		s.unit_size = 8.0
		s.max_distance = 60.0
		add_child(s)
		s.position = Vector3(0, height * 0.8, 0)
		s.play()
		s.finished.connect(s.queue_free)


func _say() -> void:
	var lines := voicelines.filter(func(s): return s != null)
	if lines.is_empty() or _voice == null:
		return
	_voice.stream = lines[randi() % lines.size()]
	_voice.play()
	var t := get_tree().create_timer(voice_time)
	t.timeout.connect(func():
		if is_instance_valid(_voice):
			_voice.stop())


# Which way it faces, and its picture
func _animate(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	if moved.length() > 0.001:
		facing = moved.normalized()
	if disguised:
		if mario_frames.size() < 2:
			return
		var walking := moved.length() > 0.001
		_anim += delta * 10.0 if walking else 0.0
		var f: Texture2D = mario_frames[1 + int(_anim) % (mario_frames.size() - 1)] if walking else mario_frames[0]
		if f != texture:
			texture = f
		# faces the way it walks, seen from the camera
		var cam := get_viewport().get_camera_3d()
		if cam and walking:
			flip_h = cam.global_basis.x.dot(facing) < 0.0
	else:
		var want: Texture2D = mx_chase_texture if state == ANGRY and mx_chase_texture else mx_texture
		if want and want != texture:
			texture = want
			_fit()
		flip_h = false


func _fit() -> void:
	if texture == null:
		return
	pixel_size = height / float(texture.get_height())
	offset = Vector2(0, texture.get_height() * 0.5)

func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	if disguised:
		_transform()   # the alarm brings it out
	target = w
	last_seen = w.feet
	lost_for = 0.0
	rest_left = 0.0


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	if not game.watcher_dead(w):
		return
	w.alive = false
	target = null
	path.clear()
	rest_left = rest_time


func placeholder() -> Texture2D:
	return blank_figure(30, 60, Color(0.8, 0.15, 0.1), 1.0, 0.0)
