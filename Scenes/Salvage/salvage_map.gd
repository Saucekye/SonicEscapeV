extends Control
# Map overlay

var game: Node3D                 # salvage.gd
var player                       # salvage_player.gd
var visited := {}                # Vector2i -> true

# Set from the Salvage node's Map settings
var room_color := Color(0.78, 0.78, 0.74)
var you_color := Color(0.9, 0.1, 0.12)
var exit_color := Color(0.25, 0.85, 0.35)
var entrance_color := Color(0.35, 0.6, 1.0)
var back_color := Color(0, 0, 0, 0.72)


func setup(game_node: Node3D, who) -> void:
	game = game_node
	player = who
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


# Mark where the player is now
func track() -> void:
	var p: Vector3 = player.global_position
	if p.y > game.UP_Y - 4.0:
		return   # still up in the start area
	var c := Vector2i(roundi(p.x / game.cell_size), roundi(p.z / game.cell_size))
	if not game.in_maze(c):
		return
	if not visited.has(c):
		visited[c] = true
		if visible:
			queue_redraw()


func toggle() -> void:
	visible = not visible
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var area := size
	var ms: Vector2i = game.maze_size
	# Fit the whole maze into most of the screen, square cells
	var cell := floorf(minf(area.x * 0.86 / ms.x, area.y * 0.82 / ms.y))
	cell = maxf(cell, 4.0)
	var full := Vector2(ms.x, ms.y) * cell
	var origin := (area - full) * 0.5
	draw_rect(Rect2(origin - Vector2(cell, cell) * 0.6, full + Vector2(cell, cell) * 1.2), back_color)
	var room := cell * 0.56          # a corridor cell's width on the map
	var half := Vector2(room, room) * 0.5
	for c in visited:
		var mid: Vector2 = origin + (Vector2(c - game.maze_lo) + Vector2(0.5, 0.5)) * cell
		draw_rect(Rect2(mid - half, Vector2(room, room)), room_color)
		for n in game._neighbours(c):
			var to: Vector2 = origin + (Vector2(n - game.maze_lo) + Vector2(0.5, 0.5)) * cell
			# A corridor to a cell you've been in goes all the way
			if visited.has(n):
				draw_line(mid, to, room_color, room)
			else:
				draw_line(mid, mid.lerp(to, 0.45), room_color, room * 0.6)
	# The entrance
	var en: Vector2 = origin + (Vector2(Vector2i.ZERO - game.maze_lo) + Vector2(0.5, 0.5)) * cell
	draw_rect(Rect2(en - half * 0.6, half * 1.2), entrance_color)
	if visited.has(game.exit_cell):
		var em: Vector2 = origin + (Vector2(game.exit_cell - game.maze_lo) + Vector2(0.5, 0.5)) * cell
		draw_rect(Rect2(em - half * 0.6, half * 1.2), exit_color)
	# You: an arrow pointing the way you face
	var p: Vector3 = player.global_position
	if p.y < game.UP_Y - 4.0:
		var at := origin + (Vector2(p.x / game.cell_size, p.z / game.cell_size) - Vector2(game.maze_lo) + Vector2(0.5, 0.5)) * cell
		var f: Vector3 = -player.global_transform.basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var r := maxf(cell * 0.42, 6.0)
		var tri := PackedVector2Array([at + dir * r, at - dir * r * 0.6 + side * r * 0.65, at - dir * r * 0.6 - side * r * 0.65])
		draw_colored_polygon(tri, you_color)
