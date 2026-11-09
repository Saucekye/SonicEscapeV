extends CharacterBody2D

var loss = false
var _collected := false   # (online: another player may have collected it)
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
		if player_body.ouch == false and not _collected:
			_collected = true
			$Node2D.set_deferred("monitoring", false)
			$Node2D.set_deferred("monitorable", false)
			if "my_rings" in player_body:   # co-op: each player has their own rings
				player_body.my_rings += 1
				player_body.my_meter += 5
			else:
				Test.rings += 1
				Test.meter += 5
			$BlinkTimer.stop()
			$Node2D/Sprite2D.visible = true
			$Node2D/Sprite2D/AnimationPlayer.play("collect")
			if not loss:
				Net.obj_gone(self, "ring")   # online: it's gone for everyone

## Online: another player collected this ring (net.gd). It goes, without counting for us.
func net_remove(_kind: String) -> void:
	if _collected:
		return
	_collected = true
	$Node2D.set_deferred("monitoring", false)
	$Node2D.set_deferred("monitorable", false)
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
