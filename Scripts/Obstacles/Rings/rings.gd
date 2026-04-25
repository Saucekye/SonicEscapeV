extends CharacterBody2D

var loss = false
var timer_started = false
const GRAVITY = 900.0

func _physics_process(delta):
	if loss:
		if not timer_started:
			timer_started = true
			
			# Disable collision with other rings only
			set_collision_layer_value(9, false)

			start_despawn_sequence()

		velocity.y += GRAVITY * delta
		move_and_slide()

func _ready() -> void:
	$Node2D/Sprite2D/AnimationPlayer.play("play")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "collect":
		$BlinkTimer.stop()
		$Node2D/Sprite2D.visible = true
		queue_free()

func _on_node_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		var player_body = area.get_parent()
		if player_body.ouch == false:
			$Node2D.set_deferred("monitoring", false)
			$Node2D.set_deferred("monitorable", false)
			print("WHAT NODE 2D")
			print($Node2D)
			Test.rings += 1
			Test.meter += 5
			$BlinkTimer.stop()
			$Node2D/Sprite2D.visible = true
			$Node2D/Sprite2D/AnimationPlayer.play("collect")

func _on_timer_timeout() -> void:
	queue_free()

func _on_blink_timer_timeout() -> void:
	$Node2D/Sprite2D.visible = not $Node2D/Sprite2D.visible

func start_despawn_sequence() -> void:
	await get_tree().create_timer(1.0).timeout
	$Timer.start()
	$BlinkTimer.start()
