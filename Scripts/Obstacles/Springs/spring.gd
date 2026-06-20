@tool
extends Area2D

@export var spring_velocity: Vector2 = Vector2(0, -1200)
@export var arc_points: int = 20
@export var gravityarc: float = 1200.0
@export var show_arc: bool = true

func _draw():
	if not show_arc:
		return

	var pos = Vector2.ZERO
	var vel = spring_velocity
	var dt = 1.0 / 60.0
	var points = [pos]

	for i in arc_points:
		vel.y += gravityarc * dt
		pos += vel * dt
		points.append(pos)

	draw_polyline(points, Color.YELLOW, 2.0)

func _ready():
	queue_redraw()
	$Sprite2D/AnimationPlayer.play("idle")


func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()
		
			
	
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		$AudioStreamPlayer2D.play()
		$Sprite2D/AnimationPlayer.play("play")

		var player_body = area.get_parent()
		player_body.apply_spring_boost(spring_velocity.rotated(rotation))



func _on_property_list_changed() -> void:
		queue_redraw()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "play":
		$Sprite2D/AnimationPlayer.play("idle")
