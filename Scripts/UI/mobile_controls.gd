extends Control
## Touch controls, replacing the old on-screen d-pad and buttons.
##
## Left side, two styles (Pause > Settings > Touch Controls, saved per player):
##   Thumbstick: a floating thumbstick. Put your thumb down anywhere on the left part
## of the screen and drag; it works in 8 directions, so diagonals (down + forward
## for rolling) and sliding from left to right without lifting both work.
##   D-Pad: a fixed cross in the bottom-left corner. Press an arm for that direction,
##   or between two arms for a diagonal; slide your thumb around it freely.
## Right side: big buttons pinned to the bottom-right corner on any screen shape,
## using the game's own button art. You can slide your thumb from one button to
## another (for example from jump onto boost).
##
## Buttons press the game's input ACTIONS (not keyboard keys), so they keep working
## if a player rebinds keys. Everything is released when the game pauses or loses
## focus, so nothing gets stuck held. Shown whenever the old touch controls would be
## (Test.mobile / the Mobile toggle). Created by CanvasLayer.gd.

const STICK_RADIUS := 105.0     # how far the knob travels (canvas pixels)
const STICK_DEAD := 0.32        # share of the radius before left / right registers
const STICK_DEAD_VERTICAL := 0.55   # up / down need a firmer push, so running doesn't roll by accident
const LEFT_ZONE := 0.45         # share of the screen width that belongs to the stick
const TOP_SAFE := 0.22          # top share of the screen left alone (HUD, pause button)
const DPAD_CENTER := Vector2(210, 200)   # from the bottom-left corner
const DPAD_RADIUS := 125.0      # size of the cross
const DPAD_REACH := 1.5         # touches this far out (times the radius) still count
const DPAD_DIAGONAL := 28.0     # degrees either side of 45° that press both directions
const OPACITY_IDLE := 0.5
const OPACITY_PRESSED := 0.9
const HAPTICS := true           # short vibration on button presses (phones that support it)

## Buttons: action(s) pressed, art, position from the bottom-right corner, radius
var BUTTONS := [
	{"name": "jump", "actions": ["ui_accept", "dash"], "tex": "res://misc/JumpButton.png", "tex_on": "res://misc/JumpButton2.png", "pos": Vector2(185, 150), "r": 92.0},
	{"name": "boost", "actions": ["airspin"], "tex": "res://misc/DashButton.png", "tex_on": "res://misc/DashButton2.png", "pos": Vector2(375, 118), "r": 66.0},
	{"name": "trick", "actions": ["trick"], "tex": "res://Sprites/UI/TouchScreen/trick.png", "tex_on": "", "pos": Vector2(345, 300), "r": 60.0},
	{"name": "airup", "actions": ["airup"], "tex": "res://misc/DashButtonUp.png", "tex_on": "res://misc/DashButtonUp2.png", "pos": Vector2(175, 345), "r": 60.0},
]
## Stick directions and the actions they press (down also presses crouch, like the Down key did)
const DIR_ACTIONS := {"left": ["ui_left"], "right": ["ui_right"], "up": ["ui_up"], "down": ["ui_down", "crouch"]}

var old_controls: Control          # the scene's original touch controls (visibility follows it)

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO     # -1..1
var _held_dirs := {}               # "left" -> true
var _touch_button := {}            # touch index -> button index
var _held_actions := {}            # action -> count of things holding it
var _tex := {}
var _style := -1


func _ready() -> void:
	Test.touch_controls_v2 = true   # turns off the old joystick bridge in player_base.gd
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for b in BUTTONS:
		for key in ["tex", "tex_on"]:
			var path: String = b[key]
			if path != "" and ResourceLoader.exists(path) and not _tex.has(path):
				_tex[path] = load(path)
	# The trick button's art lives on the old TouchScreenButton node; borrow it
	if old_controls:
		var trick := old_controls.find_child("trick", true, false) as TouchScreenButton
		if trick and trick.texture_normal:
			BUTTONS[2].tex = "_trick"
			_tex["_trick"] = trick.texture_normal
			if trick.texture_pressed:
				BUTTONS[2].tex_on = "_trick_on"
				_tex["_trick_on"] = trick.texture_pressed
		# Switch the old controls off (the node itself stays: other scripts read its visibility)
		for child in old_controls.get_children():
			if child is CanvasItem:
				child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	var show: bool = old_controls.visible if old_controls else bool(Test.mobile)
	if show != visible:
		visible = show
		if not show:
			_release_all()
	if Test.touch_style != _style:
		_style = Test.touch_style
		_release_all()
	if get_tree().paused and (not _held_actions.is_empty() or _stick_touch != -1):
		_release_all()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)


# ── Touch handling ──────────────────────────────────────────────────────────
func _touch_down(index: int, pos: Vector2) -> void:
	var size := get_viewport_rect().size
	var b := _button_at(pos, 1.25)
	if b >= 0:
		_touch_button[index] = b
		_press_button(b)
		return
	if _stick_touch != -1:
		return
	if Test.touch_style == 1:
		if pos.distance_to(_dpad_center()) <= DPAD_RADIUS * DPAD_REACH:
			_stick_touch = index
			_update_dpad(pos)
	elif pos.x < size.x * LEFT_ZONE and pos.y > size.y * TOP_SAFE:
		_stick_touch = index
		_stick_origin = pos
		_update_stick(pos)


func _touch_move(index: int, pos: Vector2) -> void:
	if index == _stick_touch and Test.touch_style == 1:
		_update_dpad(pos)
	elif index == _stick_touch:
		# Let the stick follow a thumb that drifts far, so it never runs out of travel
		var d := pos - _stick_origin
		if d.length() > STICK_RADIUS * 1.6:
			_stick_origin = pos - d.normalized() * STICK_RADIUS * 1.6
		_update_stick(pos)
	elif _touch_button.has(index):
		var b := _button_at(pos, 1.1)
		if b >= 0 and b != _touch_button[index]:
			_release_button(_touch_button[index])
			_touch_button[index] = b
			_press_button(b)


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_stick_vec = Vector2.ZERO
		_set_dirs({})
	elif _touch_button.has(index):
		_release_button(_touch_button[index])
		_touch_button.erase(index)


func _update_stick(pos: Vector2) -> void:
	var d := (pos - _stick_origin) / STICK_RADIUS
	if d.length() > 1.0:
		d = d.normalized()
	_stick_vec = d
	var dirs := {}
	if d.x > STICK_DEAD:
		dirs["right"] = true
	elif d.x < -STICK_DEAD:
		dirs["left"] = true
	if d.y > STICK_DEAD_VERTICAL:
		dirs["down"] = true
	elif d.y < -STICK_DEAD_VERTICAL:
		dirs["up"] = true
	_set_dirs(dirs)


func _dpad_center() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(DPAD_CENTER.x, size.y - DPAD_CENTER.y)


func _update_dpad(pos: Vector2) -> void:
	# Direction from the angle around the centre: 8 ways, with wide diagonals.
	# A small dead spot in the middle lets you rest your thumb on the pad.
	var d := pos - _dpad_center()
	var dirs := {}
	if d.length() > DPAD_RADIUS * 0.18:
		var ang := rad_to_deg(atan2(-d.y, d.x))   # 0 = right, 90 = up
		ang = fposmod(ang, 360.0)
		var octant := fposmod(ang, 90.0)
		var diagonal := absf(octant - 45.0) < DPAD_DIAGONAL
		if ang < 45.0 + (DPAD_DIAGONAL if diagonal else 0.0) or ang > 315.0 - (DPAD_DIAGONAL if diagonal else 0.0):
			dirs["right"] = true
		if ang > 135.0 - (DPAD_DIAGONAL if diagonal else 0.0) and ang < 225.0 + (DPAD_DIAGONAL if diagonal else 0.0):
			dirs["left"] = true
		if ang > 45.0 - (DPAD_DIAGONAL if diagonal else 0.0) and ang < 135.0 + (DPAD_DIAGONAL if diagonal else 0.0):
			dirs["up"] = true
		if ang > 225.0 - (DPAD_DIAGONAL if diagonal else 0.0) and ang < 315.0 + (DPAD_DIAGONAL if diagonal else 0.0):
			dirs["down"] = true
	_stick_vec = d.limit_length(DPAD_RADIUS) / DPAD_RADIUS
	_set_dirs(dirs)


func _set_dirs(dirs: Dictionary) -> void:
	for dname in DIR_ACTIONS:
		var want := dirs.has(dname)
		if want and not _held_dirs.has(dname):
			_held_dirs[dname] = true
			for a in DIR_ACTIONS[dname]:
				_hold(a, true)
		elif not want and _held_dirs.has(dname):
			_held_dirs.erase(dname)
			for a in DIR_ACTIONS[dname]:
				_hold(a, false)


func _button_center(b: int) -> Vector2:
	var size := get_viewport_rect().size
	return size - (BUTTONS[b].pos as Vector2)


func _button_at(pos: Vector2, reach: float) -> int:
	var best := -1
	var best_d := INF
	for i in BUTTONS.size():
		var d := pos.distance_to(_button_center(i))
		if d <= float(BUTTONS[i].r) * reach and d < best_d:
			best = i
			best_d = d
	return best


func _press_button(b: int) -> void:
	for a in BUTTONS[b].actions:
		_hold(a, true)
	if HAPTICS:
		Input.vibrate_handheld(12)


func _release_button(b: int) -> void:
	for a in BUTTONS[b].actions:
		_hold(a, false)


func _is_button_held(b: int) -> bool:
	return _touch_button.values().has(b)


func _hold(action: String, on: bool) -> void:
	# Counted, so two touches holding the same action release it only when both lift
	var n: int = _held_actions.get(action, 0) + (1 if on else -1)
	if n <= 0:
		_held_actions.erase(action)
		_send(action, false)
	else:
		if not _held_actions.has(action):
			_send(action, true)
		_held_actions[action] = n


func _send(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _release_all() -> void:
	for a in _held_actions.keys():
		_send(a, false)
	_held_actions.clear()
	_held_dirs.clear()
	_touch_button.clear()
	_stick_touch = -1
	_stick_vec = Vector2.ZERO


# ── Drawing ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	var size := get_viewport_rect().size
	if Test.touch_style == 1:
		_draw_dpad()
	else:
		_draw_stick(size)
	_draw_buttons()


func _draw_dpad() -> void:
	var c := _dpad_center()
	var active := _stick_touch != -1
	var a := OPACITY_PRESSED if active else OPACITY_IDLE
	var arm := DPAD_RADIUS * 0.42      # half the width of each arm
	var dirs := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN}
	# Outline, then fill, so the cross reads on any background
	for dname in dirs:
		var v: Vector2 = dirs[dname]
		var r := Rect2(c - Vector2(arm, arm), Vector2(arm, arm) * 2.0)
		r = r.merge(Rect2(c + v * DPAD_RADIUS - Vector2(arm, arm), Vector2(arm, arm) * 2.0))
		draw_rect(r.grow(5), Color(0, 0, 0, 0.45 * a))
	for dname in dirs:
		var v: Vector2 = dirs[dname]
		var r := Rect2(c - Vector2(arm, arm), Vector2(arm, arm) * 2.0)
		r = r.merge(Rect2(c + v * DPAD_RADIUS - Vector2(arm, arm), Vector2(arm, arm) * 2.0))
		draw_rect(r, Color(1, 1, 1, 0.22 * a))
	for dname in dirs:
		var v: Vector2 = dirs[dname]
		var held := _held_dirs.has(dname)
		var tip := c + v * (DPAD_RADIUS - arm * 0.9)
		var side := Vector2(-v.y, v.x)
		var col := Color(0.86, 0.08, 0.12, a) if held else Color(1, 1, 1, 0.75 * a)
		if held:
			var r := Rect2(c + v * (DPAD_RADIUS * 0.5) - Vector2(arm, arm), Vector2(arm, arm) * 2.0)
			r = r.merge(Rect2(c + v * DPAD_RADIUS - Vector2(arm, arm), Vector2(arm, arm) * 2.0))
			draw_rect(r, Color(1, 1, 1, 0.35 * a))
		draw_colored_polygon(PackedVector2Array([tip + v * arm * 0.55, tip - v * arm * 0.15 + side * arm * 0.55, tip - v * arm * 0.15 - side * arm * 0.55]), col)


func _draw_stick(size: Vector2) -> void:
	# Stick: shows where your thumb is, or a faint resting stick in the corner
	var origin := _stick_origin if _stick_touch != -1 else Vector2(200, size.y - 170)
	var a := OPACITY_PRESSED if _stick_touch != -1 else OPACITY_IDLE * 0.7
	draw_circle(origin, STICK_RADIUS, Color(0, 0, 0, 0.28 * a))
	draw_arc(origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.55 * a), 4.0)
	for i in 4:   # direction ticks
		var dir := Vector2.RIGHT.rotated(i * PI / 2.0)
		draw_line(origin + dir * (STICK_RADIUS - 18), origin + dir * (STICK_RADIUS - 6), Color(1, 1, 1, 0.5 * a), 4.0)
	var knob := origin + _stick_vec * STICK_RADIUS
	draw_circle(knob, 44.0, Color(1, 1, 1, 0.8 * a))
	draw_arc(knob, 44.0, 0, TAU, 32, Color(0.85, 0.08, 0.12, 0.9 * a), 5.0)


func _draw_buttons() -> void:
	for i in BUTTONS.size():
		var b: Dictionary = BUTTONS[i]
		var held := _is_button_held(i)
		var c := _button_center(i)
		var key: String = b.tex_on if (held and b.tex_on != "" and _tex.has(b.tex_on)) else b.tex
		var t: Texture2D = _tex.get(key)
		var op := OPACITY_PRESSED if held else OPACITY_IDLE
		if t:
			var s: float = float(b.r) * 2.0 / float(max(t.get_width(), t.get_height())) * (0.92 if held else 1.0)
			var sz := Vector2(t.get_width(), t.get_height()) * s
			draw_texture_rect(t, Rect2(c - sz / 2.0, sz), false, Color(1, 1, 1, op))
		else:
			draw_circle(c, b.r, Color(0, 0, 0, 0.35 * op))
			draw_arc(c, b.r, 0, TAU, 40, Color(1, 1, 1, op), 4.0)
