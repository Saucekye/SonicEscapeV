extends Node2D
## Speed and impact effects for the characters, in the game's
## red / white / black, drawn as pixels on the characters' own pixel grid.
##   - Speed streaks: thin lines whip past while running fast
##   - Sonic boom: a ring bursts out when you break past top speed
##   - Spin dash sparks: every rev kicks sparks off the ground
##   - Hit flash: a pixel starburst where you strike an enemy
## Created by atmosphere.gd. All numbers below are tunable.

const PX := 1.125                    # world units per character art pixel

const SPEED_STREAKS := false      # the speed lines around fast characters (turned off)
const HIT_FLASH := false          # the line burst where you strike an enemy (turned off)
const SONIC_BOOM := false         # the ring that bursts out when you break top speed (turned off)
const STREAK_SPEED := 1150.0         # speed before streaks appear
const STREAK_INTERVAL := 0.025       # seconds between new streaks
const STREAK_LIFE := 0.2
const BOOM_SPEED := 1450.0           # crossing this speed fires a sonic boom
const BOOM_COOLDOWN := 1.4
const BOOM_LIFE := 0.32
const SPARK_COUNT := 7               # sparks per spin dash rev
const HIT_LIFE := 0.16
const WHITE := Color(1, 1, 1)
const RED := Color("e0202c")

var _streaks := []    # {pos, len, dir, life, max, col}
var _rings := []      # {pos, life, dir}
var _sparks := []     # {pos, vel, life, max, col}
var _hits := []       # {pos, life}
var _state := {}      # character -> {streak_t, boom_t, was_fast, charge}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true        # draw in world coordinates
	z_index = 40            # above terrain, rails and characters
	z_as_relative = false
	_rng.randomize()


func _process(delta: float) -> void:
	visible = Test.effects_enabled
	if not visible:
		_streaks.clear(); _rings.clear(); _sparks.clear(); _hits.clear()
		return
	for c in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(c) or not (c is CharacterBody2D) or not c.is_visible_in_tree():
			continue
		_watch(c, delta)
	_age(_streaks, delta)
	_age(_rings, delta)
	_age(_hits, delta)
	for s in _sparks:
		s.vel.y += 1400.0 * delta
		s.pos += s.vel * delta
	_age(_sparks, delta)
	queue_redraw()


func _watch(c: CharacterBody2D, delta: float) -> void:
	if not _state.has(c):
		_state[c] = {"streak_t": 0.0, "boom_t": 0.0, "was_fast": false, "charge": 0}
		if HIT_FLASH and c.has_signal("enemy_hit"):
			c.enemy_hit.connect(func(at: Vector2): _hits.append({"pos": at, "life": HIT_LIFE, "max": HIT_LIFE}))
	var st: Dictionary = _state[c]
	var v: Vector2 = c.velocity
	# Running speed: mostly horizontal travel (a partner's catch-up flight doesn't count)
	var speed := absf(v.x) if absf(v.x) > absf(v.y) else 0.0
	var body := c.global_position + Vector2(0, -28)

	# Speed streaks
	st.streak_t -= delta
	if SPEED_STREAKS and speed > STREAK_SPEED and st.streak_t <= 0.0:
		st.streak_t = STREAK_INTERVAL
		var dir := v.normalized()
		for i in _rng.randi_range(1, 2):
			var side := Vector2(-dir.y, dir.x) * _rng.randf_range(-46, 46)
			var back := -dir * _rng.randf_range(10, 70)
			_streaks.append({"pos": body + side + back, "len": _rng.randf_range(14, 34) * PX, "dir": dir,
				"life": STREAK_LIFE, "max": STREAK_LIFE, "col": RED if _rng.randf() < 0.18 else WHITE})

	# Sonic boom when breaking past top speed
	st.boom_t -= delta
	var fast := speed > BOOM_SPEED
	if SONIC_BOOM and fast and not st.was_fast and st.boom_t <= 0.0:
		st.boom_t = BOOM_COOLDOWN
		_rings.append({"pos": body, "life": BOOM_LIFE, "max": BOOM_LIFE, "dir": v.normalized()})
	st.was_fast = fast

	# Spin dash revs
	var charge := int(c.get("spin_charge")) if c.get("spin_charge") != null else 0
	if charge > int(st.charge):
		var face := -1.0 if (c.get_node_or_null("Sprite2D") and c.get_node("Sprite2D").flip_h) else 1.0
		for i in SPARK_COUNT:
			_sparks.append({"pos": c.global_position + Vector2(-face * _rng.randf_range(4, 16), -4),
				"vel": Vector2(-face * _rng.randf_range(120, 420), -_rng.randf_range(180, 520)),
				"life": 0.35, "max": 0.35, "col": WHITE if i % 3 else RED})
	st.charge = charge


func _age(list: Array, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		list[i].life -= delta
		if list[i].life <= 0.0:
			list.remove_at(i)


func _snap(p: Vector2) -> Vector2:
	return (p / PX).floor() * PX


func _dot(p: Vector2, col: Color, size := 1.0) -> void:
	draw_rect(Rect2(_snap(p), Vector2.ONE * PX * size), col)


func _draw() -> void:
	# Streaks: 1-pixel-tall lines that shrink as they fade
	for s in _streaks:
		var t: float = s.life / s.max
		var n := int(s.len * t / PX)
		var col: Color = s.col
		col.a = 0.75 * t
		for k in n:
			_dot(s.pos - s.dir * k * PX, col)
	# Sonic boom: an expanding pixel ring, squashed along the direction of travel
	for r in _rings:
		var t: float = 1.0 - r.life / r.max
		var radius := lerpf(10.0, 78.0, t)
		var col := WHITE.lerp(RED, t)
		col.a = 1.0 - t
		var dir: Vector2 = r.dir
		var ang := dir.angle()
		var steps := int(radius * 1.2) + 12
		for k in steps:
			var a := TAU * float(k) / float(steps)
			var p := Vector2(cos(a) * radius * 0.45, sin(a) * radius).rotated(ang)
			_dot(r.pos + p, col)
	# Sparks
	for s in _sparks:
		var k: float = s.life / s.max
		var col: Color = s.col
		col.a = k
		_dot(s.pos, col)
	# Hit flash: a pixel starburst
	for h in _hits:
		var t: float = 1.0 - h.life / h.max
		var len := lerpf(6.0, 22.0, t)
		var col := WHITE.lerp(RED, t * 0.7)
		col.a = 1.0 - t * 0.6
		for k in 8:
			var d := Vector2.RIGHT.rotated(TAU * k / 8.0 + PI / 8.0)
			var from := 4.0 + len * 0.4
			for j in int((len - from * 0.5) / PX * 0.5):
				_dot(h.pos + d * (from + j * PX * 2.0), col)
		if t < 0.35:
			_dot(h.pos - Vector2.ONE * PX * 2.0, Color(1, 1, 1, 1.0 - t), 4.0)
