extends CharacterBody2D

const GROUNDED := preload("res://Scripts/Obstacles/grounded_sprite.gd")

@export var textures : Array[Texture2D]

# Physics variables
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var bounce_factor = 0.0
var wall_bounce_factor = 0.8

var friction = 0.99
var min_bounce_velocity = 50

# Speed control
var speed_multiplier = 1.8

# State
var is_being_held = false
## Online (net.gd): she was picked up on this machine, so this machine tells the
## others when she's thrown or dropped
var _held_local := false
var _released_local := false
var has_touched_surface = false

# Spin
var is_spinning = false
var spin_speed = 0.0
var max_spin_speed = 35.0
var spin_decay_ground = 0.95

# Idle
var idle_timer = 0.0
var is_in_idle_state = false
var idle_variant := ""

# Upright
var upright_speed = 12.0
var upright_threshold = 0.1

# --------------------------------------------------

func _ready():

	# RANDOM SPRITE
	if textures.size() > 0:
		# (online: the same look on every player's screen)
		$Sprite2D.texture = textures[Net.shared_rng("miku").randi_range(0, textures.size() - 1)]

	$Arrow.visible = false
	$Attackbox.monitorable = false
	$Attackbox.monitoring = false

# --------------------------------------------------
# GROUP CONTROL (ITEM ONLY WHEN THROWN)
# --------------------------------------------------

func set_item_group(active: bool) -> void:

	if active:
		if not is_in_group("item"):
			add_to_group("item")
	else:
		if is_in_group("item"):
			remove_from_group("item")

# --------------------------------------------------

## Seconds of invincibility left after she appears (nothing can knock her off)
const SPAWN_SAFE_TIME := 2.0
var spawn_safe := SPAWN_SAFE_TIME

func _physics_process(delta):
	if knocked_off:
		_fall_off_screen(delta)
		return
	if spawn_safe > 0.0:
		spawn_safe -= delta
		# Blink while she's invincible
		# Blink while invincible, in boss fights only
		if get_tree().get_first_node_in_group("boss_arena") != null:
			$Sprite2D.visible = spawn_safe <= 0.0 or int(spawn_safe * 12.0) % 2 == 0
	# Feet on the ground, like the playable characters (grounded_sprite.gd)
	GROUNDED.update(self, $Sprite2D, $CollisionShape2D, is_being_held)

	if is_being_held:
		$AnimationPlayer.play("ride")
		$Arrow.visible = false

		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""
		return

	# --------------------------------------------------
	# SPINNING (ITEM MODE ON)
	# --------------------------------------------------
	if is_spinning:

		set_item_group(true)

		rotation += spin_speed * delta * 1

		$Attackbox.monitorable = true
		$Attackbox.monitoring = true

		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""

		if has_touched_surface and (is_on_floor() or is_on_wall()):
			spin_speed *= spin_decay_ground

			if abs(spin_speed) < 0.5:
				is_spinning = false
				spin_speed = 0
				set_item_group(false)

	# --------------------------------------------------
	# AUTO-UPRIGHT
	# --------------------------------------------------
	if is_on_floor() and not is_spinning and has_touched_surface:
		if velocity.length() < upright_threshold * 100:
			var target_rot = 0.0
			var diff = fposmod(target_rot - rotation + PI, TAU) - PI
			rotation += diff * upright_speed * delta

			if abs(diff) < 0.1:
				rotation = 0

		$Attackbox.monitorable = false
		$Attackbox.monitoring = false

	# --------------------------------------------------
	# GRAVITY
	# --------------------------------------------------
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not has_touched_surface:
			has_touched_surface = true

		velocity.x = move_toward(
			velocity.x,
			0,
			abs(velocity.x) * (1.0 - friction) * delta * 120.0
		)

		if velocity.y > min_bounce_velocity:
			velocity.y = -velocity.y * bounce_factor
		else:
			velocity.y = 0

	# --------------------------------------------------
	# WALL BOUNCE
	# --------------------------------------------------
	if is_on_wall():
		if not has_touched_surface:
			has_touched_surface = true

		velocity.x = -velocity.x * wall_bounce_factor

	# --------------------------------------------------
	# MOVE
	# --------------------------------------------------
	move_and_slide()

	# --------------------------------------------------
	# STOP CONDITION
	# --------------------------------------------------
	if is_on_floor() and has_touched_surface and abs(velocity.x) < 10 and abs(velocity.y) < 10:
		velocity = Vector2.ZERO
		is_spinning = false
		spin_speed = 0
		set_item_group(false)

	# --------------------------------------------------
	# IDLE SYSTEM
	# --------------------------------------------------
	var should_be_idle = (
		velocity == Vector2.ZERO and
		is_on_floor() and
		not is_spinning and
		has_touched_surface and
		abs(rotation) < 0.1
	)

	if should_be_idle:
		if not is_in_idle_state:
			$AnimationPlayer.play("wave")
			is_in_idle_state = true
			idle_timer = 0.0
		else:
			idle_timer += delta

			if idle_timer >= 4.0 and idle_variant == "":
				idle_variant = ["wave"].pick_random()
				$AnimationPlayer.play(idle_variant)
	else:
		idle_timer = 0.0
		is_in_idle_state = false
		idle_variant = ""

# --------------------------------------------------
# THROW (BECOMES ITEM HERE)
# --------------------------------------------------

func start_spinning(throw_direction: Vector2):
	if _released_local:
		_released_local = false
		Net.miku_event(self, "throw", {"vx": velocity.x, "vy": velocity.y, "dx": throw_direction.x, "dy": throw_direction.y})

	is_spinning = true
	has_touched_surface = false

	set_item_group(true) # 🔥 ITEM MODE ON

	var spin_x = throw_direction.x
	if abs(spin_x) < 0.05:
		spin_x = 0.25

	var spin_direction = sign(spin_x)

	spin_speed = max_spin_speed * spin_direction * speed_multiplier

	var angle_factor = abs(throw_direction.y)

	spin_speed *= (1.0 + angle_factor)

	velocity = throw_direction * 900 * speed_multiplier

# --------------------------------------------------
# PICKUP
# --------------------------------------------------

func disable_physics(by = null):

	is_being_held = true
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0
	rotation = 0
	has_touched_surface = false

	set_item_group(false)

	if by != null and "my_meter" in by:
		by.my_meter += 25   # whoever picked her up
	else:
		Test.meter += 25
	_held_local = by != null and by.get("is_player") == true
	if _held_local:
		Net.miku_event(self, "held")   # online: the others see her with this player


# --------------------------------------------------
# DROP
# --------------------------------------------------

func enable_physics():
	_released_local = _held_local
	if _held_local:
		_held_local = false
		Net.miku_event(self, "free")

	is_being_held = false
	has_touched_surface = false
	velocity = Vector2.ZERO
	is_spinning = false
	spin_speed = 0

	set_item_group(false)

	if Test.maxmeter > 100:
		Test.maxmeter = 100

# --------------------------------------------------
# UI
# --------------------------------------------------

func _on_area_2d_area_entered(area):
	if area.is_in_group("Player"):
		$Arrow.visible = true
	# Hit by an enemy or a boss attack: knocked off like a defeated enemy.
	# (Not while she's being carried, the carrier's hurt() handles that, or while
	# she's been thrown and is spinning, when she's the one doing the hitting.)
	if not knocked_off and not is_being_held and not is_spinning and _is_enemy_hit(area):
		if area.get_parent().has_node("Sprite2D/AnimationPlayer"):
			var eap: AnimationPlayer = area.get_parent().get_node("Sprite2D/AnimationPlayer")
			if eap.has_animation("attack"):
				eap.play("attack")
		knock_off(signf(global_position.x - area.global_position.x))


func _is_enemy_hit(area: Area2D) -> bool:
	if area.is_in_group("enemyattack"):
		return true
	# Regular enemies hurt by touch, unless they've already been beaten
	var e = area.get_parent()
	return area.is_in_group("Enemy") and "dying" in e and not e.dying and not e.get("hurt")


# --------------------------------------------------
# KNOCKED OFF (hit by an enemy, or her carrier was hit)
# --------------------------------------------------

const KNOCK_UP := -560.0
const KNOCK_SIDE := 260.0
const KNOCK_GRAVITY := 1300.0
var knocked_off := false

## Pops her up and away (dir_x is -1 or 1), spinning, and lets her fall off screen
## through the ground. She can't be picked up or saved after this.
func knock_off(dir_x: float) -> void:
	if knocked_off or spawn_safe > 0.0:
		return
	knocked_off = true
	set_meta("lost", true)
	if dir_x == 0.0:
		dir_x = [-1.0, 1.0].pick_random()
	Net.miku_event(self, "lost", {"d": dir_x})   # online: knocked off for everyone
	is_being_held = false
	is_spinning = false
	set_item_group(false)
	remove_from_group("Miku")
	collision_layer = 0
	collision_mask = 0
	$CollisionShape2D.set_deferred("disabled", true)
	$Area2D.set_deferred("monitoring", false)
	$Area2D.set_deferred("monitorable", false)
	$Attackbox.set_deferred("monitoring", false)
	$Attackbox.set_deferred("monitorable", false)
	$Arrow.visible = false
	$AnimationPlayer.play("ride")   # curled-up pose while she tumbles
	$Sprite2D.offset = Vector2.ZERO
	z_index = 60
	velocity = Vector2(dir_x * KNOCK_SIDE, KNOCK_UP)
	spin_speed = dir_x * 14.0
	GlobalSignals.emit_signal("camerashake")
	get_tree().create_timer(3.0, false).timeout.connect(queue_free)


func _fall_off_screen(delta: float) -> void:
	velocity.y += KNOCK_GRAVITY * delta
	global_position += velocity * delta
	rotation += spin_speed * delta

func _on_area_2d_area_exited(area):
	if area.is_in_group("Player"):
		$Arrow.visible = false
