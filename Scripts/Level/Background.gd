extends Node2D

@export var parallax_1: PackedScene
@export var parallax_2: PackedScene
@export var parallax_4: PackedScene
@export var parallax_5: PackedScene
@export var parallax_6: PackedScene

static var parallax_index: int = 0

var parallax_scenes: Array[PackedScene] = []
var _shown_scene: PackedScene   # the background in use, for make_copy()


func _ready():
	if not (parallax_1 or parallax_2 or parallax_4 or parallax_5 or parallax_6):
		return   # no backgrounds set here (the Background autoload); the level's Background node shows them
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

	_shown_scene = scene
	var bg = scene.instantiate()
	add_child(bg)
	_add_atmosphere(bg, Test.current_background)


func _spawn_specific(scene: PackedScene, id: int):
	if scene == null:
		push_error("Specific parallax scene is null!")
		return

	Test.current_background = id
	Test.current_background_name = scene.resource_path.get_file().get_basename()

	_shown_scene = scene
	var bg = scene.instantiate()
	add_child(bg)
	_add_atmosphere(bg, Test.current_background)


## A fresh copy of this floor's background (on the characters' pixel grid), for
## co-op's second view (coop.gd), which can't see the main view's CanvasLayers
func make_copy() -> Node:
	if _shown_scene == null:
		return null
	var bg = _shown_scene.instantiate()
	preload("res://Scripts/Level/pixel_match.gd").apply(bg)
	return bg


func _get_background_id(scene: PackedScene) -> int:
	if scene == parallax_1: return 1
	if scene == parallax_2: return 2
	if scene == parallax_4: return 4
	if scene == parallax_5: return 5
	if scene == parallax_6: return 6
	return 0


func _add_atmosphere(bg: Node, id: int) -> void:
	# Per-stage haze, colour grade, glow and particles (atmosphere.gd)
	# Background art onto the characters' pixel grid (no mixels)
	preload("res://Scripts/Level/pixel_match.gd").apply(bg)
	var atmosphere = preload("res://Scripts/Level/atmosphere.gd").new()
	add_child(atmosphere)
	atmosphere.setup(bg, id)



## The backgrounds are drawn to fill the screen at the Close zoom; pulled back
## further (Wide) they shrank with the camera and left black gaps at the edges.
## On Wide they stay at their Close size instead (the stage still zooms out).
func _process(_delta: float) -> void:
	var wide := Test.zoom_level == 0
	for bg in get_children():
		if bg is ParallaxBackground and bg.scroll_ignore_camera_zoom != wide:
			bg.scroll_ignore_camera_zoom = wide
