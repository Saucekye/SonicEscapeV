extends Components_Action

@export var homing_speed: float = 2000.0
@export var homing_range: float = 500.0
@export var max_homing_time: float = 0.6
@export var hit_distance: float = 40.0
@export var hit_bounce_y: float = 650.0
@export var miss_carry_speed_scale: float = 0.4

var reticle: Sprite2D
var reticle_sfx: AudioStreamPlayer
var homing_active := false


func _ready() -> void:
	# Run the base class setup first
	super._ready()

	# Fallback if player wasn't assigned
	if player == null:
		var p = get_tree().get_first_node_in_group("Player")

		if p == null:
			p = get_parent()

		if p != null:
			player = p

	# Create reticle
	reticle = Sprite2D.new()
	reticle.texture = load("res://misc/reticle.png")
	reticle.z_index = 100
	reticle.visible = false
	get_tree().current_scene.add_child.call_deferred(reticle)

	# Create reticle sound
	reticle_sfx = AudioStreamPlayer.new()
	reticle_sfx.stream = load("res://Sounds/SonicSFX/Sonic Homing Attack Reticle SFX.mp3")
	get_tree().current_scene.add_child.call_deferred(reticle_sfx)


func _exit_tree() -> void:
	if is_instance_valid(reticle):
		reticle.queue_free()

	if is_instance_valid(reticle_sfx):
		reticle_sfx.queue_free()


func _process(_delta: float) -> void:
	if player == null:
		return

	if not is_instance_valid(reticle):
		return

	# Only show the reticle while airborne
	if player.is_on_floor() or homing_active:
		reticle.visible = false

		# Stop reticle sound
		if is_instance_valid(reticle_sfx) and reticle_sfx.playing:
			reticle_sfx.stop()

		return

	var target := get_closest_enemy()

	if target != null:
		reticle.visible = true
		reticle.global_position = target.global_position

		# Play reticle sound once when target is acquired
		if is_instance_valid(reticle_sfx) and not reticle_sfx.playing:
			reticle_sfx.play()

	else:
		reticle.visible = false

		# Stop sound when there is no target
		if is_instance_valid(reticle_sfx) and reticle_sfx.playing:
			reticle_sfx.stop()


func has_target() -> bool:
	return get_closest_enemy() != null


func _is_valid_target(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false

	if not enemy is CharacterBody2D:
		return false

	if enemy.get("dying") == null or enemy.get("dying") == true:
		return false

	if not enemy.has_method("dead"):
		return false

	return true


func get_closest_enemy() -> CharacterBody2D:
	if player == null:
		return null

	var closest_enemy: CharacterBody2D = null
	var closest_distance := homing_range

	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not _is_valid_target(enemy):
			continue

		var distance := player.global_position.distance_to(enemy.global_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy


func _can_start() -> bool:
	if player == null:
		return false

	return (
		Input.is_action_just_pressed("ui_accept")
		and not Input.is_action_pressed("ui_down")
		and player.can_dash
		and not player.wall_cast.is_colliding()
		and not player.wall_cast_2.is_colliding()
		and not player.is_coyote_time_active()
		and not homing_active
	)


func action() -> void:
	if not _can_start():
		return

	var target := get_closest_enemy()

	if target == null:
		return

	# Start homing attack
	homing_active = true

	# Hide reticle
	reticle.visible = false

	# Stop reticle sound
	if is_instance_valid(reticle_sfx) and reticle_sfx.playing:
		reticle_sfx.stop()

	player.can_dash = false
	player.can_stomp = true
	player.falling = true
	player.dashed = true
	player.ball = false
	player.crouch = false

	player.ap.play("jump")

	player.fall_gravity = 0

	player.trail.visible = true
	player.smokeemit()

	# Homing attack sound
	player.sfx.pitch_scale = 2
	player.sfx.stream = load("res://Sounds/SonicSFX/SA_113.wav")
	player.sfx.play()

	# Time scales with distance
	var start_dist := player.global_position.distance_to(target.global_position)

	var time_limit := minf(
		start_dist / homing_speed + 0.1,
		max_homing_time
	)

	var elapsed := 0.0
	var last_dist := start_dist
	var hit := false

	while elapsed < time_limit:
		await get_tree().process_frame

		if not is_instance_valid(player):
			homing_active = false
			return

		elapsed += get_process_delta_time()

		# Enemy freed during flight = miss
		if not is_instance_valid(target):
			break

		# Re-aim every frame
		var to_target := target.global_position - player.global_position
		var dist := to_target.length()

		player.motion = to_target.normalized() * homing_speed

		# Check if we hit the enemy
		var overshot := (
			dist > last_dist + 1.0
			and last_dist < hit_distance * 2.0
		)

		if dist <= hit_distance or overshot:
			hit = true
			break

		last_dist = dist

	# Make sure player still exists
	if not is_instance_valid(player):
		homing_active = false
		return

	if hit:
		# Kill enemy if desired
		if is_instance_valid(target) and target.get("dying") != true:
			pass
			# target.set("dying", true)
			# target.dead()

		# Bounce after hitting enemy
		player.motion.x = 0
		player.motion.y = -hit_bounce_y

		# Allow another homing attack
		player.can_dash = true
		player.dashx = true
		player.dashed = false

	else:
		# Missed target
		player.motion *= miss_carry_speed_scale

	# Restore gravity
	player.fall_gravity = player.default

	# Turn off trail
	player.trail.visible = false

	# Finish homing attack
	homing_active = false
