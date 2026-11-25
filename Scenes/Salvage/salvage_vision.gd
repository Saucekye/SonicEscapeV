extends Control
# Top-down mode's sight

var game: Node3D                 # salvage.gd
var player                       # salvage_player.gd
var cone := 100.0                # degrees
var reach := 11.0                # metres
var rays := 72
var near := 1.4                  # always see this close around you
var color := Color(0, 0, 0, 1)
var soft_edge := 1.6             # metres over which it fades to dark
var soft_sides := 22.0           # degrees past the cone's sides that it fades out over
var waver := 0.05                # how much the edge breathes and wavers


func setup(game_node: Node3D, who) -> void:
	game = game_node
	player = who
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	if player.dead:
		if not is_instance_valid(player.watching):
			draw_rect(Rect2(Vector2.ZERO, size), color)   # nothing to see
		return   # spectating: you see what's around them
	var cam: Camera3D = player.cam
	var k := size / Vector2(player.view.size)
	var eye: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var face: Vector3 = -player.global_transform.basis.z
	var base := atan2(face.z, face.x)
	var half := deg_to_rad(cone) * 0.5
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for p in game.players:
		skip.append(p.get_rid())
	var to_screen := func(w: Vector3) -> Vector2:
		return cam.unproject_position(w) * k
	var mid: Vector2 = to_screen.call(eye)
	var far := size.length() * 2.0
	var t := Time.get_ticks_msec() / 1000.0
	var clear := Color(color, 0.0)
	# One ring all the way round you
	var span := half + deg_to_rad(soft_sides)
	var n := rays + int(rays * soft_sides / maxf(cone, 1.0)) * 2
	var behind := 32
	var rim_in: Array[Vector2] = []
	var rim_out: Array[Vector2] = []
	var outer: Array[Vector2] = []
	for i in n + behind:
		var a: float
		if i <= n:
			a = base - span + 2.0 * span * i / n
		else:
			a = base + span + (TAU - 2.0 * span) * (i - n) / behind
		var d := Vector3(cos(a), 0, sin(a))
		var off := absf(angle_difference(base, a))
		var shut := smoothstep(half - deg_to_rad(soft_sides) * 0.3, span, off)
		var r_in := near
		var r_out := near + soft_edge
		if shut < 1.0:
			# the edge of what you see breathes and wavers a little, like a light
			var wobble := 1.0 + waver * (0.6 * sin(t * 1.7) + 0.4 * sin(a * 9.0 + t * 2.9))
			var q := PhysicsRayQueryParameters3D.create(eye, eye + d * reach * wobble, 1, skip)
			var hit := space.intersect_ray(q)
			var dist: float = eye.distance_to(hit.position) if hit else reach * wobble
			r_in = lerpf(maxf(dist - soft_edge, near), near, shut)
			r_out = maxf(lerpf(dist + soft_edge * 0.35, near + soft_edge, shut), r_in + 0.3)
		rim_in.append(to_screen.call(eye + d * r_in))
		var o: Vector2 = to_screen.call(eye + d * r_out)
		rim_out.append(o)
		outer.append(mid + (o - mid).normalized() * far)
	var count := rim_in.size()
	for i in count:
		var j := (i + 1) % count
		_tri(rim_in[i], rim_in[j], rim_out[j], clear, clear, color)
		_tri(rim_in[i], rim_out[j], rim_out[i], clear, color, color)
		_tri(rim_out[i], rim_out[j], outer[j], color, color, color)
		_tri(rim_out[i], outer[j], outer[i], color, color, color)


func _tri(a: Vector2, b: Vector2, c: Vector2, ca := color, cb := color, cc := color) -> void:
	draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([ca, cb, cc]), PackedVector2Array())
