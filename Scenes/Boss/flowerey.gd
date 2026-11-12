extends Node2D

signal health_changed(current: int, maximum: int)
# Same signal the other bosses use to drive the boss HP bar
signal update_health_bar(boss_health: int, boss_max_health: int)
signal phase_changed(new_phase: int)
signal defeated
signal end # emitted on death; the chunk's level script listens to this
signal lunge_done

enum State { INACTIVE, INTRO, IDLE, ATTACKING, DYING }


# ---------------- TUNING ----------------
# true: health is computed like the other bosses, clamp(Test.level * 2, 15, 50).
# false: the max_health value below is used as is.
@export var scale_health_with_level: bool = true
@export var max_health: int = 30
@export var phase_thresholds: Array[float] = [0.5]
@export var idle_times: Array[float] = [3.0, 1.8]
@export var hits_to_interrupt_idle: int = 3

# Bug testing: anything other than "None" makes him use only that attack, in any phase.
@export_enum("None", "attack_Jarona", "attack_Jarona2", "attack_Jarona3") var debug_force_attack: String = "None"

# true: the fight starts as soon as the scene loads.
# false: it waits until begin_fight() is called (e.g. from the level intro's "start" signal).
@export var auto_start: bool = true

# Testing shortcut: jump the "intro" animation straight to its last frame instead of playing it.
@export var skip_intro: bool = false

# Where Flowery waits while idling and returns to between lunges.
# Add a Marker2D named "IdlePoint" under this node and move it where you want him.
# If there is none, he uses the position his sprite has when the fight starts.
@export var home_return_time: float = 0.4

# Chase: the player is constantly pushed to the left while the fight is active
@export var chase_push_speed: float = 100.0
@export var chase_phase_bonus: float = 0.5 # extra push per phase (0.5 = +50% in phase 2)

# Jarona (homing lunge)
@export var jarona1Count: int = 4
@export var jarona1StartSpeed: float = 600.0
@export var jarona1SpeedIncrease: float = 100.0
@export var jarona1SpeedDecrease: float = 150.0
@export var jarona1MinSpeed: float = 300.0
@export var jarona1MaxSpeed: float = 1600.0
@export var jarona1MaxLungeTime: float = 2.0 # safety: lunge ends after this long even without a hit
@export var jarona1RecoilDistance: float = 140.0
@export var jarona1RecoilTime: float = 0.3
@export var jarona_voice_lines: Array[AudioStream] = []

# Jarona 2 (homing lunge + summoned hitboxes, spawned after each punch)
@export var jarona2HitboxScene: PackedScene # an Area2D scene; if empty, a placeholder circle (with no animation) is built in code
@export var jarona2HitboxAnim: StringName = &"" # played when the hitbox spawns; empty = autoplay, else the first non-RESET animation
@export var jarona2HitboxLaunchAnim: StringName = &"" # optional: played when it launches forward
@export var jarona2HitboxRadius: float = 28.0 # placeholder only
@export var jarona2HitboxSpread: float = 90.0 # distance of each hitbox from his centre, perpendicular to the lunge
@export var jarona2BackDistance: float = 120.0 # how far past the idle point they drift
@export var jarona2BackTime: float = 0.35 # drift back + settle on the player's altitude, then launch immediately
@export var jarona2LockOffsetMin: float = 0.0 # px above/below the player's altitude (0 = exact)
@export var jarona2LockOffsetMax: float = 90.0
@export var jarona2ForwardSpeed: float = 700.0
@export var jarona2ForwardDistance: float = 1800.0
@export var jarona2FlipToDirection: bool = false # flip the hitbox to face its travel direction (assumes the art faces right)

# Jarona 3 (walls of three hitboxes: ground + ceiling always hurt, the middle one breaks when the player stomps/attacks it)
# Positions below use the arena's coordinates (the same numbers the editor shows for nodes in the arena scene).
@export var jarona3Count: int = 3 # how many walls per attack
@export var jarona3Spacing: float = 500.0 # distance in px between one wall and the next
@export var jarona3Speed: float = 500.0
@export var jarona3SpaceNode: NodePath # node whose coordinates the four numbers below use. Empty = Flowery's parent (the arena)
@export var jarona3StartX: float = 2000.0 # x where each wall appears
@export var jarona3EndX: float = 500.0 # x where it is removed
@export var jarona3GroundY: float = 700.0 # y of the floor: the bottom of the ground block sits here
@export var jarona3CeilingY: float = 70.0 # y of the ceiling: the top of the ceiling block sits here
@export var jarona3WindupTime: float = 0.5 # Flowery's windup before the first wall
@export var jarona3TelegraphTime: float = 0.4 # each wall shows up faded and harmless this long before it launches
@export var jarona3HitboxWidth: float = 60.0 # thickness of the ground/ceiling blocks (the safe block uses its texture's width when it has one)
@export var jarona3MiddleSizeMin: float = 60.0 # height of the middle block (random between min and max)
@export var jarona3MiddleSizeMax: float = 160.0
@export var jarona3MiddleHeightMin: float = 150.0 # centre of the middle block, px above the ground (random between min and max)
@export var jarona3MiddleHeightMax: float = 400.0

# Wall art. Leave empty to keep the placeholder rectangles (red = hurts, blue = safe/breakable).
# The collision box always matches the block size.
enum WallArt { STRETCH, TILE } # STRETCH: art is scaled to fill the block. TILE: art repeats at its own size.
@export var jarona3HurtTexture: Texture2D # ground + ceiling blocks (width = jarona3HitboxWidth)
@export var jarona3SafeTexture: Texture2D # middle block: keeps the texture's own width, only its height changes
@export var jarona3SafeTint: Color = Color(0.4, 0.7, 1.0) # tint applied to the safe texture (white = no tint); also the colour of the break particles
@export var jarona3ArtMode: WallArt = WallArt.STRETCH
@export var jarona3FlipToDirection: bool = false # mirror the wall to face its travel direction (assumes the art faces right)


# ---------------- STATE ----------------
var state: State = State.INACTIVE
var health: int
var phase: int = 0
var hits_while_idle: int = 0
var active_player: CharacterBody2D

var _attack_token: int = 0
var _active_tween: Tween
var _lunging: bool = false
var _lunge_hit_player: bool = false
var _deflected: bool = false
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_speed: float = 0.0
var _lunge_time_left: float = 0.0
var _last_voice_line: AudioStream
var _last_attack: StringName = &""
var _fight_requested: bool = false
var _home_position: Vector2

var attack_pools: Array = [
	[&"attack_Jarona"],
	[&"attack_Jarona", &"attack_Jarona2", &"attack_Jarona3"],
]

# ---------------- NODES (names match the scene tree) ----------------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var hit_box: Area2D = $Sprite2D/HitBox
@onready var attack_box: Area2D = $Sprite2D/AttackBox
@onready var timer: Timer = $Timer
@onready var voice_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var hit_sfx: Array[AudioStreamPlayer] = [$hitsfx, $hitsfx2]
@onready var idle_point: Marker2D = get_node_or_null("IdlePoint")


# ---------------- LIFECYCLE ----------------
func _ready() -> void:
	if scale_health_with_level:
		max_health = min(50, max(15, Test.level * 2))
	health = max_health
	timer.one_shot = true
	# Guarded so it also works when the scene already has these connected in the editor
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)
	if not attack_box.area_entered.is_connected(_on_attack_box_area_entered):
		attack_box.area_entered.connect(_on_attack_box_area_entered)
	if not attack_box.body_entered.is_connected(_on_attack_box_body_entered):
		attack_box.body_entered.connect(_on_attack_box_body_entered)
	attack_box.monitoring = false
	_connect_end_to_level()
	if auto_start:
		begin_fight.call_deferred()


func _exit_tree() -> void:
	# Safety: never leave the game stuck in slow motion
	Engine.time_scale = 1.0


# The chunk's level script handles "end" in _on_node_2d_end. Connecting it from code means
# the level still ends if the editor connection was lost when the boss was swapped.
func _connect_end_to_level() -> void:
	var level := get_parent()
	if level == null or not level.has_method("_on_node_2d_end"):
		return
	var handler := Callable(level, "_on_node_2d_end")
	if not end.is_connected(handler):
		end.connect(handler)


# Call this to start the fight. Safe to call more than once: only the first call counts.
func begin_fight() -> void:
	if _fight_requested:
		return
	_fight_requested = true
	_start_fight()


func _start_fight() -> void:
	# Wait until the player exists
	_resync_player()
	while active_player == null:
		await get_tree().process_frame
		_resync_player()

	# Read after the chunk has been placed in the level, not in _ready
	_home_position = sprite.global_position
	sprite.global_position = _home()

	GlobalSignals.disable_boss_ui.emit(false) # show the boss HP bar, like the other bosses
	_emit_health()
	_enter_idle()


func _process(_delta: float) -> void:
	_resync_player()


func _physics_process(delta: float) -> void:
	_push_player_left(delta)
	_home_in(delta)


# ---------------- CHASE PUSH ----------------
func _push_player_left(delta: float) -> void:
	if state == State.INACTIVE or state == State.INTRO or state == State.DYING:
		return
	if active_player == null or not is_instance_valid(active_player):
		return
	var push_speed := chase_push_speed * (1.0 + phase * chase_phase_bonus)
	# move_and_collide respects walls, so the player can be pinned against the edge
	active_player.move_and_collide(Vector2.LEFT * push_speed * delta)


# ---------------- PLAYER TRACKING ----------------
func _resync_player() -> void:
	var players := get_tree().get_nodes_in_group("active_player")
	if players.size() > 0 and is_instance_valid(players[0]):
		active_player = players[0]
		return
	# Fallback used by the other bosses
	for body in get_tree().get_nodes_in_group("all_characters"):
		if is_instance_valid(body) and "is_player" in body and body.is_player == true:
			active_player = body
			return


# ---------------- HOME POSITION ----------------
func _home() -> Vector2:
	if idle_point:
		return idle_point.global_position
	return _home_position


# Moves the sprite back to the idle point. Stored in _active_tween so _die() can kill it.
func _return_home() -> void:
	_active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(sprite, "global_position", _home(), home_return_time)
	await _active_tween.finished


# ---------------- HEALTH UI ----------------
func _emit_health() -> void:
	health_changed.emit(health, max_health)
	update_health_bar.emit(health, max_health)


# ---------------- ATTACK LOOP ----------------
func _enter_idle() -> void:
	if state == State.DYING:
		return
	state = State.IDLE
	hits_while_idle = 0
	_play_anim(&"Floweridle")
	timer.start(idle_times[min(phase, idle_times.size() - 1)])


func _on_timer_timeout() -> void:
	if state == State.IDLE:
		_pick_next_attack()


func _pick_next_attack() -> void:
	timer.stop()
	if debug_force_attack != "None" and has_method(debug_force_attack):
		_last_attack = StringName(debug_force_attack)
		call(_last_attack)
		return
	var pool: Array = attack_pools[min(phase, attack_pools.size() - 1)].duplicate()
	if pool.size() > 1:
		pool.erase(_last_attack)
	_last_attack = pool.pick_random()
	call(_last_attack)


# ---------------- ATTACK HELPERS ----------------
func _begin_attack() -> int:
	timer.stop()
	state = State.ATTACKING
	_attack_token += 1
	return _attack_token


func _stale(token: int) -> bool:
	return token != _attack_token or state != State.ATTACKING


func _end_attack(token: int) -> void:
	if _stale(token):
		return
	_enter_idle()


# Plays an animation only if it exists, so a typo gives a warning instead of an error.
func _play_anim(anim_name: StringName) -> void:
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		push_warning("Flowery: missing animation '%s'" % anim_name)


# Waits for the animation length with a timer instead of "animation_finished",
# so a missing or looping animation can never freeze the fight.
func _play_and_wait(anim_name: StringName) -> void:
	if not anim.has_animation(anim_name):
		push_warning("Flowery: missing animation '%s'" % anim_name)
		return
	anim.play(anim_name)
	await get_tree().create_timer(anim.current_animation_length).timeout


# ---------------- VOICE ----------------
func _play_voice(lines: Array[AudioStream]) -> void:
	if lines.is_empty():
		return
	var choices := lines.duplicate()
	if choices.size() > 1:
		choices.erase(_last_voice_line)
	_last_voice_line = choices.pick_random()
	voice_player.stream = _last_voice_line
	voice_player.play()


# ---------------- ATTACK: JARONA ----------------
func attack_Jarona() -> void:
	var t := _begin_attack()
	var speed := jarona1StartSpeed
	var telegraphAttack := 0.5

	for i in jarona1Count:
		_resync_player()
		if active_player == null:
			break

		_play_anim(&"jaronaWindup")
		await get_tree().create_timer(telegraphAttack).timeout
		if _stale(t): return

		_resync_player()
		if active_player == null:
			break

		_lunge_dir = (active_player.global_position - sprite.global_position).normalized()
		_lunge_speed = speed
		_lunge_time_left = jarona1MaxLungeTime
		_lunge_hit_player = false
		_deflected = false
		_lunging = true
		attack_box.set_deferred("monitoring", true)

		_play_voice(jarona_voice_lines) # random clip on every lunge
		_play_anim(&"Jarona")
		await lunge_done

		attack_box.set_deferred("monitoring", false)
		if _stale(t): return

		if _deflected:
			await _recoil()
			if _stale(t): return

		# Back to the idle point before the next lunge starts
		await _return_home()
		if _stale(t): return

		# Player got hurt: ease off. Parried or timed out: speed up.
		if _lunge_hit_player:
			speed = max(speed - jarona1SpeedDecrease, jarona1MinSpeed)
			telegraphAttack = min(telegraphAttack + 0.08, 0.5)
		else:
			speed = min(speed + jarona1SpeedIncrease, jarona1MaxSpeed)
			telegraphAttack = max(telegraphAttack - 0.08, 0.15)

		await get_tree().create_timer(0.15).timeout
		if _stale(t): return

	await _play_and_wait(&"Idle")
	if _stale(t): return
	_end_attack(t)


# ---------------- ATTACK: JARONA 2 (lunge + summoned hitboxes) ----------------
func attack_Jarona2() -> void:
	var t := _begin_attack()
	var speed := jarona1StartSpeed
	var telegraphAttack := 0.5

	for i in jarona1Count:
		_resync_player()
		if active_player == null:
			break

		_play_anim(&"jaronaWindup")
		await get_tree().create_timer(telegraphAttack).timeout
		if _stale(t): return

		_resync_player()
		if active_player == null:
			break

		_lunge_dir = (active_player.global_position - sprite.global_position).normalized()
		_lunge_speed = speed
		_lunge_time_left = jarona1MaxLungeTime
		_lunge_hit_player = false
		_deflected = false
		_lunging = true
		attack_box.set_deferred("monitoring", true)

		_play_voice(jarona_voice_lines)
		_play_anim(&"Jarona")
		await lunge_done

		attack_box.set_deferred("monitoring", false)
		if _stale(t): return

		# The punch is over: the hitboxes appear now and fly while he recovers
		_summon_hitboxes()

		if _deflected:
			await _recoil()
			if _stale(t): return

		await _return_home()
		if _stale(t): return

		if _lunge_hit_player:
			speed = max(speed - jarona1SpeedDecrease, jarona1MinSpeed)
			telegraphAttack = min(telegraphAttack + 0.08, 0.5)
		else:
			speed = min(speed + jarona1SpeedIncrease, jarona1MaxSpeed)
			telegraphAttack = max(telegraphAttack - 0.08, 0.15)

		await get_tree().create_timer(0.15).timeout
		if _stale(t): return

	await _play_and_wait(&"recoverJarona")
	if _stale(t): return

	_end_attack(t)


# ---------------- ATTACK: JARONA 3 (walls of hitboxes) ----------------
func attack_Jarona3() -> void:
	var t := _begin_attack()
	_resync_player()
	if active_player == null:
		_end_attack(t)
		return

	# Walls travel from StartX to EndX
	var dir := Vector2.RIGHT if jarona3EndX > jarona3StartX else Vector2.LEFT

	_play_anim(&"jaronaWindup")
	await get_tree().create_timer(jarona3WindupTime).timeout
	if _stale(t): return

	for i in jarona3Count:
		_spawn_wall(dir)
		if i < jarona3Count - 1:
			# Every wall moves at the same speed, so a time gap of spacing / speed gives a constant distance
			await get_tree().create_timer(jarona3Spacing / maxf(jarona3Speed, 1.0)).timeout
			if _stale(t): return

	await _play_and_wait(&"recoverJarona")
	if _stale(t): return
	_end_attack(t)


func _ground_y() -> float:
	return jarona3GroundY


func _ceiling_y() -> float:
	return jarona3CeilingY


# The node whose coordinate space the Jarona 3 numbers are in: the one set in the Inspector,
# otherwise Flowery's parent (the arena).
func _wall_host() -> Node:
	var n: Node = null
	if not jarona3SpaceNode.is_empty():
		n = get_node_or_null(jarona3SpaceNode)
	if n == null:
		n = get_parent()
	return n


# One wall = a ground block, a ceiling block and a breakable middle block, moving together.
func _spawn_wall(dir: Vector2) -> void:
	var spawn_x := jarona3StartX
	var ground_y := _ground_y()
	var ceiling_y := _ceiling_y()

	# Middle block: random size and height, kept between the ground and ceiling blocks
	var mid_size := randf_range(minf(jarona3MiddleSizeMin, jarona3MiddleSizeMax), maxf(jarona3MiddleSizeMin, jarona3MiddleSizeMax))
	var mid_height := randf_range(minf(jarona3MiddleHeightMin, jarona3MiddleHeightMax), maxf(jarona3MiddleHeightMin, jarona3MiddleHeightMax))
	# The middle block has to fit between the ceiling and the ground
	mid_size = minf(mid_size, maxf(ground_y - ceiling_y, 0.0))
	var mid_y := clampf(ground_y - mid_height, ceiling_y + mid_size * 0.5, ground_y - mid_size * 0.5)
	var mid_top := mid_y - mid_size * 0.5
	var mid_bottom := mid_y + mid_size * 0.5

	var wall := Node2D.new()
	# The wall lives in the arena (Flowery's parent), not under Flowery, so his own position can't
	# affect it. Every number here is in the arena's coordinates, like the editor shows them.
	_wall_host().add_child(wall)
	wall.position = Vector2(spawn_x, 0.0)
	wall.add_to_group("jarona_hitbox") # so _die() clears it
	wall.modulate.a = 0.35 # telegraph: faded and harmless until it launches
	if jarona3FlipToDirection:
		wall.scale.x = 1.0 if dir.x > 0.0 else -1.0

	# Shared by the three blocks: the wall hurts the player once at most
	var wave := {"hit": false}
	# Hurt blocks start at the ceiling and at the ground and end where the middle block begins,
	# so their size is calculated and nothing overlaps
	var ceiling_h := mid_top - ceiling_y
	if ceiling_h >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, ceiling_y + ceiling_h * 0.5, ceiling_h, false)
	var ground_h := ground_y - mid_bottom
	if ground_h >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, mid_bottom + ground_h * 0.5, ground_h, false)
	if mid_size >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, mid_y, mid_size, true)

	var tw := wall.create_tween()
	tw.tween_interval(jarona3TelegraphTime)
	tw.tween_callback(_arm_wall.bind(wall))
	tw.tween_property(wall, "position:x",
		jarona3EndX,
		absf(jarona3EndX - spawn_x) / maxf(jarona3Speed, 1.0))
	tw.tween_callback(wall.queue_free)


func _add_wall_piece(wall: Node2D, wave: Dictionary, x: float, center_y: float, height: float, breakable: bool) -> void:
	var piece := Area2D.new()

	# The safe block keeps its texture's own thickness; only its height is randomised
	var width := jarona3HitboxWidth
	if breakable and jarona3SafeTexture:
		width = float(jarona3SafeTexture.get_width())

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	piece.add_child(shape)

	piece.add_child(_make_wall_visual(Vector2(width, height), breakable))

	# Same layers as his lunge hitbox so it detects the player the same way
	piece.collision_layer = attack_box.collision_layer
	piece.collision_mask = attack_box.collision_mask
	if breakable:
		# Also detect the player's attacks, the same ones that hurt Flowery's own hit box
		piece.collision_mask |= hit_box.collision_mask
	piece.monitoring = false # switched on when the wall launches
	piece.monitorable = false
	piece.area_entered.connect(_on_wall_area_entered.bind(piece, wave, breakable))
	piece.body_entered.connect(_on_wall_body_entered.bind(piece, wave, breakable))

	wall.add_child(piece)
	piece.position = Vector2(x - wall.position.x, center_y)


# Builds the look of one block: a texture, or the placeholder rectangle.
func _make_wall_visual(size: Vector2, breakable: bool) -> Node2D:
	var tex: Texture2D = jarona3SafeTexture if breakable else jarona3HurtTexture

	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		if breakable:
			s.modulate = jarona3SafeTint
		if jarona3ArtMode == WallArt.TILE:
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(Vector2.ZERO, size)
		else:
			s.scale = size / tex.get_size()
		return s

	# Placeholder: red = always hurts, blue = safe/breakable
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	poly.color = Color(0.3, 0.8, 1.0, 0.8) if breakable else Color(1.0, 0.3, 0.4, 0.8)
	return poly


func _arm_wall(wall: Node2D) -> void:
	if not is_instance_valid(wall):
		return
	wall.modulate.a = 1.0
	for piece in wall.get_children():
		if piece is Area2D:
			piece.set_deferred("monitoring", true)


func _on_wall_area_entered(area: Area2D, piece: Area2D, wave: Dictionary, breakable: bool) -> void:
	if piece.has_meta(&"broken"):
		return

	# Stomping or attacking the middle block breaks it (same groups that interrupt Flowery)
	if breakable and area.is_in_group("Playerattack"):
		_break_wall_piece(piece)
		if area.is_in_group("Player"):
			var p = area.get_parent()
			if "can_stomp" in p:
				p.can_stomp = true
			if "bounce" in p:
				p.bounce = 0
		return

	if wave["hit"] or not area.is_in_group("Player"):
		return
	wave["hit"] = true
	_hurt_player(area)


func _on_wall_body_entered(body: Node2D, piece: Area2D, wave: Dictionary, breakable: bool) -> void:
	if body != active_player or wave["hit"]:
		return
	if breakable:
		# Give a stomp one physics frame to break the block before the body counts as a hit
		await get_tree().physics_frame
		if not is_instance_valid(piece) or piece.has_meta(&"broken") or wave["hit"]:
			return
	wave["hit"] = true
	_hurt_player(body)


func _break_wall_piece(piece: Area2D) -> void:
	if piece.has_meta(&"broken"):
		return
	piece.set_meta(&"broken", true)
	piece.set_deferred("monitoring", false)
	_spawn_break_particles(piece)
	piece.queue_free()


# Small blue burst where the safe block was.
# The particles live in the arena (not in the piece), because the piece is freed right away.
func _spawn_break_particles(piece: Area2D) -> void:
	# Cover the block's area; the first child of each piece is its CollisionShape2D
	var size := Vector2(40.0, 40.0)
	var col := piece.get_child(0) as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		size = (col.shape as RectangleShape2D).size

	var p := CPUParticles2D.new()
	_wall_host().add_child(p)
	p.global_position = piece.global_position

	p.one_shot = true
	p.explosiveness = 1.0 # all particles at once = explosion
	p.amount = 18
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size * 0.5
	p.direction = Vector2.ZERO
	p.spread = 180.0 # any direction
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.damping_min = 150.0 # slows them down so it reads as a pop
	p.damping_max = 250.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = jarona3SafeTint # same blue as the block

	# Fade out each particle over its own life
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad

	p.finished.connect(p.queue_free)
	p.emitting = true


# ---------------- LUNGE (shared by both Jarona attacks) ----------------
# Steers toward the player every physics frame while a lunge is active.
func _home_in(delta: float) -> void:
	if not _lunging:
		return
	if active_player == null or not is_instance_valid(active_player):
		_end_lunge()
		return

	var to_player := active_player.global_position - sprite.global_position
	var step := _lunge_speed * delta
	if to_player.length() <= step:
		sprite.global_position = active_player.global_position
	else:
		_lunge_dir = to_player.normalized() # also keeps the recoil direction correct
		sprite.global_position += _lunge_dir * step

	_lunge_time_left -= delta
	if _lunge_time_left <= 0.0:
		_end_lunge()


func _end_lunge() -> void:
	if _lunging:
		_lunging = false
		lunge_done.emit()


func _deflect() -> void:
	_deflected = true
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()


func _recoil() -> void:
	_play_anim(&"Deflected")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "global_position", sprite.global_position - _lunge_dir * jarona1RecoilDistance, jarona1RecoilTime)
	await tween.finished
	await get_tree().create_timer(0.25).timeout


# ---------------- PLAYER DAMAGE ----------------
# Finds whoever can be hurt: the node itself, or its nearest parent that has hurt()
func _hurt_player(node: Node) -> bool:
	var n := node
	while n != null and n != get_tree().root:
		if n.has_method("hurt"):
			n.hurt()
			return true
		n = n.get_parent()
	return false


func _on_attack_box_area_entered(area: Area2D) -> void:
	if state != State.ATTACKING or _lunge_hit_player:
		return
	if area.is_in_group("Player"):
		_lunge_hit_player = true
		_hurt_player(area)
		_end_lunge()


func _on_attack_box_body_entered(body: Node2D) -> void:
	if state != State.ATTACKING or _lunge_hit_player or body != active_player:
		return
	_lunge_hit_player = true
	_hurt_player(body)
	_end_lunge()


# ---------------- SUMMONED HITBOXES ----------------
func _summon_hitboxes() -> void:
	# At the end of a punch he is standing on the player, so use the lunge direction
	var forward: Vector2 = _lunge_dir if _lunge_dir.length() > 0.01 else Vector2.LEFT
	var back := -forward
	var side := forward.orthogonal()

	for s in [-1.0, 1.0]:
		var offset: Vector2 = side * s * jarona2HitboxSpread
		var hb := _make_hitbox()
		add_child(hb)
		hb.global_position = sprite.global_position + offset
		_play_hitbox_anim(hb, jarona2HitboxAnim)

		# One hitbox ends up above the player's altitude, the other below
		var lock_offset: float = s * randf_range(jarona2LockOffsetMin, jarona2LockOffsetMax)
		var back_x: float = (_home() + back * jarona2BackDistance + offset).x

		# Single tween: drift back AND settle on the player's altitude at the same time.
		# When it ends, the hitbox is behind Flowery at the player's height, so it launches immediately.
		var tw := hb.create_tween()
		tw.tween_method(_drift_back.bind(hb, hb.global_position, back_x, lock_offset), 0.0, 1.0, jarona2BackTime)
		tw.tween_callback(_send_hitbox_forward.bind(hb))


# t goes 0 -> 1. X heads to the spot behind Flowery, Y heads to the player's *current* altitude,
# so the height is always up to date and exactly locked on arrival (t = 1).
func _drift_back(t: float, hb: Area2D, start: Vector2, back_x: float, lock_offset: float) -> void:
	if not is_instance_valid(hb):
		return
	var e := sin(t * PI * 0.5) # sine ease-out
	var target_y := start.y
	if active_player and is_instance_valid(active_player):
		target_y = active_player.global_position.y + lock_offset
	hb.global_position = Vector2(
		lerpf(start.x, back_x, e),
		lerpf(start.y, target_y, e)
	)


# Altitude is locked by now: travel in a perfectly horizontal line, no homing
func _send_hitbox_forward(hb: Area2D) -> void:
	if not is_instance_valid(hb):
		return

	hb.set_deferred("monitoring", true) # only dangerous once launched

	var dir := Vector2.LEFT
	if active_player and is_instance_valid(active_player):
		if active_player.global_position.x > hb.global_position.x:
			dir = Vector2.RIGHT

	if jarona2FlipToDirection:
		hb.scale.x = absf(hb.scale.x) * (1.0 if dir.x > 0.0 else -1.0)
	_play_hitbox_anim(hb, jarona2HitboxLaunchAnim)

	var tw := hb.create_tween()
	tw.tween_property(hb, "global_position:x",
		hb.global_position.x + dir.x * jarona2ForwardDistance,
		jarona2ForwardDistance / jarona2ForwardSpeed)
	tw.tween_callback(hb.queue_free)


func _make_hitbox() -> Area2D:
	var hb: Area2D
	var is_placeholder := false
	if jarona2HitboxScene:
		hb = jarona2HitboxScene.instantiate() as Area2D
		if hb == null:
			push_warning("Flowery: jarona2HitboxScene's root must be an Area2D")
			hb = Area2D.new()
			is_placeholder = true
	else:
		push_warning("Flowery: jarona2HitboxScene is empty, using the placeholder (it has no animation)")
		hb = Area2D.new()
		is_placeholder = true

	if is_placeholder:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = jarona2HitboxRadius
		shape.shape = circle
		hb.add_child(shape)
		# Placeholder visual so you can see it; assign a scene for real art
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			pts.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * jarona2HitboxRadius)
		poly.polygon = pts
		poly.color = Color(1.0, 0.3, 0.4, 0.8)
		hb.add_child(poly)

	# Use the same layers as his lunge hitbox so it detects the player the same way
	hb.collision_layer = attack_box.collision_layer
	hb.collision_mask = attack_box.collision_mask
	hb.monitoring = false # switched on when it launches
	hb.monitorable = false
	hb.add_to_group("jarona_hitbox")
	hb.area_entered.connect(_on_summoned_hitbox_area_entered.bind(hb))
	hb.body_entered.connect(_on_summoned_hitbox_body_entered.bind(hb))
	return hb


# Plays an animation on whatever animation node the hitbox scene contains.
# An empty name uses the autoplay animation, otherwise the first one that isn't RESET.
func _play_hitbox_anim(hb: Node, anim_name: StringName) -> void:
	var players := hb.find_children("*", "AnimationPlayer", true, false)
	var sprites := hb.find_children("*", "AnimatedSprite2D", true, false)
	if players.is_empty() and sprites.is_empty():
		if anim_name != &"":
			push_warning("Flowery: hitbox has no AnimationPlayer or AnimatedSprite2D to play '%s'" % anim_name)
		return

	for node in players:
		var ap := node as AnimationPlayer
		var pick: StringName = anim_name
		if pick == &"" or not ap.has_animation(pick):
			if pick != &"":
				push_warning("Flowery: hitbox has no animation '%s'" % pick)
			pick = &""
			if ap.autoplay != "" and ap.has_animation(StringName(ap.autoplay)):
				pick = StringName(ap.autoplay)
			else:
				for n in ap.get_animation_list():
					if n != "RESET":
						pick = StringName(n)
						break
		if pick != &"":
			ap.play(pick)
			return

	for node in sprites:
		var spr := node as AnimatedSprite2D
		if spr.sprite_frames == null:
			continue
		var pick: StringName = anim_name
		if pick == &"" or not spr.sprite_frames.has_animation(pick):
			pick = &""
			var names := spr.sprite_frames.get_animation_names()
			if names.size() > 0:
				pick = StringName(names[0])
		if pick != &"":
			spr.play(pick)
			return


# Deliberately ignores the boss's state: it hurts the player even while he is idle or attacking
func _on_summoned_hitbox_area_entered(area: Area2D, hb: Area2D) -> void:
	if hb.has_meta(&"hit") or not area.is_in_group("Player"):
		return
	hb.set_meta(&"hit", true) # each hitbox hurts once
	_hurt_player(area)


func _on_summoned_hitbox_body_entered(body: Node2D, hb: Area2D) -> void:
	if hb.has_meta(&"hit") or body != active_player:
		return
	hb.set_meta(&"hit", true)
	_hurt_player(body)


func _clear_hitboxes() -> void:
	for hb in get_tree().get_nodes_in_group("jarona_hitbox"):
		hb.queue_free()


# ---------------- DAMAGE ----------------
# Mirrors the other bosses: thrown items ("item") and player attacks ("Playerattack")
# both hurt the boss, and a stomp (area also in "Player") makes the player bounce.
func _on_hit_box_area_entered(area: Area2D) -> void:
	if not (state in [State.IDLE, State.ATTACKING]):
		return

	if area.is_in_group("item"):
		take_damage(1)
		area.get_parent().queue_free()

	if area.is_in_group("Playerattack"):
		take_damage(1)
		if area.is_in_group("Player"):
			var p = area.get_parent()
			if "can_stomp" in p:
				p.can_stomp = true
			if "bounce" in p:
				p.bounce = 0


func take_damage(amount: int = 1) -> void:
	if state == State.DYING or state == State.INTRO or state == State.INACTIVE:
		return

	health = max(health - amount, 0)
	_emit_health()
	hit_sfx.pick_random().play()
	_flash()

	if health <= 0:
		_die()
		return

	if _lunging:
		_deflect()

	_update_phase()

	if state == State.IDLE and hits_to_interrupt_idle > 0:
		hits_while_idle += 1
		if hits_while_idle >= hits_to_interrupt_idle:
			_pick_next_attack()


func _flash(duration: float = 0.1) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_amount", 1.0)
	await get_tree().create_timer(duration).timeout
	mat.set_shader_parameter("flash_amount", 0.0)


# ---------------- PHASES ----------------
func _update_phase() -> void:
	var ratio := health / float(max_health)
	var new_phase := 0
	for threshold in phase_thresholds:
		if ratio <= threshold:
			new_phase += 1
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_on_phase_started(phase)


func _on_phase_started(_new_phase: int) -> void:
	pass


# ---------------- DEATH ----------------
func _die() -> void:
	state = State.DYING
	_attack_token += 1
	GlobalCanvasLayer.tricks += 10 # same reward as the other bosses
	timer.stop()
	_clear_hitboxes()
	voice_player.stop()
	attack_box.set_deferred("monitoring", false)
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()
	_play_anim(&"death")

	# Same death overlay animation the other bosses play, if this scene has it
	var overlay_anim := get_node_or_null("TextureRect/AnimationPlayer") as AnimationPlayer
	if overlay_anim and overlay_anim.has_animation(&"end"):
		overlay_anim.play(&"end")

	Engine.time_scale = 0.25
	var fall := create_tween().set_parallel(true)
	fall.tween_property(sprite, "global_position:y", sprite.global_position.y + 1500, 1.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(sprite, "rotation", sprite.rotation + TAU * 2, 1.2)

	await get_tree().create_timer(0.35, true, false, true).timeout
	Engine.time_scale = 1.0
	await fall.finished

	if end.get_connections().is_empty():
		push_warning("Flowery: 'end' has no listeners, so the level script never learns the boss died")
	defeated.emit()
	end.emit()
	queue_free()
