extends Node2D
# Grind sparks, like the Sonic Adventure and Rush rails

const PX := 1.125                   # world units per character art pixel
const RATE := 170.0                 # sparks per second at base grind speed
const HEIGHT := 35.0                # the rail sits this far below the character's middle
const COLOURS := [Color(1, 1, 1), Color("fff0a0"), Color("ffc24a"), Color("ff7a2a")]
const GRAVITY := 700.0

var rail: Node                      # Rail.gd
var _sparks := []                   # {pos, vel, life, max, col}
var _flares := []                   # contact hot spots
var _acc := {}                      # player -> sparks owed
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true                # drawn in world space
	z_index = 6


func _process(delta: float) -> void:
	if rail:
		for p in rail.grinding_players.keys():
			if is_instance_valid(p) and rail.grinding_players[p] and p.grinding:
				_spray(p, delta)
	for s in _sparks:
		s.vel.y += GRAVITY * delta
		s.pos += s.vel * delta
		s.life -= delta
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	for f in _flares:
		f.life -= delta
	_flares = _flares.filter(func(f): return f.life > 0.0)
	queue_redraw()


func _spray(p: Node, delta: float) -> void:
	var r: float = float(p.rot)
	var mx: float = p.motion.x
	var dir := signf(mx) if mx != 0.0 else 1.0
	var fwd := Vector2(cos(r), sin(r)) * dir
	var up := Vector2(0, -1).rotated(r)
	var contact: Vector2 = p.global_position - up * HEIGHT
	_flares.append({"pos": contact, "life": 0.05})
	_acc[p] = float(_acc.get(p, 0.0)) + delta * RATE * clampf(absf(mx) / 600.0, 0.6, 2.2)
	while _acc[p] >= 1.0:
		_acc[p] -= 1.0
		var spd := _rng.randf_range(220, 620) * clampf(absf(mx) / 700.0, 0.8, 1.8)
		var life := _rng.randf_range(0.12, 0.3)
		_sparks.append({"pos": contact + fwd * _rng.randf_range(-4, 4),
			"vel": -fwd * spd + up * _rng.randf_range(80, 380) + Vector2(_rng.randf_range(-40, 40), 0),
			"life": life, "max": life, "col": COLOURS[_rng.randi() % COLOURS.size()]})


func _dot(at: Vector2, col: Color, size := 1) -> void:
	draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX) * size), col)


func _draw() -> void:
	# Sparks: short streaks along their path, white-hot at the head, two pixels thick
	for s in _sparks:
		var k: float = s.life / s.max
		var col: Color = (s.col as Color).lerp(Color("e0202c"), (1.0 - k) * 0.6)
		col.a = clampf(k * 1.6, 0.0, 1.0)
		var d: Vector2 = (s.vel as Vector2).normalized()
		var n := 2 + int(clampf((s.vel as Vector2).length() / 110.0, 0.0, 5.0) * k)
		var side := Vector2(-d.y, d.x)
		for j in n:
			var c2 := col if j > 0 else Color(1, 1, 0.9, col.a)
			_dot(s.pos - d * PX * j, c2)
			if j < n - 1:
				_dot(s.pos - d * PX * j + side * PX, c2)
	# Where the feet meet the rail
	for f in _flares:
		var size := 3 if _rng.randf() < 0.5 else 5
		_dot(f.pos - Vector2.ONE * PX * (size + 2) / 2.0, Color(1, 0.6, 0.15, 0.45), size + 2)
		_dot(f.pos - Vector2.ONE * PX * size / 2.0, Color(1, 0.97, 0.85, 1.0), size)
		for i in 3:
			_dot(f.pos + Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-6, 3)), Color(1, 0.85, 0.4, 0.9))
