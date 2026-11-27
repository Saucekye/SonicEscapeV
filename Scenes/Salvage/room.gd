extends "res://Scenes/Salvage/bracken.gd"
# ROOM: comes for you like stop-motion, rushes you once it can see you

var rest_left := 0.0
var lunging := false
var _skip_left := 0.0
var _since_skip := 0.0
var _base_offset := Vector2.ZERO

# Set from the Salvage node's ROOM settings
var chase_speed := 3.6           # metres a second on average
var skip_every := 0.3            # seconds it holds still between skips
var lunge_range := 8.0           # this close, and in your sight, it rushes you
var lunge_speed := 10.0          # rushing
var rest_time := 4.0             # how long it stands still after catching someone
var static_range := 16.0         # static starts this close
var static_strength := 0.9       # how thick the static gets right next to it
var twitch := 0.05               # how much it shakes on the spot
var smear := true                # leaves a fading copy of itself behind each skip


func setup(game_node: Node3D, tex: Texture2D) -> void:
	super.setup(game_node, tex)
	_base_offset = offset


func update(delta: float, watchers: Array) -> void:
	if not visible:
		return
	_shade()
	_static(watchers)
	_twitch()
	if rest_left > 0.0:
		rest_left -= delta
		return
	var alive := _alive(watchers)
	var t = _pick_target(alive)
	if t == null:
		lunging = false
		state = STALK
		_skip(delta, func(dt): _roam(dt))
	else:
		state = ANGRY
		if not lunging and _flat_dist(t.feet) < lunge_range and _sees_me(t) and not settling():
			lunging = true   # it's seen you seeing it
		if lunging:
			_chase(t, lunge_speed, delta)   # the rush: no holding still
		else:
			_skip(delta, func(dt): _chase(t, chase_speed, dt))
		if _reach(t) and not settling():
			_kill(t)


# Stop-motion: hold still, then make up all the ground at once
func _skip(delta: float, move: Callable) -> void:
	_since_skip += delta
	_skip_left -= delta
	if _skip_left > 0.0:
		return
	_skip_left = skip_every * randf_range(0.6, 1.4)
	var from := global_position
	move.call(_since_skip)
	_since_skip = 0.0
	if from.distance_to(global_position) > 0.05:
		_smear_at(from)


# Shaking on the spot
func _twitch() -> void:
	if texture == null:
		return
	var w := float(texture.get_width())
	offset = _base_offset + Vector2(randf_range(-1.0, 1.0) * w * twitch, randf_range(-0.3, 0.3) * w * twitch)


# A faint copy of it left where it was, fading fast
func _smear_at(at: Vector3) -> void:
	if not smear or texture == null:
		return
	var g := Sprite3D.new()
	g.texture = texture
	g.pixel_size = pixel_size
	g.offset = offset
	g.billboard = billboard
	g.texture_filter = texture_filter
	g.shaded = false
	g.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	g.modulate = Color(modulate, 0.4)
	game.add_child(g)
	g.global_position = at
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.3)
	tw.tween_callback(g.queue_free)


# The closer it is, the more static
func _static(watchers: Array) -> void:
	for w in watchers:
		if not w.alive:
			continue
		var d := global_position.distance_to(w.feet)
		var k := clampf(1.0 - d / static_range, 0.0, 1.0)
		w.static = maxf(w.get("static", 0.0), k * k * static_strength)


func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	rest_left = 0.0


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	if not game.watcher_dead(w):
		return
	w.alive = false
	lunging = false
	path.clear()
	rest_left = rest_time


func placeholder() -> Texture2D:
	return blank_figure(30, 100, Color(0.05, 0.05, 0.06), 1.0, 0.3)   # a black figure
