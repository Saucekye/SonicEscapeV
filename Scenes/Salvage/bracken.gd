extends Sprite3D
# The Bracken

enum { WAIT, STALK, SPOTTED, ANGRY, CARRY, ROAM }

var game: Node3D                 # salvage.gd
var state := WAIT
var anger := 0.0                 # seconds of being stared at
var angry_left := 0.0
var angry_at = null              # the watcher it's after
var carry_left := 0.0
var path: Array[Vector2i] = []
var repath := 0.0
var spotted_for := 0.0           # how long it's been seen without a break
var min_shade := 0.4             # darkest it gets
var kind_index := 0              # which of salvage.gd's hunters this is
var spawn_after := 35.0          # seconds into the visit before it turns up
var stunned_left := 0.0          # frozen by a Stun
var alarm_on = null              # the watcher who set off the alarm
var alarm_left := 0.0            # how much longer it goes straight for them

# Set from the Salvage node's Bracken settings
var stalk_speed := 3.0
var flee_speed := 5.5
var charge_speed := 7.4
var anger_time := 3.0
var angry_time := 7.0
var corner_distance := 2.2
var kill_distance := 1.05
var height := 1.75
var carry_time := 8.0            # seconds it drags someone off for
var drag_to_den := true          # drags whoever it kills back to its den, and hunts nobody till it's there
var drag_speed := 3.3            # how fast it drags them
var den := Vector2i(-1, -1)      # its den: a corner far from the exit
var dragging = null              # the watcher it killed, while it drags them
var _drag_body: RigidBody3D
var cool_rate := 0.25            # how fast its anger wears off
var hush_time := 1.0             # before it charges, everything goes silent this long
var bold_max := 5                # it gets bolder each time it's caught
var bold_step := 0.12            # each time, it takes this much less staring to set off
var boldness := 0
var _unseen_for := 99.0          # a fresh sighting only counts after this many seconds out of sight
var winding := false             # in the silence before a charge
var _wind_left := 0.0
var _wind_at = null
# Shared by every hunter
var sight_range := 28.0          # how far away players can see it
var view_dot := 0.72             # how near the middle of your view it has to be to count as seen
var hide_range := 2.5            # hidden players are safe from it unless it's this close


func setup(game_node: Node3D, tex: Texture2D) -> void:
	game = game_node
	texture = tex
	pixel_size = height / float(tex.get_height())
	offset = Vector2(0, tex.get_height() * 0.5)   # feet at its position
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	visible = false


# Appear somewhere far from everyone
func spawn(at: Vector3) -> void:
	global_position = at
	if den == Vector2i(-1, -1):
		den = game.far_cell_from([game._cell_center(game.exit_cell)])
	visible = true
	state = STALK


# The alarm went off
func alarm(w, for_time: float) -> void:
	alarm_on = w
	alarm_left = for_time
	if state == CARRY and dragging != null:
		return   # it gets the body home first
	path.clear()
	repath = 0.0
	if w != null and get_script().resource_path.ends_with("bracken.gd"):
		_get_angry(w)   # the Bracken charges


# Every frame
func update(delta: float, watchers: Array) -> void:
	if not visible:
		return
	_shade()
	repath -= delta
	var alive := watchers.filter(func(w): return w.alive and _in_maze(w.feet))
	var seen_by := alive.filter(func(w): return _sees_me(w))

	match state:
		CARRY:
			if dragging != null:
				# Dragging them home
				_drag(game.body_of(dragging))
				if path.is_empty() or not game.watcher_dead(dragging):
					# Home (or they were brought back)
					dragging = null
					_let_go()
					state = STALK
				else:
					_walk_path(drag_speed, delta)
			else:
				# Dragging someone off to its corner, then back to it
				carry_left -= delta
				_walk_path(flee_speed * 0.6, delta)
				if carry_left <= 0.0:
					state = STALK
		ANGRY:
			angry_left -= delta
			if angry_at == null or not angry_at.alive or angry_left <= 0.0:
				_calm_down()
			else:
				_chase(angry_at, charge_speed, delta)
				if _reach(angry_at):
					_kill(angry_at)
		_:
			if winding:
				# The silence before it charges
				_wind_left -= delta
				if _wind_left <= 0.0:
					winding = false
					if _wind_at != null and _wind_at.alive:
						_get_angry(_wind_at)
			elif not seen_by.is_empty():
				# Looked at: freeze, then slink away
				if spotted_for == 0.0 and _unseen_for > 4.0:
					boldness = mini(boldness + 1, bold_max)
				_unseen_for = 0.0
				spotted_for += delta
				anger += delta * seen_by.size()
				state = SPOTTED
				var closest = _closest(seen_by)
				var bold := 1.0 - bold_step * maxi(boldness - 1, 0)
				if not settling() and (anger >= anger_time * maxf(bold, 0.35) or _flat_dist(closest.feet) < corner_distance and spotted_for > 0.4):
					if hush_time > 0.0:
						winding = true   # everything goes quiet first
						_wind_left = hush_time
						_wind_at = closest
						path.clear()
					else:
						_get_angry(closest)
				elif spotted_for > 0.35 + (1.0 - bold) * 2.5:
					_flee_from(closest, delta * maxf(bold, 0.5))
			else:
				spotted_for = 0.0
				_unseen_for += delta
				anger = maxf(anger - delta * cool_rate, 0.0)
				var target = _pick_target(alive)
				if target == null:
					state = ROAM
					_roam(delta)
				else:
					state = STALK
					_chase(target, stalk_speed, delta)
					if _reach(target):
						_kill(target)   # it got you from behind


# Lit like everything else
func _shade() -> void:
	var lit: float = maxf(game._light_at(global_position + Vector3(0, 1.0, 0)), game.hunter_glow_at(global_position))   # up close, it's clear as day
	modulate = Color.WHITE * (min_shade + (1.0 - min_shade) * lit)
	modulate.a = 1.0
	if model:
		_model_frame()


# A 3D model in place of the picture
var model: Node3D
var _model_mats: Array = []      # [material, its own colour]
var _model_pixel := 1.0


func use_model(scene: PackedScene) -> void:
	model = scene.instantiate() as Node3D
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	transparency = 1.0   # the picture itself isn't drawn
	add_child(model)
	_model_pixel = pixel_size
	# Lit by the maze's own lamps, like the picture
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m = mi.get_active_material(i)
			if m is StandardMaterial3D:
				var own := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				own.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mi.set_surface_override_material(i, own)
				_model_mats.append([own, own.albedo_color])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _model_frame() -> void:
	for pair in _model_mats:
		(pair[0] as StandardMaterial3D).albedo_color = pair[1] * Color(modulate.r, modulate.g, modulate.b, 1.0)
	model.scale = Vector3.ONE * (pixel_size / _model_pixel)   # bigger from above, like the pictures
	for gi in model.find_children("*", "GeometryInstance3D", true, false):
		gi.layers = layers
	# Turned to face whoever's watching here
	if not game.players.is_empty():
		var at: Vector3 = game.players[0].global_position
		var flat := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
		if flat.length() > 0.01:
			model.global_rotation.y = atan2(-flat.x, -flat.z)

# Players who are still in the maze and still in play
func _alive(watchers: Array) -> Array:
	return watchers.filter(func(w): return w.alive and _in_maze(w.feet))


# Seeing and being seen Is this player looking at it?
func _sees_me(w) -> bool:
	var chest := global_position + Vector3(0, height * 0.6, 0)
	var to: Vector3 = chest - w.eye
	var dist := to.length()
	if dist > minf(sight_range, w.get("sight", sight_range)) or dist < 0.05:   # not far, in fog
		return false
	if w.forward.dot(to / dist) < view_dot:   # outside the middle of their view
		return false
	return _clear(w.eye, chest)


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return game.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# Just turned up
func settling() -> bool:
	return game.time < spawn_after + game.hunter_settle_time


func _pick_target(alive: Array):
	if alarm_left > 0.0 and alarm_on != null and alive.has(alarm_on):
		return alarm_on   # the alarm: after whoever took the Chaos Emerald
	if settling():
		return null
	var best = null
	var best_d := INF
	for w in alive:
		var d := _flat_dist(w.feet)
		if w.hidden and (d > hide_range or w.get("sheltered", false)):
			continue   # crouched behind cover
		if d < best_d:
			best_d = d
			best = w
	return best


func _closest(list: Array):
	var best = list[0]
	for w in list:
		if _flat_dist(w.feet) < _flat_dist(best.feet):
			best = w
	return best


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _reach(w) -> bool:
	if w.get("sheltered", false):
		return false
	if game.in_narrow(w.feet):
		return false
	return _flat_dist(w.feet) < kill_distance and absf(w.feet.y - global_position.y) < 1.2


# Moving through the maze
func _in_maze(p: Vector3) -> bool:
	var c := _cell(p)
	return game.in_maze(c) and p.y < game.UP_Y - 4.0


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / game.cell_size), roundi(p.z / game.cell_size))


# Shortest way through the corridors from a to b
func _route(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out := _route_avoiding(a, b, true)
	if out.is_empty() and a != b:
		out = _route_avoiding(a, b, false)
	return out


func _route_avoiding(a: Vector2i, b: Vector2i, all_narrow: bool) -> Array[Vector2i]:
	var came := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for n in game._neighbours(c):
			if game.narrow_safe and game.narrow_cells.has(n) and (all_narrow or game.narrow_taken(n)):
				continue   # too narrow for it
			if not came.has(n):
				came[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not came.has(b):
		return out
	var c := b
	while c != a:
		out.push_front(c)
		c = came[c]
	return out


func _chase(w, speed: float, delta: float) -> void:
	var here := _cell(global_position)
	var there := _cell(w.feet)
	if game.narrow_safe and game.narrow_cells.has(there):
		# In a narrow corridor
		there = _way_into_narrow(there)
		if here == there:
			return
		if repath <= 0.0 or path.is_empty() or path[-1] != there:
			path = _route(here, there)
			repath = 0.3
		_walk_path(speed, delta)
		return
	if here == there:
		_step_toward(w.feet, speed, delta)   # same corridor
		return
	if repath <= 0.0 or path.is_empty() or path[-1] != there:
		path = _route(here, there)
		repath = 0.3
	_walk_path(speed, delta)


# The cell just outside a narrow corridor nearest this hunter
func _way_into_narrow(c: Vector2i) -> Vector2i:
	var best := c
	var best_d := INF
	var seen := {c: true}
	var queue: Array[Vector2i] = [c]
	while not queue.is_empty():
		var x: Vector2i = queue.pop_front()
		for n in game._neighbours(x):
			if seen.has(n):
				continue
			seen[n] = true
			if game.narrow_cells.has(n):
				queue.append(n)
				continue
			var d := _flat_dist(game._cell_center(n))
			if d < best_d:
				best_d = d
				best = n
	return best


func _walk_path(speed: float, delta: float) -> void:
	if path.is_empty():
		return
	var next: Vector3 = game._cell_center(path[0])
	if _step_toward(next, speed, delta):
		path.pop_front()


# Move toward a point along the floor
func _step_toward(to: Vector3, speed: float, delta: float) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	var d := flat.length()
	var step: float = speed * game.hunter_speed() * delta   # way faster once the Chaos Emerald's taken
	if d <= step:
		global_position.x = to.x
		global_position.z = to.z
	else:
		global_position += flat / d * step
	var c := _cell(global_position)
	global_position.y = game._floor_at(c, global_position)
	return d <= step + 0.05


# Back away from someone looking at it, toward a corridor they can't see
func _flee_from(w, delta: float) -> void:
	var here := _cell(global_position)
	if path.is_empty() or repath <= 0.0:
		var away: Array[Vector2i] = []
		var best := -INF
		for n in game._neighbours(here):
			var score: float = game._cell_center(n).distance_to(w.feet)
			if _clear(w.eye, game._cell_center(n) + Vector3(0, 1.0, 0)):
				score -= 6.0   # still in sight there
			if score > best:
				best = score
				away = [n]
		path = away
		repath = 0.5
	_walk_path(flee_speed, delta)


# Every cell exactly this many steps from c through the corridors
func _cells_at(c: Vector2i, steps: int) -> Array[Vector2i]:
	var dist := {c: 0}
	var queue: Array[Vector2i] = [c]
	var ring: Array[Vector2i] = []
	var far := 0
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		if dist[a] > far:
			far = dist[a]
		if dist[a] == steps:
			ring.append(a)
			continue
		for n in game._neighbours(a):
			if not dist.has(n):
				dist[n] = dist[a] + 1
				queue.append(n)
	if ring.is_empty():
		for a in dist:
			if dist[a] == far:
				ring.append(a)
	return ring


func _roam(delta: float) -> void:
	if path.is_empty():
		var c: Vector2i = game.maze_lo + Vector2i(randi() % game.maze_size.x, randi() % game.maze_size.y)
		path = _route(_cell(global_position), c)
	_walk_path(stalk_speed * 0.8, delta)


func _get_angry(w) -> void:
	state = ANGRY
	angry_at = w
	angry_left = angry_time
	path.clear()
	game.bracken_angry(w)


func _calm_down() -> void:
	state = STALK
	anger = 0.0
	angry_at = null
	path.clear()


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	if not game.watcher_dead(w):
		return
	w.alive = false
	anger = 0.0
	angry_at = null
	state = CARRY
	if drag_to_den and den != Vector2i(-1, -1):
		# Back to its den with them, then back to the hunt
		dragging = w
		path = _route(_cell(global_position), den)
		return
	# Off to its corner with them, then back to the hunt
	carry_left = carry_time
	path = _route(_cell(global_position), game.far_cell_from([global_position]))


# Hold the body just behind it, low to the floor, as it walks
func _drag(body: RigidBody3D) -> void:
	if body != _drag_body:
		_let_go()
		_drag_body = body
	if not is_instance_valid(body):
		_drag_body = null
		return
	if not body.freeze:
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
	var back := Vector3.ZERO
	if not path.is_empty():
		var ahead: Vector3 = game._cell_center(path[0]) - global_position
		ahead.y = 0.0
		if ahead.length() > 0.01:
			back = -ahead.normalized()
	elif body.global_position.distance_to(global_position) > 0.01:
		back = Vector3(body.global_position.x - global_position.x, 0, body.global_position.z - global_position.z).normalized()
	var want := global_position + back * 0.7 + Vector3(0, 0.3, 0)
	body.global_position = body.global_position.lerp(want, 0.35)


# Drop the body where it is
func _let_go() -> void:
	if is_instance_valid(_drag_body):
		_drag_body.freeze = false
		_drag_body.linear_velocity = Vector3.ZERO
		_drag_body.angular_velocity = Vector3.ZERO
	_drag_body = null

# Its stand-in picture
func placeholder() -> Texture2D:
	return placeholder_texture()


# A flat stand-in shape
static func blank_figure(w: int, h: int, col: Color, round: float, taper: float) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var edge := col.darkened(0.65)
	var inside := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		var t := float(y) / h
		var half := w * 0.5 * (1.0 - taper * (1.0 - t))
		var cx := absf(x - w * 0.5 + 0.5)
		var cap := w * 0.5 * round
		if y < cap:
			return Vector2(cx, cap - y).length() <= minf(cap, half)
		return cx <= half
	for y in h:
		for x in w:
			if inside.call(x, y):
				var border: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
				img.set_pixel(x, y, edge if border else col)
	return ImageTexture.create_from_image(img)


# A placeholder picture until there's art
static func placeholder_texture() -> Texture2D:
	var w := 40
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Color(0.42, 0.12, 0.09)
	var leaf := Color(0.22, 0.38, 0.14)
	var eye := Color(0.95, 0.9, 0.75)
	for y in h:
		for x in w:
			var cx := absf(x - w * 0.5 + 0.5)
			var on := false
			var col := body
			if y < 26:
				# Leafy head: a ragged round shape
				var r := 13.0 + 3.0 * sin(float(x) * 1.7 + float(y) * 0.9)
				on = Vector2(cx, y - 13.0).length() < r * 0.85
				col = leaf
			elif y < 60:
				on = cx < 7.0 - (y - 26) * 0.03 or (y < 50 and cx < 15.0 - absf(y - 34) * 0.4)   # thin body, long arms
			else:
				on = absf(cx - 3.5) < 2.2   # two thin legs
			if on:
				img.set_pixel(x, y, col)
	for ex in [w / 2 - 4, w / 2 + 3]:
		img.set_pixel(ex, 15, eye)
		img.set_pixel(ex, 16, eye)
	return ImageTexture.create_from_image(img)
