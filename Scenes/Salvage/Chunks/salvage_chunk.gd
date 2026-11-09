@tool
class_name SalvageChunk
extends Node3D
## One corridor chunk of the Salvage facility, like the 2D levels' chunks: a scene
## you build and edit in Godot, which salvage.gd fits into the maze.
##
## The rules for a chunk:
##   - It covers one 4 x 4 m corridor cell, centred on its origin. The floor's top
##     is at y = 0 and the ceiling's underside at y = 3.2 (Wall Height); a
##     staircase's top floor is 1.6 m up (Level Step) and its ceiling 1.6 m higher.
##   - Tick the sides that are open (north = -Z, south = +Z, east = +X, west = -X).
##     An open side should be open across its full width, so neighbouring chunks
##     and the metal doors line up. salvage.gd turns chunks to fit, so one corner
##     chunk serves for every corner.
##   - A staircase climbs toward +Z (south): open at north (bottom) and south (top).
##   - Name the ceiling node "Ceiling" (it's taken out over the hole you drop in by).
##   - Marker3Ds in the "lamp_spot" group are where ceiling lamps can hang (some
##     lamps are dead or flicker, and only some spots get one).
##   - Use the facility's materials (Materials/*.tres) so the lighting reaches them.
##   - Bodies in the "salvage_cover" group count as cover to hide behind or under.
## To add a variant, duplicate a chunk, change it, and add it to the Salvage
## node's Chunks list. Weight is how often it's picked among chunks that fit.

@export var open_north := true
@export var open_south := true
@export var open_east := false
@export var open_west := false
@export var stairs := false        ## climbs one floor toward +Z (open north and south)
@export_range(0.0, 10.0) var weight := 1.0


## Its open sides as maze directions, in its own frame (x = east, y = south)
func openings() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if open_north: out.append(Vector2i(0, -1))
	if open_south: out.append(Vector2i(0, 1))
	if open_east: out.append(Vector2i(1, 0))
	if open_west: out.append(Vector2i(-1, 0))
	return out
