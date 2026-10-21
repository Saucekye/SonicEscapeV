extends CharacterBody2D

@onready var timer: Timer = $Timer
@onready var attackbox: Area2D = $Hitbox

@export var lifetime: float = 10.0

const PROJECTILE_SCALE: float = 3.0

var current_player: Node2D
var start_speed: float = 650.0
var decelerration: float = 500.0
var base_speed: float = 350.0
var speed: float = start_speed

var direction: Vector2 = Vector2.ZERO
@onready var sprite_mat = $Sprite2D.material as ShaderMaterial

func _ready() -> void:
	timer.start(lifetime)

	current_player = _get_current_player()

	if current_player != null:
		direction = (global_position - current_player.global_position).normalized()
	else:
		direction = Vector2.RIGHT

	velocity = direction * speed


func _physics_process(delta: float) -> void:
	# Gradually slow down.
	speed = max(base_speed, speed - decelerration * delta)

	# Move and detect wall collisions.
	velocity = direction * speed

	var collision = move_and_collide(velocity * delta)

	if collision:
		# Bounce away from the wall.
		direction = direction.bounce(collision.get_normal()).normalized()
		velocity = direction * speed


func _get_current_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("Player")

	for player in players:
		if is_instance_valid(player) and player.get("is_player") == true:
			return player

	return null


func _on_timer_timeout() -> void:
	attackbox.monitoring = false
	attackbox.monitorable = false

	var tween_fade = get_tree().create_tween()
	tween_fade.tween_property(self, "modulate:a", 0.0, 0.333)

	await tween_fade.finished
	queue_free()

				
func flash_sprite(duration: float = 0.1) -> void:
	sprite_mat.set_shader_parameter("flash_amount", 1.0)

	await get_tree().create_timer(duration).timeout

	sprite_mat.set_shader_parameter("flash_amount", 0.0)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("Playerattack") or area.is_in_group("Player") or area.is_in_group("item"):
		var enemies = get_tree().get_nodes_in_group("Enemy")
		for enemy in enemies:
			if enemy.has_method("take_damage"):
				enemy.take_damage(2)
				flash_sprite()
				break
