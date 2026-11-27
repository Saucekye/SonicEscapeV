@tool
class_name SalvageChunk
extends Node3D
# One corridor cell of the Salvage maze

@export var open_north := true
@export var open_south := true
@export var open_east := false
@export var open_west := false
@export var stairs := false        ## climbs one floor toward +Z
@export_range(0.0, 10.0) var weight := 1.0


# Its open sides as maze directions, in its own frame
func openings() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if open_north: out.append(Vector2i(0, -1))
	if open_south: out.append(Vector2i(0, 1))
	if open_east: out.append(Vector2i(1, 0))
	if open_west: out.append(Vector2i(-1, 0))
	return out
