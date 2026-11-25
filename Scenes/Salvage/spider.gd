extends "res://Scenes/Salvage/bracken.gd"
# The Spider

enum { LURK, EMERGE, CRAWL, GONE, HUNT, DRAG, LISTEN, LEAVE }
var phase := LURK
var lairs: Array = []            # cells it can climb out of
var _t := 0.0
var _from := Vector3.ZERO
var _wall_at := Vector3.ZERO
var _normal := Vector3.UP        # what it's flat against
var _along := Vector3.FORWARD
var _crawled := 0.0
var heard_at = null              # where it last heard someone
var _quiet_for := 0.0
var _frames: Array[Texture2D] = []
var _anim := 0.0
var _skitter := 0.0

# Set from the Salvage node's Spider settings
var emerge_range := 5.0          # this close to its pit and it may climb out
var emerge_chance := 0.6         # ...this likely
var crawl_speed := 4.0
var crawl_distance := 12.0       # it scuttles this far along the wall, then it's gone
var return_after := Vector2(20.0, 40.0)
var roam_speed := 2.2
var rush_speed := 14.0           # you walk at 4.2
var hear_range := 16.0
var quiet_speed := 0.8           # moving slower than this
var drop_chance := 0.12          # chance a second that it drops you on the way
var listen_time := 6.0           # after dropping you, how long it stays and listens
var holding = null               # the watcher it's got hold of
var _drag_t := 0.0
var _dropped_at := 0.0
var size := 3.2                  # metres across, legs and all
var body := 0.65                 # how long its body is, as a share of that
var _legs: Array = []            # each: {"hip", "rest", "side", "phase", "rate", "thigh", "shin", "twitch"}
var _leg_mat: StandardMaterial3D


func setup(game_node: Node3D, tex: Texture2D) -> void:
	# A flat (2D) body
	_frames = [game_node.spider_texture if game_node.spider_texture else _draw_body()]
	height = size
	super.setup(game_node, _frames[0])
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	pixel_size = size * body / float(_frames[0].get_height())
	kill_distance = maxf(kill_distance, size * 0.45)
	_make_legs()
	offset = Vector2.ZERO
	double_sided = true
	visible = false


func spawn(_at: Vector3) -> void:

	phase = LURK
	state = ROAM
	visible = false


func update(delta: float, watchers: Array) -> void:
	_anim += delta
	_t += delta
	var alive := _alive(watchers)
	match phase:
		LURK:
			for w in alive:
				for c in lairs:
					var at: Vector3 = game._cell_center(c)
					if Vector2(w.feet.x - at.x, w.feet.z - at.z).length() < emerge_range:
						if randf() < emerge_chance:
							_emerge(c, w)
						else:
							lairs.erase(c)   # not this pit, this time
						return
		EMERGE:
			# Up out of the pit, then onto the wall
			var k := clampf(_t / 0.8, 0.0, 1.0)
			global_position = _from.lerp(_wall_at, ease(k, 0.6))
			if k >= 1.0:
				phase = CRAWL
				_t = 0.0
				_crawled = 0.0
		CRAWL:
			# Off along the wall, away
			var step := crawl_speed * delta
			global_position += _along * step
			_crawled += step
			var space := get_world_3d().direct_space_state
			var ahead := PhysicsRayQueryParameters3D.create(global_position, global_position + _along * 0.8, 1)
			if _crawled > crawl_distance or not space.intersect_ray(ahead).is_empty():
				phase = GONE
				_t = 0.0
				visible = false
				_t = -randf_range(return_after.x, return_after.y)
		GONE:
			if _t >= 0.0:
				_return(alive)
		HUNT:
			_hunt(alive, delta)
		DRAG:
			_haul(alive, delta)
		LISTEN:
			_listen(alive, delta)
		LEAVE:
			state = ROAM
			_walk_path(roam_speed, delta)
			if path.is_empty() or _t > 5.0:
				phase = GONE
				visible = false
				_t = -randf_range(return_after.x, return_after.y)
	_pose(delta)


func _emerge(c: Vector2i, w) -> void:
	var mid: Vector3 = game._cell_center(c)
	var fl: float = game._floor_at(c, mid)
	_from = Vector3(mid.x, fl - 1.5, mid.z)
	# Which way the corridor runs
	var ways: Array = game._neighbours(c)
	_along = Vector3(ways[0].x - c.x, 0, ways[0].y - c.y).normalized() if not ways.is_empty() else Vector3.FORWARD
	if (mid - w.feet).dot(_along) < 0.0:
		_along = -_along
	var side := Vector3(-_along.z, 0, _along.x) * (1.0 if randf() < 0.5 else -1.0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(mid.x, fl + 1.4, mid.z), Vector3(mid.x, fl + 1.4, mid.z) + side * game.cell_size, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_wall_at = Vector3(mid.x, fl + 1.4, mid.z) + side * 1.5
		_normal = -side
	else:
		_normal = hit.normal
		_wall_at = hit.position + hit.normal * 0.06
	global_position = _from
	visible = true
	phase = EMERGE
	_t = 0.0


# The next time
func _return(alive: Array) -> void:
	var pts: Array = []
	for w in alive:
		pts.append(w.feet)
	if pts.is_empty():
		return
	var c: Vector2i = game.far_cell_from(pts)
	var at: Vector3 = game._cell_center(c)
	at.y = game._floor_at(c, at) + 0.05
	global_position = at
	visible = true
	phase = HUNT
	state = ROAM
	path.clear()


# Blind: it goes by sound
func _hunt(alive: Array, delta: float) -> void:
	var loud = null
	var best := hear_range
	for w in alive:
		var d := global_position.distance_to(w.feet)
		if d < best and _noisy(w):
			best = d
			loud = w
	if loud != null:
		if heard_at == null:
			path.clear()
		heard_at = loud.feet
		_quiet_for = 0.0
	if heard_at != null:
		state = ANGRY
		_chase({"feet": heard_at}, rush_speed, delta)
		if _flat_dist(heard_at) < 1.0:
			_quiet_for += delta
			if _quiet_for > 1.5:
				heard_at = null
				path.clear()
	else:
		state = ROAM
		if path.is_empty():
			var c: Vector2i = game.maze_lo + Vector2i(randi() % game.maze_size.x, randi() % game.maze_size.y)
			path = _route(_cell(global_position), c)
		_walk_path(roam_speed, delta)
	for w in alive:
		if _reach(w) and not game.in_exit_car(w.feet):
			_grab(w)
			break


# Got you: off back to the nearest pit with you
func _grab(w) -> void:
	holding = w
	phase = DRAG
	state = ANGRY
	_drag_t = 0.0
	heard_at = null
	var here := _cell(global_position)
	var best = null
	var best_d := INF
	for c in lairs_all:
		var d := Vector2(c - here).length()
		if d < best_d:
			best_d = d
			best = c
	path = _route(here, best) if best != null else ([] as Array[Vector2i])
	_lair = best
	game.spider_hold(w, self, true)


var lairs_all: Array = []        # every pit it lives in
var _lair = null


func _haul(alive: Array, delta: float) -> void:
	var w = holding
	if w == null or not alive.has(w):
		_drop_hold(false)
		return
	_drag_t += delta
	if _lair == null:
		_finish(w)
		return
	var there: Vector3 = game._cell_center(_lair)
	if path.is_empty():
		if _step_toward(there, drag_speed, delta):
			_finish(w)
		return
	_walk_path(drag_speed, delta)
	# Now and then it loses its grip
	if _drag_t > 1.5 and randf() < drop_chance * delta:
		_drop_hold(true)


# Down the pit with you
func _finish(w) -> void:
	game.spider_hold(w, self, false)
	holding = null
	_kill(w)
	phase = LEAVE
	_t = 0.0
	path.clear()


func _drop_hold(listen: bool) -> void:
	if holding != null:
		game.spider_hold(holding, self, false)
	holding = null
	path.clear()
	if listen:
		phase = LISTEN
		state = ROAM
		_t = 0.0
		_dropped_at = 0.0
	else:
		phase = HUNT


# It dropped you
func _listen(alive: Array, delta: float) -> void:
	_dropped_at += delta
	if _dropped_at > 0.6:
		for w in alive:
			if global_position.distance_to(w.feet) < hear_range and _noisy(w):
				phase = HUNT
				heard_at = w.feet
				_quiet_for = 0.0
				path.clear()
				return
	if _t > listen_time:
		phase = LEAVE
		_t = 0.0
		var pts: Array = []
		for w in alive:
			pts.append(w.feet)
		path = _route(_cell(global_position), game.far_cell_from(pts)) if not pts.is_empty() else ([] as Array[Vector2i])


# Where whoever it has hold of is
func drag_point() -> Vector3:
	return global_position - _along * 0.6 + Vector3(0, 0.05, 0)


func _noisy(w) -> bool:
	if w.local and w.local.get("crouching"):
		return false
	return w.speed > quiet_speed


# Flat against the wall
func _pose(delta: float) -> void:
	if not visible:
		return
	var n := _normal if phase in [EMERGE, CRAWL] else Vector3.UP
	var head := _along
	if phase in [HUNT, DRAG, LEAVE] and not path.is_empty():
		var to: Vector3 = game._cell_center(path[0]) - global_position
		to.y = 0.0
		if to.length() > 0.05:
			head = to.normalized()
			_along = head
	if phase == EMERGE:
		head = Vector3.UP if _t < 0.5 else _along
	head = (head - n * head.dot(n)).normalized()
	if head.length() < 0.5:
		head = n.cross(Vector3.RIGHT).normalized()
	global_basis = Basis(head.cross(n).normalized(), head, n)
	var lit: float = maxf(game._light_at(global_position + n * 0.2), game.hunter_glow_at(global_position))
	modulate = Color(Color.WHITE * (min_shade + (1.0 - min_shade) * lit), 1.0)
	var moving := phase in [EMERGE, CRAWL, LEAVE] or (phase in [HUNT, DRAG] and not path.is_empty())
	_move_legs(delta, moving, lit)
	# Its legs, skittering, when it rushes
	if state == ANGRY and phase == HUNT:
		_skitter -= delta
		var dread = game.get_node_or_null("Dread")
		if _skitter <= 0.0 and dread and not game.dread_steps.is_empty():
			_skitter = 0.07
			dread._at(game.dread_steps[randi() % game.dread_steps.size()], global_position, 0.6, randf_range(1.8, 2.3))


# Its body, from above
static func _draw_body() -> Texture2D:
	var w := 40
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.06, 0.05, 0.05)
	_blob(img, Vector2(w * 0.5, h * 0.66), 17.0, 20.0, dark)   # abdomen
	_blob(img, Vector2(w * 0.5, h * 0.26), 11.0, 12.0, dark)   # head
	_blob(img, Vector2(w * 0.5, h * 0.66), 7.0, 9.0, Color(0.12, 0.08, 0.08))   # a mark on its back
	for e in [Vector2(-3, -16), Vector2(3, -16), Vector2(-6, -13), Vector2(6, -13), Vector2(-2, -12), Vector2(2, -12)]:
		img.set_pixelv(Vector2i(Vector2(w * 0.5, h * 0.26) + e), Color(0.95, 0.1, 0.1))
	return ImageTexture.create_from_image(img)


# Its jumpscare
static func _draw_face() -> Texture2D:
	var w := 96
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.05, 0.04, 0.04)
	var c := Vector2(w * 0.5, w * 0.2)   # high up: the jumpscare shows the top of its picture
	# legs: up and out, bent, either side
	for i in 4:
		for sgn: float in [-1.0, 1.0]:
			var hip := c + Vector2(sgn * 10.0, 6.0 + i * 3.0)
			var knee := hip + Vector2(sgn * (16.0 + i * 5.0), -26.0 + i * 9.0)
			var foot := knee + Vector2(sgn * (6.0 + i * 3.0), 34.0 + i * 6.0)
			_line(img, hip, knee, dark, 3)
			_line(img, knee, foot, dark, 2)
	_blob(img, c + Vector2(0, 8), 21.0, 22.0, dark)   # head and body
	# fangs
	for sgn: float in [-1.0, 1.0]:
		_line(img, c + Vector2(sgn * 5.0, 22.0), c + Vector2(sgn * 3.0, 36.0), Color(0.75, 0.7, 0.6), 2)
	# eyes: two big, six small
	for e in [Vector2(-6, 0), Vector2(6, 0)]:
		_blob(img, c + e, 3.4, 3.4, Color(0.95, 0.08, 0.08))
		img.set_pixelv(Vector2i(c + e + Vector2(-1, -1)), Color(1, 0.8, 0.8))
	for e in [Vector2(-13, -4), Vector2(13, -4), Vector2(-9, -8), Vector2(9, -8), Vector2(-3, -9), Vector2(3, -9)]:
		_blob(img, c + e, 1.6, 1.6, Color(0.9, 0.1, 0.1))
	return ImageTexture.create_from_image(img)


# Eight legs, two segments each, out from the body's sides
func _make_legs() -> void:
	_leg_mat = StandardMaterial3D.new()
	_leg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_leg_mat.albedo_color = Color(0.06, 0.05, 0.05)
	var rests := [50.0, 18.0, -14.0, -45.0]   # degrees from straight out, forward +
	for side in [1.0, -1.0]:
		for i in 4:
			var leg := {
				"hip": Vector3(side * size * body * 0.16, size * body * (0.2 - i * 0.11), 0.0),   # under the front of its body
				"rest": deg_to_rad(rests[i]),
				"side": side,
				"phase": i * PI * 0.5 + (PI if side < 0.0 else 0.0) + randf_range(-0.3, 0.3),
				"rate": randf_range(0.85, 1.15),
				"thigh": size * randf_range(0.24, 0.27),
				"shin": size * randf_range(0.3, 0.34),
				"twitch": 0.0,
				"t": randf() * TAU,
			}
			for part in ["a", "b"]:
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(size * (0.025 if part == "a" else 0.016), 1.0, size * 0.02)
				m.mesh = bm
				m.material_override = _leg_mat
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(m)
				leg[part] = m
			_legs.append(leg)


# Each leg steps on its own
func _move_legs(delta: float, moving: bool, lit: float) -> void:
	var c := min_shade + (1.0 - min_shade) * lit
	_leg_mat.albedo_color = Color(0.06, 0.05, 0.05) * c + Color(0.02, 0.02, 0.02)
	var speed := (22.0 if state == ANGRY else 9.0) if moving else 0.0
	for leg in _legs:
		leg.t += delta * speed * leg.rate
		var swing := 0.0
		var lift := 0.0
		if moving:
			swing = sin(leg.t) * deg_to_rad(20.0)
			lift = maxf(cos(leg.t), 0.0) * size * 0.06
		else:
			leg.twitch -= delta
			if leg.twitch < -randf_range(1.5, 6.0):
				leg.twitch = 0.25   # a twitch
			if leg.twitch > 0.0:
				swing = sin(leg.twitch * 25.0) * deg_to_rad(10.0)
				lift = size * 0.03
		var a: float = leg.rest + swing
		var out := Vector3(leg.side * cos(a), sin(a), 0.0)
		var knee: Vector3 = leg.hip + out * leg.thigh + Vector3(0, 0, size * 0.09 + lift)
		var bend: float = a - deg_to_rad(12.0)   # the lower leg sweeps a little back
		var down := Vector3(leg.side * cos(bend) * 0.9, sin(bend) * 0.9, 0.0).normalized()
		var foot: Vector3 = knee + down * leg.shin
		foot.z = lift * 0.5
		_segment(leg.a, leg.hip, knee)
		_segment(leg.b, knee, foot)


func _segment(m: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3(0, 0, 1)).normalized()
	if x.length() < 0.5:
		x = Vector3(1, 0, 0)
	var z := x.cross(y).normalized()
	m.transform = Transform3D(Basis(x, y * len, z), (from + to) * 0.5)


static func _blob(img: Image, at: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(int(at.y - ry), int(at.y + ry) + 1):
		for x in range(int(at.x - rx), int(at.x + rx) + 1):
			if pow((x - at.x) / rx, 2) + pow((y - at.y) / ry, 2) <= 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, thick: int) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dx in thick:
			for dy in thick:
				var q := Vector2i(p) + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)

func alarm(w, for_time: float) -> void:
	# The alarm brings it out, hunting
	if phase in [DRAG, LISTEN]:
		return
	if phase in [LURK, GONE, EMERGE, CRAWL, LEAVE]:
		visible = false
		_return([w])
	heard_at = w.feet


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	if not game.watcher_dead(w):
		return
	w.alive = false
	heard_at = null
	path.clear()


func placeholder() -> Texture2D:
	return _draw_body()
