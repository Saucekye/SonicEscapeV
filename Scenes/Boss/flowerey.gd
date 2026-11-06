extends Node2D

signal health_changed(current: int, maximum: int)
signal phase_changed(new_phase: int)
signal defeated
signal lunge_done

enum State { INACTIVE, INTRO, IDLE, ATTACKING, DYING }


# ---------------- TUNING ----------------
@export var max_health: int = 30
@export var phase_thresholds: Array[float] = [0.5]
@export var idle_times: Array[float] = [3.0, 1.8]
@export var hits_to_interrupt_idle: int = 3

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

var attack_pools: Array = [
	[&"attack_a", &"attack_Jarona"],
	[&"attack_a", &"attack_Jarona", &"attack_c"],
]

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var timer: Timer = $Timer
@onready var lunge_hitbox: Area2D = $Sprite2D/LungeHitbox
@onready var voice_player: AudioStreamPlayer = $VoicePlayer
@onready var hit_sfx: AudioStreamPlayer = get_node_or_null("hitsfx")

@onready var markers_a: Array = [$Marker2D1, $Marker2D2]


# ---------------- LIFECYCLE ----------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	health = max_health
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	$TriggerArea.area_entered.connect(_on_trigger_area_entered)
	$HitBox.area_entered.connect(_on_hitbox_area_entered)
	lunge_hitbox.area_entered.connect(_on_lunge_hitbox_area_entered)
	lunge_hitbox.monitoring = false


func _on_trigger_area_entered(area: Area2D) -> void:
	if state != State.INACTIVE or not area.is_in_group("Player"):
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	_start_fight()


func _start_fight() -> void:
	state = State.INTRO
	_resync_player()
	anim.play("intro")
	await anim.animation_finished
	health_changed.emit(health, max_health)
	_enter_idle()


func _process(_delta: float) -> void:
	_resync_player()


# ---------------- PLAYER TRACKING ----------------
func _resync_player() -> void:
	var players := get_tree().get_nodes_in_group("active_player")
	if players.size() > 0 and is_instance_valid(players[0]):
		active_player = players[0]


# ---------------- ATTACK LOOP ----------------
func _enter_idle() -> void:
	if state == State.DYING:
		return
	state = State.IDLE
	hits_while_idle = 0
	anim.play("Idle")
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


func _play_and_wait(anim_name: StringName) -> void:
	anim.play(anim_name)
	await anim.animation_finished


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

		anim.play("jaronaWindup")
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
		lunge_hitbox.set_deferred("monitoring", true)

		anim.play("Jarona")
		_active_tween = create_tween()
		_active_tween.tween_property(sprite, "global_position", target, duration)
		_active_tween.finished.connect(_end_lunge)
		await lunge_done

		lunge_hitbox.set_deferred("monitoring", false)
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
	anim.play("Deflected")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "global_position", sprite.global_position - _lunge_dir * jarona1RecoilDistance, jarona1RecoilTime)
	await tween.finished
	await get_tree().create_timer(0.25).timeout


func _on_lunge_hitbox_area_entered(area: Area2D) -> void:
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
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "global_position", sprite.global_position + dir * 900, 0.35)
	await tween.finished
	if _stale(t): return

	_end_attack(t)


# ---------------- DAMAGE ----------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Playerattack") and state in [State.IDLE, State.ATTACKING]:
		take_damage(1)


func take_damage(amount: int = 1) -> void:
	if state == State.DYING or state == State.INTRO or state == State.INACTIVE:
		return

	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	if hit_sfx:
		hit_sfx.play()
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
	timer.stop()
	voice_player.stop()
	lunge_hitbox.set_deferred("monitoring", false)
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()
	anim.play("death")

	Engine.time_scale = 0.25
	var fall := create_tween().set_parallel(true)
	fall.tween_property(sprite, "global_position:y", sprite.global_position.y + 1500, 1.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(sprite, "rotation", sprite.rotation + TAU * 2, 1.2)

	await get_tree().create_timer(0.35, true, false, true).timeout
	Engine.time_scale = 1.0
	await fall.finished

	defeated.emit()
	queue_free()
