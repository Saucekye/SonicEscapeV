extends Node2D

@export var parallax_1: PackedScene
@export var parallax_2: PackedScene
@export var parallax_4: PackedScene
@export var parallax_5: PackedScene
@export var parallax_6: PackedScene

static var parallax_index: int = 0

var parallax_scenes: Array[PackedScene] = []


func _ready():
	parallax_scenes = [
		parallax_1,
		parallax_2,
		parallax_4,
		parallax_5
	]

	# Every 4th floor uses parallax_6
	if Test.level % 4 == 0:
		_spawn_specific(parallax_6, 6)
		return

	# Change background every 4 floors
	var current_set = (Test.level - 1) / 4
	parallax_index = current_set % parallax_scenes.size()

	_spawn_parallax()


func _spawn_parallax():
	var scene = parallax_scenes[parallax_index]

	if scene == null:
		push_error("No parallax scene available!")
		return

	var id = _get_background_id(scene)

	Test.current_background = id
	Test.current_background_name = scene.resource_path.get_file().get_basename()

	var bg = scene.instantiate()
	add_child(bg)


func _spawn_specific(scene: PackedScene, id: int):
	if scene == null:
		push_error("Specific parallax scene is null!")
		return

	Test.current_background = id
	Test.current_background_name = scene.resource_path.get_file().get_basename()

	var bg = scene.instantiate()
	add_child(bg)


func _get_background_id(scene: PackedScene) -> int:
	if scene == parallax_1: return 1
	if scene == parallax_2: return 2
	if scene == parallax_4: return 4
	if scene == parallax_5: return 5
	if scene == parallax_6: return 6
	return 0
