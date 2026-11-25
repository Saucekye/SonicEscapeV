extends Control
# Touch controls for Salvage

var STICK_RADIUS := 105.0        # how far the knob travels
const STICK_DEAD := 0.18
const LEFT_ZONE := 0.42          # share of the screen width that belongs to the stick
const TOP_SAFE := 0.2            # top share of the left side left alone
const TAP_TIME := 0.25           # a touch shorter than this, that barely moved, is a tap
const TAP_MOVE := 18.0
const OPACITY_IDLE := 0.5
const OPACITY_PRESSED := 0.9

var BUTTONS := [
	{"action": "sv_jump", "tex": "res://misc/JumpButton.png", "tex_on": "res://misc/JumpButton2.png", "pos": Vector2(170, 150), "r": 88.0, "corner": "bottom"},
	{"action": "sv_sprint", "tex": "res://misc/DashButton.png", "tex_on": "res://misc/DashButton2.png", "pos": Vector2(350, 118), "r": 64.0, "corner": "bottom"},
	{"action": "sv_crouch", "tex": "res://misc/Down.png", "tex_on": "res://misc/Down2.png", "pos": Vector2(160, 330), "r": 60.0, "corner": "bottom"},
	{"action": "sv_map", "tex": "res://misc/mapbutton.png", "tex_on": "res://misc/mapbuttonpress.png", "pos": Vector2(90, 150), "r": 50.0, "corner": "top"},
]

var game: Node3D                 # salvage.gd
var player                       # salvage_player.gd
var look_speed := 1.6            # look drag speed, times the mouse's
var button_scale := 1.0          # size of the buttons

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_touch := -1
var _look_start := 0.0
var _look_moved := 0.0
var _touch_button := {}          # touch index -> button index
var _tex := {}
var _pause_button: Button


func setup(game_node: Node3D, who) -> void:
	game = game_node
	player = who
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in BUTTONS:
		b.pos *= button_scale
		b.r *= button_scale
		for key in ["tex", "tex_on"]:
			var path: String = b[key]
			if ResourceLoader.exists(path) and not _tex.has(path):
				_tex[path] = load(path)
	# Pause: the same plain button the levels show on touch screens
	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.position = Vector2(-150, 250)
	_pause_button.size = Vector2(120, 48)
	_pause_button.pressed.connect(_press_pause)
	add_child(_pause_button)


func _press_pause() -> void:
	_release_all()
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)
	get_tree().create_timer(0.1, true).timeout.connect(func():
		var up := InputEventAction.new()
		up.action = "ui_cancel"
		up.pressed = false
		Input.parse_input_event(up))


func _process(_delta: float) -> void:
	if (get_tree().paused or game.menu_open()) and (_stick_touch != -1 or _look_touch != -1 or not _touch_button.is_empty()):
		_release_all()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused or game.menu_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if _pause_button.get_global_rect().has_point(pos):
		return
	var size := get_viewport_rect().size
	var b := _button_at(pos, 1.25)
	if b >= 0:
		_touch_button[index] = b
		_send(BUTTONS[b].action, true)
		Input.vibrate_handheld(12)
	elif pos.x < size.x * LEFT_ZONE:
		if _stick_touch == -1 and pos.y > size.y * TOP_SAFE:
			_stick_touch = index
			_stick_origin = pos
			_update_stick(pos)
	elif _look_touch == -1:
		_look_touch = index
		_look_start = Time.get_ticks_msec() / 1000.0
		_look_moved = 0.0


func _touch_move(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _stick_touch:
		var d := pos - _stick_origin
		if d.length() > STICK_RADIUS * 1.6:
			_stick_origin = pos - d.normalized() * STICK_RADIUS * 1.6   # follow a drifting thumb
		_update_stick(pos)
	elif index == _look_touch:
		_look_moved += relative.length()
		if not player.escaped:
			player.look_mouse(relative * look_speed)
	elif _touch_button.has(index):
		var b := _button_at(pos, 1.1)
		if b >= 0 and b != _touch_button[index]:
			_send(BUTTONS[_touch_button[index]].action, false)
			_touch_button[index] = b
			_send(BUTTONS[b].action, true)


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_update_stick(_stick_origin)
	elif index == _look_touch:
		_look_touch = -1
		if Time.get_ticks_msec() / 1000.0 - _look_start < TAP_TIME and _look_moved < TAP_MOVE:
			# A tap: interact with what's in the middle of your view
			_send("sv_interact", true)
			get_tree().create_timer(0.1).timeout.connect(_send.bind("sv_interact", false))
	elif _touch_button.has(index):
		_send(BUTTONS[_touch_button[index]].action, false)
		_touch_button.erase(index)


# Walking: the stick presses sv_forward / sv_back / sv_left / sv_right as hard as it's pushed
func _update_stick(pos: Vector2) -> void:
	var d := (pos - _stick_origin) / STICK_RADIUS
	if d.length() > 1.0:
		d = d.normalized()
	_stick_vec = d if d.length() > STICK_DEAD else Vector2.ZERO
	_strength("sv_right", maxf(_stick_vec.x, 0.0))
	_strength("sv_left", maxf(-_stick_vec.x, 0.0))
	_strength("sv_back", maxf(_stick_vec.y, 0.0))
	_strength("sv_forward", maxf(-_stick_vec.y, 0.0))


func _strength(action: String, s: float) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = s > 0.0
	e.strength = s
	Input.parse_input_event(e)


func _send(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _release_all() -> void:
	for i in _touch_button:
		_send(BUTTONS[_touch_button[i]].action, false)
	_touch_button.clear()
	if _stick_touch != -1:
		_stick_touch = -1
		_update_stick(_stick_origin)
	_look_touch = -1


func _button_center(b: int) -> Vector2:
	var size := get_viewport_rect().size
	var p: Vector2 = BUTTONS[b].pos
	if BUTTONS[b].corner == "top":
		return Vector2(size.x - p.x, p.y)
	return size - p


func _button_at(pos: Vector2, reach: float) -> int:
	var best := -1
	var best_d := INF
	for i in BUTTONS.size():
		var d := pos.distance_to(_button_center(i))
		if d <= float(BUTTONS[i].r) * reach and d < best_d:
			best = i
			best_d = d
	return best


func _draw() -> void:
	# The stick, while a thumb is on it
	if _stick_touch != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.28 * OPACITY_PRESSED))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.55 * OPACITY_PRESSED), 4.0)
		var knob := _stick_origin + (_stick_vec if _stick_vec != Vector2.ZERO else Vector2.ZERO) * STICK_RADIUS
		draw_circle(knob, 44.0, Color(1, 1, 1, 0.8 * OPACITY_PRESSED))
		draw_arc(knob, 44.0, 0, TAU, 32, Color(0.85, 0.08, 0.12, 0.9 * OPACITY_PRESSED), 5.0)
	for i in BUTTONS.size():
		var b: Dictionary = BUTTONS[i]
		var held: bool = _touch_button.values().has(i)
		var key: String = b.tex_on if held and _tex.has(b.tex_on) else b.tex
		var t: Texture2D = _tex.get(key)
		var op := OPACITY_PRESSED if held else OPACITY_IDLE
		var c := _button_center(i)
		if t:
			var s: float = float(b.r) * 2.0 / float(max(t.get_width(), t.get_height())) * (0.92 if held else 1.0)
			var sz := Vector2(t.get_width(), t.get_height()) * s
			draw_texture_rect(t, Rect2(c - sz / 2.0, sz), false, Color(1, 1, 1, op))
