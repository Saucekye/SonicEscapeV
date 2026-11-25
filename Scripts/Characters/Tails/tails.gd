extends Player

@onready var fly_component: Node = $Fly
@onready var swipe_attack_component: Node = $SwipeAttack
@onready var stomp_component: Node = $Stomp
@onready var trick_component: Node = $Trick

# THE TORNADO: in the air, up + airspin and Tails jumps into his plane
const TORNADO := preload("res://Scenes/Characters/Tails/tornado.tscn")
const TORNADO_METER := 50          # meter you need to get in
const TORNADO_DRAIN := 25.0        # meter a second while climbing straight up
const TORNADO_FLASH := 0.35        # the white flash, seconds
const TORNADO_HIT := 25.0          # a hit in the plane costs this much meter instead of rings
const TORNADO_SAFE := 1.0          # seconds after a hit before the next one counts
var _tornado_hit_at := -10.0
var tornado: CharacterBody2D
var _boarded_at := 0.0


func handle_air_actions(is_grounded) -> void:
	if is_player and tornado == null and inp_pressed("ui_up") and inp_just_pressed("airspin") and my_meter >= Test.meter_cost(TORNADO_METER):
		_board_tornado()
		return
	fly_component.action()
	swipe_attack_component.action()
	stomp_component.action()
	trick_component.action()

func handle_ground_action() -> void:
	# Only triggers when not already swiping
	swipe_attack_component.action()
	
func handle_wall_mechanics() -> void:
	pass


func _physics_process(delta):
	if tornado:
		_ride_tornado(delta)
		return
	super._physics_process(delta)


# Hit while flying
func hurt():
	if tornado == null:
		await super.hurt()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _tornado_hit_at < TORNADO_SAFE:
		return
	_tornado_hit_at = now
	my_meter = maxf(my_meter - TORNADO_HIT, 0.0)
	var spr: Node2D = tornado.get_node("Sprite2D")
	var t := tornado.create_tween()
	for i in 4:
		t.tween_property(spr, "modulate", Color(1, 0.3, 0.3), 0.06)
		t.tween_property(spr, "modulate", Color.WHITE, 0.06)
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(0.25, 5.0)


func _board_tornado() -> void:
	_white_flash()
	tornado = TORNADO.instantiate()
	get_tree().current_scene.add_child(tornado)
	tornado.global_position = global_position
	tornado.collision_layer = 0   # nothing to bump into it but the level
	tornado.collision_mask = collision_mask
	var dir := -1.0 if $Sprite2D.flip_h else 1.0
	tornado.velocity = Vector2(dir * tornado.MAX_SPEED, 0)
	tornado.rotation = 0.0 if dir > 0 else PI
	_boarded_at = Time.get_ticks_msec() / 1000.0
	visible = false
	motion = Vector2.ZERO


func _ride_tornado(delta: float) -> void:
	if not is_instance_valid(tornado):
		tornado = null
		_leave_tornado()
		return
	global_position = tornado.global_position
	# Climbing burns meter
	if tornado.velocity.y < 0.0:
		my_meter = maxf(my_meter - TORNADO_DRAIN * delta * (-tornado.velocity.y / tornado.MAX_SPEED), 0.0)
	var out := Time.get_ticks_msec() / 1000.0 - _boarded_at > 0.3 and inp_pressed("ui_up") and inp_just_pressed("airspin")
	if out or my_meter <= 0.0 or is_player_dead:
		_leave_tornado()


func _leave_tornado() -> void:
	_white_flash()
	var v := Vector2.ZERO
	if is_instance_valid(tornado):
		v = tornado.velocity
		global_position = tornado.global_position
		tornado.queue_free()
	tornado = null
	visible = true
	motion = v * 0.8
	$Sprite2D.flip_h = v.x < 0.0
	falling = true


# A white flash over the whole screen
func _white_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)
	var t := layer.create_tween()
	t.tween_property(rect, "color:a", 0.0, TORNADO_FLASH)
	t.tween_callback(layer.queue_free)
