extends Node2D

@export var parallax_1: PackedScene
@export var parallax_2: PackedScene
@export var parallax_4: PackedScene
@export var parallax_5: PackedScene
@export var parallax_6: PackedScene

static var parallax_index: int = 0

var parallax_scenes: Array[PackedScene] = []
var _styles := {}               # scene -> stage look


func _ready():
	if not (parallax_1 or parallax_2 or parallax_4 or parallax_5 or parallax_6):
		return   # no backgrounds set here
	parallax_scenes = [
		parallax_1,
		parallax_2,
		parallax_4,
		parallax_5
	]
	# game_content.tres decides, when it lists any
	var listed: Array[PackedScene] = []
	for entry in Content.data().level_backgrounds:
		if entry and entry.scene:
			listed.append(entry.scene)
			_styles[entry.scene] = entry.style
	if not listed.is_empty():
		parallax_scenes = listed

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
	if _styles.has(scene): return int(_styles[scene])
	if scene == parallax_1: return 1
	if scene == parallax_2: return 2
	if scene == parallax_4: return 4
	if scene == parallax_5: return 5
	if scene == parallax_6: return 6
	return 0


# The backgrounds are drawn to fill the screen at the Close zoom
func _process(_delta: float) -> void:
	var wide := Test.zoom_level == 0
	for bg in get_children():
		if bg is ParallaxBackground and bg.scroll_ignore_camera_zoom != wide:
			bg.scroll_ignore_camera_zoom = wide
