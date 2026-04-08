extends Node2D

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
