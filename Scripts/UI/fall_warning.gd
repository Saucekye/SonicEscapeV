extends Control
# Falling from high up onto an enemy you can't see yet

## How close to where you'll come down an enemy has to be
@export var landing_reach := 140.0
## Furthest below you an enemy is still warned about
@export var look_down := 4000.0
## Falling at least this fast
@export var min_fall_speed := 150.0
@export var mark_color := Color(1.0, 0.2, 0.15)
@export var mark_size := 16.0
## Most see-through and least see-through it gets as it softly pulses
@export var alpha_low := 0.4
@export var alpha_high := 0.8
@export var fade_time := 0.15
const EDGE := 14.0   # gap from the bottom of the screen

var controller: Node
var _marks := {}   # enemy -> {"x"
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	var want := {}
	var p := controller.get("current_character") as CharacterBody2D if controller else null
	if p != null and is_instance_valid(p) and not p.is_on_floor() and not p.get("is_player_dead") and not Pause.visible:
		want = _ahead(p)
	for e in want:
		if not _marks.has(e):
			_marks[e] = {"x": want[e], "a": 0.0}
		_marks[e].x = want[e]
	for e in _marks.keys():
		var m: Dictionary = _marks[e]
		m.a = move_toward(m.a, 1.0 if want.has(e) else 0.0, delta / fade_time)
		if m.a <= 0.0:
			_marks.erase(e)
	queue_redraw()


# Enemies below the screen near where you'll land, and their x on screen
func _ahead(p: CharacterBody2D) -> Dictionary:
	var out := {}
	var v: Vector2 = p.get("motion") if p.get("motion") is Vector2 else p.velocity
	if v.y < min_fall_speed:
		return out
	var g: float = p.get("fall_gravity") if p.get("fall_gravity") else 2080.0
	var xf := get_viewport().get_canvas_transform()
	var bottom := get_viewport_rect().size.y
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not (e is CharacterBody2D) or not e.is_visible_in_tree() or e.is_queued_for_deletion():
			continue
		var dy: float = e.global_position.y - p.global_position.y
		if dy <= 0.0 or dy > look_down:
			continue
		var on_screen: Vector2 = xf * e.global_position
		if on_screen.y < bottom:
			continue   # you can see it already
		# Where you'll be when you're down at its height, keeping your speed
		var t := (-v.y + sqrt(v.y * v.y + 2.0 * g * dy)) / g
		var land_x := p.global_position.x + v.x * t
		if absf(e.global_position.x - land_x) <= landing_reach:
			out[e] = on_screen.x
	return out


func _draw() -> void:
	var y := get_viewport_rect().size.y - EDGE
	var pulse := lerpf(alpha_low, alpha_high, 0.5 + 0.5 * sin(_t * 6.0))
	for e in _marks:
		var m: Dictionary = _marks[e]
		var x: float = clampf(m.x, mark_size, get_viewport_rect().size.x - mark_size)
		var c := Color(mark_color, pulse * m.a)
		var s := mark_size
		# A small chevron pointing down
		draw_polyline(PackedVector2Array([Vector2(x - s, y - s * 0.7), Vector2(x, y), Vector2(x + s, y - s * 0.7)]), c, 3.0, true)
