extends Node2D

var _rect := Rect2()

func _ready() -> void:
	# The wall run stays out of loops (player_base.gd _curve_leads_to_wall)
	add_to_group("loops")
	_measure.call_deferred()
	# Dress the loop with the stage's Sonic Rush Adventure fill (rush_skin.gd)
	var skin = preload("res://Scripts/Level/rush_skin.gd")
	for layer in find_children("*", "TileMapLayer", true, false):
		skin.apply.call_deferred(layer, Test.current_background, false)

func _on_bl_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	
	print("BL triggered - Entering back loop")
	print("  Before: Layer = ", body.collision_layer, " | Mask = ", body.collision_mask)
	
	# SAVE the current state first!
	#body.stored_layer = body.collision_layer
	#body.stored_mask = body.collision_mask
	
	# Switch to back loop (layer 4 = value 8)
	body.collision_layer = 8
	body.collision_mask = 1
	
	print("  After:  Layer = ", body.collision_layer, " | Mask = ", body.collision_mask)
	print("  Stored: Layer = ", body.stored_layer, " | Mask = ", body.stored_mask)
	

func _on_al_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	print("AL triggered - Exiting back loop")
	print("  Before: Layer = ", body.collision_layer, " | Mask = ", body.collision_mask)

	# RESTORE the saved state
	body.collision_layer = body.stored_layer
	body.collision_mask = body.stored_mask
	
	print("  After:  Layer = ", body.collision_layer, " | Mask = ", body.collision_mask)
	
func _on_loop_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	body.in_loop = true

func _on_loop_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	body.in_loop = false


func _measure() -> void:
	var first := true
	for l in find_children("*", "TileMapLayer", true, false):
		var u: Rect2i = l.get_used_rect()
		if u.size == Vector2i.ZERO:
			continue
		var a: Vector2 = l.to_global(l.map_to_local(u.position))
		var b: Vector2 = l.to_global(l.map_to_local(u.end))
		var r := Rect2(a, Vector2.ZERO).expand(b).abs()
		_rect = r if first else _rect.merge(r)
		first = false


## True if a point is inside this loop (with a little margin)
func contains_point(p: Vector2) -> bool:
	return _rect.size != Vector2.ZERO and _rect.grow(80.0).has_point(p)
