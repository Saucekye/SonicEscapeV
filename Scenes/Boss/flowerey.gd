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

# true: the fight starts as soon as the scene loads.
# false: it waits until begin_fight() is called (e.g. from the level intro's "start" signal).
@export var auto_start: bool = true

# Chase: the player is constantly pushed to the left while the fight is active
@export var chase_push_speed: float = 100.0
@export var chase_phase_bonus: float = 0.5 # extra push per phase (0.5 = +50% in phase 2)

@export var jarona1Count: int = 4
@export var jarona1StartSpeed: float = 600.0
@export var jarona1SpeedIncrease: float = 100.0
@export var jarona1SpeedDecrease: float = 150.0
@export var jarona1MinSpeed: float = 300.0
@export var jarona1MaxSpeed: float = 1600.0
@export var jarona1Overshoot: float = 150.0
@export var jarona1RecoilDistance: float = 140.0
@export var jarona1RecoilTime: float = 0.3
@export var jarona_voice_lines: Array[AudioStream] = []


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
var _last_voice_line: AudioStream
var _last_attack: StringName = &""
var _fight_requested: bool = false

var attack_pools: Array = [
	[&"attack_a", &"attack_Jarona"],
	[&"attack_a", &"attack_Jarona", &"attack_c"],
]

# ---------------- NODES (names match the scene tree) ----------------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var hit_box: Area2D = $Sprite2D/HitBox
@onready var attack_box: Area2D = $Sprite2D/AttackBox
@onready var timer: Timer = $Timer
@onready var voice_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var hit_sfx: Array[AudioStreamPlayer] = [$hitsfx, $hitsfx2]

@onready var markers_a: Array = [$Marker2D1, $Marker2D2, $Marker2D3, $Marker2D6]


# ---------------- LIFECYCLE ----------------
func _ready() -> void:
	if scale_health_with_level:
		max_health = min(50, max(15, Test.level * 2))
	health = max_health
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	attack_box.area_entered.connect(_on_attack_box_area_entered)
	attack_box.monitoring = false
	if auto_start:
		begin_fight.call_deferred()


func _exit_tree() -> void:
	# Safety: never leave the game stuck in slow motion
	Engine.time_scale = 1.0


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

	state = State.INTRO
	await _play_and_wait(&"intro")
	if state != State.INTRO:
		return
	GlobalSignals.disable_boss_ui.emit(false) # show the boss HP bar, like the other bosses
	_emit_health()
	_enter_idle()


func _process(_delta: float) -> void:
	_resync_player()


func _physics_process(delta: float) -> void:
	_push_player_left(delta)


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
	_play_anim(&"Idle")
	timer.start(idle_times[min(phase, idle_times.size() - 1)])


func _on_timer_timeout() -> void:
	if state == State.IDLE:
		_pick_next_attack()


func _pick_next_attack() -> void:
	timer.stop()
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

	_play_voice(jarona_voice_lines)

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

		var start := sprite.global_position
		var dir := (active_player.global_position - start).normalized()
		var target := active_player.global_position + dir * jarona1Overshoot
		var duration := start.distance_to(target) / speed

		_lunge_dir = dir
		_lunge_hit_player = false
		_deflected = false
		_lunging = true
		attack_box.set_deferred("monitoring", true)

		_play_anim(&"Jarona")
		_active_tween = create_tween()
		_active_tween.tween_property(sprite, "global_position", target, duration)
		_active_tween.finished.connect(_end_lunge)
		await lunge_done

		attack_box.set_deferred("monitoring", false)
		if _stale(t): return

		if _deflected:
			await _recoil()
			if _stale(t): return

		if _lunge_hit_player or _deflected:
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


func _on_attack_box_area_entered(area: Area2D) -> void:
	if state != State.ATTACKING or _lunge_hit_player:
		return
	if area.is_in_group("Player"):
		_lunge_hit_player = true
		var victim := area.get_parent()
		if victim.has_method("take_damage"):
			victim.take_damage(1)


# ---------------- ATTACK: A ----------------
func attack_a() -> void:
	var t := _begin_attack()

	var marker: Marker2D = markers_a.pick_random()
	sprite.global_position = marker.global_position

	await _play_and_wait(&"Attack")
	if _stale(t): return

	_end_attack(t)


# ---------------- ATTACK: C ----------------
func attack_c() -> void:
	var t := _begin_attack()

	await _play_and_wait(&"Attack3")
	if _stale(t): return

	_resync_player()
	if active_player == null:
		_end_attack(t)
		return

	var dir := (active_player.global_position - sprite.global_position).normalized()
	# Stored in _active_tween so _die() can kill it
	_active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(sprite, "global_position", sprite.global_position + dir * 900, 0.35)
	await _active_tween.finished
	if _stale(t): return

	_end_attack(t)


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

	defeated.emit()
	end.emit()
	queue_free()
