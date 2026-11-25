extends Node2D
# The trick chain's points over your head

const SIZE := 38                    # how big the number is
const ABOVE := Vector2(30, -95)     # where it sits from your middle
const COUNT_TIME := 0.2             # how long it takes to count up to the new total
const ORANGE_AT := 500              # a total this big turns orange
const WHITE := Color.WHITE
const ORANGE := Color(1.0, 0.5, 0.08)
const OUTLINE := Color(0.06, 0.04, 0.1)
const LINGER := 0.6                 # how long it stays once you've landed
const FADE := 0.2                   # how long it takes to fade

var who: Node2D
var shown := 0.0
var total := 0
var _from := 0.0
var _count := 1.0                   # 0..1 while counting up
var _ending := -1.0                 # counting down to going
var _going := false
var _label: Label


static func for_player(p: Node2D) -> Node2D:
	var c = p.get_meta("trick_counter") if p.has_meta("trick_counter") else null
	if c != null and is_instance_valid(c) and not c._going:
		return c
	c = (load("res://Scripts/Effects/trick_counter.gd") as GDScript).new()
	c.who = p
	c.z_index = 50
	p.get_parent().add_child(c)
	c.global_position = p.global_position + ABOVE
	p.set_meta("trick_counter", c)
	return c


func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", SIZE)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(240, SIZE * 1.5)
	_label.position = -_label.size * 0.5
	add_child(_label)


func add(points: int) -> void:
	_from = shown
	total += points
	_count = 0.0
	_ending = -1.0


# The finisher: nothing extra
func finish() -> void:
	pass


func _process(delta: float) -> void:
	if not is_instance_valid(who):
		queue_free()
		return
	global_position = who.global_position + ABOVE
	if _going:
		return
	if _count < 1.0:
		_count = minf(_count + delta / COUNT_TIME, 1.0)
		shown = lerpf(_from, total, _count)
	_label.text = str(int(round(shown)))
	_label.add_theme_color_override("font_color", ORANGE if total >= ORANGE_AT else WHITE)
	var landed: bool = who.has_method("is_on_floor") and who.is_on_floor()
	if landed and _ending < 0.0 and _count >= 1.0:
		_ending = LINGER
	if _ending >= 0.0:
		_ending -= delta
		if _ending <= 0.0:
			_go()


func _go() -> void:
	_going = true
	if who and is_instance_valid(who) and who.get_meta("trick_counter", null) == self:
		who.remove_meta("trick_counter")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(queue_free)
