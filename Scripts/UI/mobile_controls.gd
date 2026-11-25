extends Control
# Touch controls

const SIZE := 0.72              # how big the stick and buttons are
const STICK_RADIUS := 105.0 * SIZE   # how far the knob travels
const STICK_DEAD := 0.32        # share of the radius before left / right registers
const STICK_DEAD_VERTICAL := 0.55   # up / down need a firmer push
const LEFT_ZONE := 0.45         # share of the screen width that belongs to the stick
const TOP_SAFE := 0.22          # top share of the screen left alone
const DPAD_CENTER := Vector2(210, 200) * SIZE   # from the bottom-left corner
const DPAD_RADIUS := 125.0 * SIZE   # size of the cross
const DPAD_REACH := 1.5         # touches this far out
const DPAD_DIAGONAL := 28.0     # degrees either side of 45° that press both directions
const OPACITY_IDLE := 0.38       # see-through enough to make out your character behind them
# Rest areas and boss arenas have a fixed camera
const ARENA_ZOOM := 0.8         # times the arena camera's own zoom
const ARENA_DOWN := 0.08        # and moved down this share of the screen
const OPACITY_PRESSED := 0.9
const HAPTICS := true           # short vibration on button presses

# Buttons: action pressed, art, position from the bottom-right corner, radius
var BUTTONS := [
	{"name": "jump", "actions": ["ui_accept", "dash"], "tex": "res://misc/JumpButton.png", "tex_on": "res://misc/JumpButton2.png", "pos": Vector2(185, 150), "r": 92.0},
	{"name": "boost", "actions": ["airspin"], "tex": "res://misc/DashButton.png", "tex_on": "res://misc/DashButton2.png", "pos": Vector2(375, 118), "r": 66.0},
	{"name": "trick", "actions": ["trick"], "tex": "res://Sprites/UI/TouchScreen/trick.png", "tex_on": "", "pos": Vector2(345, 300), "r": 60.0},
	{"name": "airup", "actions": ["airup"], "tex": "res://misc/DashButtonUp.png", "tex_on": "res://misc/DashButtonUp2.png", "pos": Vector2(175, 345), "r": 60.0},
]
# Stick directions and the actions they press
const DIR_ACTIONS := {"left": ["ui_left"], "right": ["ui_right"], "up": ["ui_up"], "down": ["ui_down", "crouch"]}

var old_controls: Control          # the scene's original touch controls

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
	for b in BUTTONS:   # all to the same smaller size, closer into the corner
		b.pos = b.pos * SIZE
		b.r = b.r * SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for b in BUTTONS:
		for key in ["tex", "tex_on"]:
			var path: String = b[key]
			if path != "" and ResourceLoader.exists(path) and not _tex.has(path):
				_tex[path] = load(path)
	# The trick button's art lives on the old TouchScreenButton node
	if old_controls:
		var trick := old_controls.find_child("trick", true, false) as TouchScreenButton
		if trick and trick.texture_normal:
			BUTTONS[2].tex = "_trick"
			_tex["_trick"] = trick.texture_normal
			if trick.texture_pressed:
				BUTTONS[2].tex_on = "_trick_on"
				_tex["_trick_on"] = trick.texture_pressed
		# Switch the old controls off
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
	if (get_tree().paused or Pause.visible) and (not _held_actions.is_empty() or _stick_touch != -1):
		_release_all()
	if visible:
		_fit_arena_camera()
	queue_redraw()


# A rest area's or boss arena's camera
func _fit_arena_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.get_script() != null or cam.has_meta("touch_fitted"):
		return
	cam.set_meta("touch_fitted", true)
	var h := get_viewport().get_visible_rect().size.y
	var z0 := cam.zoom.y
	var bottom := cam.offset.y + h * 0.5 / z0          # the old bottom edge, from the camera
	cam.zoom *= ARENA_ZOOM
	var z1 := cam.zoom.y
	cam.offset.y = bottom - h * (0.5 - ARENA_DOWN) / z1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused or Pause.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)


# Touch handling
func _touch_down(index: int, pos: Vector2) -> void:
	var size := get_viewport_rect().size
	if _tapped_icon(pos):
		return
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
		# Let the stick follow a thumb that drifts far
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
	# Direction from the angle around the centre
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
		if d <= float(BUTTONS[i].r) * reach * 1.15 and d < best_d:
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


# Drawing
func _draw() -> void:
	var size := get_viewport_rect().size
	if Test.touch_style == 1:
		_draw_dpad()
	else:
		_draw_stick(size)
	_draw_buttons()


# The D-pad, drawn with the game's own arrow buttons
const DPAD_ART := {
	"left": ["res://misc/Left.png", "res://misc/Left2.png"],
	"right": ["res://misc/Right.png", "res://misc/Right2.png"],
	"up": ["res://Sprites/UI/TouchScreen/Up.png", "res://Sprites/UI/TouchScreen/Up2.png"],
	"down": ["res://misc/Down.png", "res://misc/Down2.png"],
}

func _draw_dpad() -> void:
	var c := _dpad_center()
	var active := _stick_touch != -1
	var dirs := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN}
	var arm := DPAD_RADIUS * 0.46      # each arrow button's half-size
	for dname in dirs:
		var v: Vector2 = dirs[dname]
		var held := _held_dirs.has(dname)
		var path: String = DPAD_ART[dname][1 if held else 0]
		if not _tex.has(path) and ResourceLoader.exists(path):
			_tex[path] = load(path)
		var t: Texture2D = _tex.get(path)
		if t == null:
			continue
		var a := OPACITY_PRESSED if held or active else OPACITY_IDLE
		var s := arm * 2.0 / float(maxi(t.get_width(), t.get_height())) * (0.92 if held else 1.0)
		var sz := Vector2(t.get_width(), t.get_height()) * s
		var at := c + v * DPAD_RADIUS * 0.8
		draw_texture_rect(t, Rect2(at - sz / 2.0, sz), false, Color(1, 1, 1, a))


func _draw_stick(size: Vector2) -> void:
	# Stick: shows where your thumb is, or a faint resting stick in the corner
	var origin := _stick_origin if _stick_touch != -1 else Vector2(200 * SIZE, size.y - 170 * SIZE)
	var a := OPACITY_PRESSED if _stick_touch != -1 else OPACITY_IDLE * 0.7
	draw_circle(origin, STICK_RADIUS, Color(0, 0, 0, 0.28 * a))
	draw_arc(origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.55 * a), 4.0)
	for i in 4:   # direction ticks
		var dir := Vector2.RIGHT.rotated(i * PI / 2.0)
		draw_line(origin + dir * (STICK_RADIUS - 18 * SIZE), origin + dir * (STICK_RADIUS - 6 * SIZE), Color(1, 1, 1, 0.5 * a), 4.0)
	var knob := origin + _stick_vec * STICK_RADIUS
	draw_circle(knob, 44.0 * SIZE, Color(1, 1, 1, 0.8 * a))
	draw_arc(knob, 44.0 * SIZE, 0, TAU, 32, Color(0.85, 0.08, 0.12, 0.9 * a), 5.0)


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


# Tap your character's picture
func _tapped_icon(pos: Vector2) -> bool:
	var icon := get_parent().get_node_or_null("Sprite2Dicon") as Sprite2D
	if icon == null or icon.texture == null or not icon.visible:
		return false
	var pc := get_tree().current_scene.find_child("PlayerController", true, false) if get_tree().current_scene else null
	if pc == null or pc.characters.size() <= 1:
		return false
	var half: Vector2 = icon.texture.get_size() * icon.global_scale.abs() * 0.5
	if not Rect2(icon.global_position - half, half * 2.0).grow(16.0).has_point(pos):
		return false
	var press := InputEventAction.new()
	press.action = "switch"
	press.pressed = true
	Input.parse_input_event(press)
	var lift := InputEventAction.new()
	lift.action = "switch"
	lift.pressed = false
	Input.parse_input_event.call_deferred(lift)
	# a little squash so you can tell it took
	var base := icon.scale
	var tw := icon.create_tween()
	tw.tween_property(icon, "scale", base * 0.85, 0.06)
	tw.tween_property(icon, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true
