class_name FlowerPlatformSpawner
extends Node2D

@export var platform_scenes: Array[PackedScene] = []
@export var scroll_speed: float = 300.0
@export var ground_y: float = 700.0   # y the player stands on (this node's local y)
@export var margin: float = 600.0     # road is kept this far beyond each screen edge
# Added to every flower's width when placing it. Negative closes gaps (transparent padding in the
# sprite), positive adds space. Tune it until the flowers touch without overlapping.
@export var spacing_adjust: float = 0.0

var running := true
var _platforms: Array = []
var _printed := false


# By default the road stays where it is, so the player isn't left with nothing to stand on.
func stop(clear_platforms: bool = false) -> void:
	running = false
	if clear_platforms:
		_clear()


func _physics_process(delta: float) -> void:
	if platform_scenes.is_empty():
		return

	if running:
		var dx := scroll_speed * delta
		for p in _platforms:
			if is_instance_valid(p):
				p.global_position.x -= dx

	_cover_view()


# Width of the slot one flower takes up in the road. Everything (placing, measuring, culling)
# uses this, so the spacing stays consistent.
func _slot_width(p: FlowerPlatform) -> float:
	return maxf(p.get_width() + spacing_adjust, 1.0) # never 0 or less, or the spawn loops would never end


# Global x range currently visible on screen
func _view_range() -> Vector2:
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var w := vp.get_visible_rect().size.x
	return Vector2((inv * Vector2.ZERO).x, (inv * Vector2(w, 0.0)).x)


func _cover_view() -> void:
	var view := _view_range()
	var need_left := view.x - margin
	var need_right := view.y + margin

	if not _printed:
		_printed = true
		print("FlowerPlatformSpawner: visible x range %d to %d, spawner at (%d, %d)" % [view.x, view.y, global_position.x, global_position.y])

	# Drop flowers that are far outside the screen, on either side
	for i in range(_platforms.size() - 1, -1, -1):
		var p = _platforms[i]
		if not is_instance_valid(p):
			_platforms.remove_at(i)
			continue
		var half: float = _slot_width(p) * 0.5
		if p.global_position.x + half < view.x - margin * 2.0 or p.global_position.x - half > view.y + margin * 2.0:
			p.queue_free()
			_platforms.remove_at(i)

	if _platforms.is_empty():
		_rebuild(need_left, need_right)
		return

	# Current extent of the road
	var left := INF
	var right := -INF
	for p in _platforms:
		var half: float = _slot_width(p) * 0.5
		left = minf(left, p.global_position.x - half)
		right = maxf(right, p.global_position.x + half)

	# Road is nowhere near the screen (e.g. the camera just jumped): start over there
	if right < need_left or left > need_right:
		_rebuild(need_left, need_right)
		return

	while right < need_right:
		right = _spawn_from(right)
	while left > need_left:
		left = _spawn_to(left)


func _rebuild(from_x: float, to_x: float) -> void:
	_clear()
	var x := from_x
	while x < to_x:
		x = _spawn_from(x)


func _clear() -> void:
	for p in _platforms:
		if is_instance_valid(p):
			p.queue_free()
	_platforms.clear()


func _make() -> FlowerPlatform:
	var scene: PackedScene = platform_scenes.pick_random()
	var p := scene.instantiate() as FlowerPlatform
	add_child(p)
	_platforms.append(p)
	return p


func _road_y() -> float:
	return to_global(Vector2(0.0, ground_y)).y


# New flower with its left edge at left_x; returns its right edge
func _spawn_from(left_x: float) -> float:
	var p := _make()
	var w := _slot_width(p)
	p.global_position = Vector2(left_x + w * 0.5, _road_y())
	return left_x + w


# New flower with its right edge at right_x; returns its left edge
func _spawn_to(right_x: float) -> float:
	var p := _make()
	var w := _slot_width(p)
	p.global_position = Vector2(right_x - w * 0.5, _road_y())
	return right_x - w
