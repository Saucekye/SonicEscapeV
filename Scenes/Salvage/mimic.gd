extends "res://Scenes/Salvage/bracken.gd"
# The Mimic

var look: Sprite3D               # the character it's copying
var target = null
var last_seen := Vector3.ZERO
var lost_for := 0.0
var rest_left := 0.0
var facing := Vector3.FORWARD
var _last_pos := Vector3.ZERO
var _strings: Array = []         # [MeshInstance3D, where on its body it hangs from]
var _string_mat: StandardMaterial3D
var _sway := 0.0

# Set from the Salvage node's Mimic settings
var character := "Sonic"
var walk_speed := 3.0            # wandering, and strolling over to you
var lunge_speed := 6.5           # close up
var lunge_range := 5.0
var spot_range := 18.0
var spot_angle := 75.0
var lose_time := 4.0
var rest_time := 4.0
var string_range := 6.0          # the strings show this close, clearer the closer you are
var stare_time := 2.0            # when it spots you, it stares this long before walking over
var _stare_left := 0.0
var ceiling := 3.2               # how high the strings go


func setup(game_node: Node3D, _tex: Texture2D) -> void:
	look = game_node.TEAMMATE.instantiate()
	if not look.setup(character):
		look.free()
		look = game_node.TEAMMATE.instantiate()
		look.setup("Sonic")
	look.min_light = game_node.character_brightness
	game_node.add_child(look)
	# Its own sprite is the character's standing frame, never drawn
	var atlas := AtlasTexture.new()
	atlas.atlas = look.texture
	var fw := look.texture.get_width() / maxi(look.hframes, 1)
	var fh := look.texture.get_height() / maxi(look.vframes, 1)
	var f: int = look.stance_frames[0] if not look.stance_frames.is_empty() else 0
	atlas.region = Rect2((f % look.hframes) * fw, (f / look.hframes) * fh, fw, fh)
	height = look.height
	super.setup(game_node, atlas)
	transparency = 1.0
	_make_strings()


func _exit_tree() -> void:
	if is_instance_valid(look):
		look.queue_free()


func spawn(at: Vector3) -> void:
	super.spawn(at)
	_last_pos = global_position


func update(delta: float, watchers: Array) -> void:
	if is_instance_valid(look):
		look.visible = visible
	if not visible:
		return
	_shade()
	if rest_left > 0.0:
		rest_left -= delta
	else:
		var alive := _alive(watchers)
		if target != null and not (target in alive):
			target = null
		if target == null:
			state = ROAM
			for w in alive:
				if _spots(w) and not settling():
					target = w
					last_seen = w.feet
					lost_for = 0.0
					_stare_left = stare_time   # it stares at you first
					break
			if target == null:
				_roam_at(walk_speed, delta)
		if target != null:
			state = STALK
			if _spots(target):
				last_seen = target.feet
				lost_for = 0.0
			else:
				lost_for += delta
			if lost_for > lose_time:
				target = null
				path.clear()
			elif _stare_left > 0.0:
				_stare_left -= delta   # standing there, looking at you
				var to: Vector3 = target.feet - global_position
				to.y = 0.0
				if to.length() > 0.01:
					facing = to.normalized()
			else:
				var close := _flat_dist(target.feet) < lunge_range and lost_for == 0.0
				if close:
					state = ANGRY   # the lunge
				_chase({"feet": last_seen}, lunge_speed if close else walk_speed, delta)
				if _reach(target) and not settling():
					_kill(target)
	_dress(delta)

# Like a player
func _dress(delta: float) -> void:
	var moved := global_position - _last_pos
	moved.y = 0.0
	_last_pos = global_position
	if moved.length() > 0.001:
		facing = moved.normalized()
	var cam := get_viewport().get_camera_3d()
	if is_instance_valid(look):
		look.state = "Dash" if state == ANGRY else ""
		var lit: float = game._light_at(global_position + Vector3(0, 1.0, 0))
		look.drive(global_position, cam, lit, delta, look.state, true)
	# Strings: clearer the closer the nearest of us is
	var near := INF
	for p in game.players:
		if not p.dead:
			near = minf(near, p.global_position.distance_to(global_position))
	var a := clampf(1.0 - (near - string_range * 0.4) / (string_range * 0.6), 0.0, 1.0)
	_string_mat.albedo_color.a = 0.75 * a
	_sway += delta
	var right := cam.global_transform.basis.x if cam else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized()
	var top: float = game._floor_at(_cell(global_position), global_position) + ceiling
	for s in _strings:
		var m: MeshInstance3D = s[0]
		m.visible = a > 0.01
		if not m.visible:
			continue
		var on: Vector3 = s[1]
		var from: Vector3 = global_position + right * on.x + Vector3(0, on.y, 0)
		var to := Vector3(from.x + sin(_sway * 0.9 + on.x * 3.0) * 0.06, top, from.z)
		var len := maxf(to.y - from.y, 0.05)
		m.global_position = (from + to) * 0.5
		var dir := (to - from).normalized()
		m.global_basis = Basis(right, dir * len, right.cross(dir).normalized())   # up the thread, facing you


# Its jumpscare picture
func _face_now() -> void:
	if not is_instance_valid(look) or not (texture is AtlasTexture):
		return
	var fw := look.texture.get_width() / maxi(look.hframes, 1)
	var fh := look.texture.get_height() / maxi(look.vframes, 1)
	var f: int = look.run_frames[0] if not look.run_frames.is_empty() else look.frame   # upright, coming at you
	(texture as AtlasTexture).region = Rect2((f % look.hframes) * fw, (f / look.hframes) * fh, fw, fh)


# Thin threads from its head and hands up to the ceiling
func _make_strings() -> void:
	_string_mat = StandardMaterial3D.new()
	_string_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_string_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_string_mat.albedo_color = Color(0.85, 0.85, 0.8, 0.0)
	_string_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.015, 1.0)
	for on in [Vector3(0.0, height * 0.95, 0), Vector3(-height * 0.3, height * 0.55, 0), Vector3(height * 0.3, height * 0.55, 0), Vector3(-height * 0.12, height * 0.2, 0), Vector3(height * 0.12, height * 0.2, 0)]:
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = _string_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(m)
		m.top_level = true
		_strings.append([m, on])
	tree_exiting.connect(func():
		for s in _strings:
			if is_instance_valid(s[0]):
				s[0].queue_free())


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
		return false
	return _clear(w.eye, eye)


func _roam_at(speed: float, delta: float) -> void:
	if path.is_empty():
		var c: Vector2i = game.maze_lo + Vector2i(randi() % game.maze_size.x, randi() % game.maze_size.y)
		path = _route(_cell(global_position), c)
	_walk_path(speed, delta)


func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	target = w
	last_seen = w.feet
	lost_for = 0.0
	rest_left = 0.0


func _kill(w) -> void:
	if not w.alive:
		return
	_face_now()
	game.monster_kill(w, self)
	if not game.watcher_dead(w):
		return
	w.alive = false
	target = null
	path.clear()
	rest_left = rest_time
	game.mimic_caught(w)   # they'll get up as one of us
