extends Node2D

@export var camera_path : NodePath
var _camera : Node = null

@export var parallax_scale : float = 1.0
@export var mirroring : Vector2 = Vector2.ZERO
@export var mirror_margin : int = 64

var original_position : Vector2 = Vector2.ZERO
var motion : Vector2 = Vector2.ZERO

func _ready():
	if not camera_path.is_empty():
		set_camera(get_node(camera_path))
	original_position = position

func _process(delta):
	if _camera != null:
		update_motion()
		wrap_children()
	else:
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			set_camera(cameras[0])

func update_motion():
	var to_camera = _camera.global_position - $camera_follower.global_position
	motion += to_camera
	position = original_position + (motion * (1.0 - parallax_scale))
	$camera_follower.global_position = _camera.global_position

func wrap_children():
	if mirroring.x == 0 and mirroring.y == 0:
		return
	
	var mirror_bounds = Rect2()
	mirror_bounds.size = mirroring
	mirror_bounds.position = _camera.global_position - mirror_bounds.size / 2
	
	for child in get_children():
		if mirroring.x != 0:
			if child.global_position.x < (mirror_bounds.position.x - mirror_margin):
				child.position.x += mirroring.x + (2 * mirror_margin)
			elif child.global_position.x > (mirror_bounds.position.x + mirror_bounds.size.x + mirror_margin):
				child.position.x -= mirroring.x + (2 * mirror_margin)
		if mirroring.y != 0:
			if child.global_position.y < (mirror_bounds.position.y - mirror_margin):
				child.position.y += mirroring.y + (2 * mirror_margin)
			elif child.global_position.y > (mirror_bounds.position.y + mirror_bounds.size.y + mirror_margin):
				child.position.y -= mirroring.y + (2 * mirror_margin)

func set_camera(new_cam : Node) -> void:
	_camera = new_cam
	motion += global_position - _camera.global_position

func get_camera() -> Node:
	return _camera
