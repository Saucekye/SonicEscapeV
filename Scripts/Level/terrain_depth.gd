extends TileMapLayer
## Gives the terrain thickness. A darker copy of the terrain sits a
## little further back and is drawn in perspective from the camera (scaled toward
## the screen centre), so ledges show a back face that shifts as you move, like
## the 2.5D stages in Sonic Rush. Purely visual: no collision.
## Created by rush_skin.gd for each main terrain layer. Follows the Effects toggle.

const DEPTH := 0.055   # how far back the copy sits (0 = flat, 0.1 = very deep)

var source: TileMapLayer


static func make(src: TileMapLayer, material_in: Material, tint: Color) -> void:
	if src.get_parent() == null or src.has_meta("depth_layer"):
		return
	var back = load("res://Scripts/Level/terrain_depth.gd").new()
	back.name = src.name + "Depth"
	back.source = src
	back.tile_set = src.tile_set
	back.tile_map_data = src.tile_map_data
	back.collision_enabled = false
	back.navigation_enabled = false
	back.occlusion_enabled = false
	back.material = material_in
	back.self_modulate = tint
	back.z_index = src.z_index
	back.z_as_relative = src.z_as_relative
	back.add_to_group("fx_depth")
	back.visible = Test.effects_enabled
	src.set_meta("depth_layer", back)
	var parent := src.get_parent()
	parent.add_child(back)
	parent.move_child(back, src.get_index())   # drawn just behind the real terrain
	back._place()


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	# A plane further back looks smaller around the point you're looking at
	var shrink := Transform2D(0.0, Vector2.ONE * (1.0 - DEPTH), 0.0, c * DEPTH)
	global_transform = shrink * source.global_transform
