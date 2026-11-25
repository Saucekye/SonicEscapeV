extends Control
# Move prompts, like Sonic Adventure 2's and Dragon Ball Xenoverse's

var controller: Node            # player_controller.gd
var _rows: Array = []           # [name, [actions], hold?] shown now
var _key := ""
var _device := "keys"           # "keys", "pad" or "touch"
var _box: VBoxContainer
var _over: HBoxContainer        # "Down + Trick" over your head when the trick finisher's ready
var _over_key := ""
var _over_in := 1.0             # 0 -> 1 as it fades in

const ROW_HEIGHT := 38
const SEE_THROUGH := 0.45       # how solid the prompts are
const FONT_SIZE := 20
const FROM_TOP := 0.30          # where the list starts, as a share of the screen height
const TOUCH_ART := {"ui_accept": "res://misc/JumpButton.png", "airspin": "res://misc/DashButton.png",
	"airup": "res://misc/DashButtonUp.png", "trick": "res://Sprites/UI/TouchScreen/trick.png"}
# Controller buttons by number, Xbox names
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_DPAD_UP: "Up", JOY_BUTTON_DPAD_DOWN: "Down", JOY_BUTTON_DPAD_LEFT: "Left", JOY_BUTTON_DPAD_RIGHT: "Right"}
const PAD_COLOURS := {"A": Color(0.35, 0.8, 0.3), "B": Color(0.9, 0.25, 0.25), "X": Color(0.25, 0.5, 0.95), "Y": Color(0.95, 0.8, 0.2)}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = SEE_THROUGH
	add_child(_box)
	_over = HBoxContainer.new()
	_over.add_theme_constant_override("separation", 3)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.visible = false
	add_child(_over)
	if Test.mobile:
		_device = "touch"


func _input(event: InputEvent) -> void:
	var was := _device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_device = "pad"
	elif event is InputEventKey:
		_device = "keys"
	elif event is InputEventScreenTouch:
		_device = "touch"
	if was != _device:
		_key = ""   # redraw with the other buttons


func _process(_delta: float) -> void:
	var p: Node = controller.get("current_character") if controller else null
	var on: bool = Test.display == null or Test.display.move_prompts
	visible = on and p != null and is_instance_valid(p) and not Pause.visible and not p.get("is_player_dead")
	if not visible:
		return
	var rows := _moves(p)
	var key := str(rows) + _device
	if key != _key:
		_key = key
		_rows = rows
		_rebuild()
	var vp := get_viewport_rect().size
	_box.position = Vector2(vp.x - _box.size.x - 18, vp.y * FROM_TOP)
	_finisher_over(p)


# Over your head, when the trick finisher's ready
const OVER_HEAD := 78.0   # how far above the character

func _finisher_over(p: Node) -> void:
	var ready: bool = not p.is_on_floor() and not p.get("finished_in_air") and GlobalCanvasLayer.tricks >= 3 \
			and p.find_children("*", "", false, false).any(func(c): return c.scene_file_path.get_file().get_basename() == "trick")
	if ready and not _over.visible:
		# a quick fade in, nothing fancy
		_over_in = 0.0
		_over.scale = Vector2.ONE
		_over.create_tween().tween_property(self, "_over_in", 1.0, FADE)
	_over.visible = ready
	if not ready:
		return
	if _over_key != _device:
		_over_key = _device
		for c in _over.get_children():
			c.queue_free()
		_over.add_child(_glyph("ui_down"))
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", FONT_SIZE)
		plus.add_theme_color_override("font_outline_color", Color.BLACK)
		plus.add_theme_constant_override("outline_size", 4)
		_over.add_child(plus)
		_over.add_child(_glyph("trick"))
		_over.reset_size()
	var at: Vector2 = (p as CanvasItem).get_global_transform_with_canvas().origin
	_over.pivot_offset = Vector2(_over.size.x * 0.5, _over.size.y)
	_over.position = at - Vector2(_over.size.x * 0.5, OVER_HEAD + _over.size.y)
	_over.modulate.a = _over_in * SEE_THROUGH


# What this character can do right now, without crowding the screen
func _moves(p: Node) -> Array:
	var has := {}
	for c in p.get_children():
		var path: String = c.scene_file_path
		if path != "" and c.has_method("action") and not (c.name in p.get("skip_abilities") if "skip_abilities" in p else false):
			has[path.get_file().get_basename()] = c
	var out: Array = []
	var meter: float = p.my_meter
	var down: bool = p.inp_pressed("ui_down")
	var up: bool = p.inp_pressed("ui_up")
	if p.get("hanging_on_wall"):
		out.append(["Wall Jump", ["ui_accept"], false])
		if has.has("wall_climb"):
			out.append(["Climb", ["ui_up"], true])
		return out
	# Up near a line of rings
	var light: bool = up and not down and p.has_method("light_dash_ready") and p.light_dash_ready()
	if p.is_on_floor():
		if light:
			out.append(["Light Speed Dash", ["trick"], false])   # up's already held
			return out
		if down:
			out.append(["Spin Dash", ["ui_accept"], false])   # down's already held
		elif up and has.has("peelout") and absf(p.motion.x) < 1.0:
			out.append(["Peel Out", ["ui_accept"], false])
		elif absf(p.motion.x) > 300.0 and has.has("ground_boost") and meter >= _cost(has.ground_boost) and not p.get("is_boosting"):
			out.append(["Boost", ["airspin"], true])   # running: you could boost
		return out
	# In the air
	if down:
		if has.has("stomp") and p.can_stomp:
			out.append(["Stomp", ["airspin"], false])
		if has.has("trick") and not p.flying and GlobalCanvasLayer.tricks >= 3:
			out.append(["Trick Finisher", ["trick"], false])
		return out
	if up:
		if light:
			out.append(["Light Speed Dash", ["trick"], false])
			return out
		var up_move = has.get("airup", has.get("airspinup"))
		if up_move and meter >= _cost(up_move) and not p.flying:
			out.append(["Up Boost", ["airspin"], false])
		if not p.get("is_super") and not p.is_in_group("super_form") and Test.chaos_emeralds >= Test.SUPER_EMERALDS and p.my_rings >= Test.SUPER_RINGS:
			out.append(["Hyper" if Test.super_emeralds >= Test.SUPER_EMERALDS else "Super", ["trick"], false])
		return out
	# The jump button's move
	var homing = has.get("homing_attack")
	if homing and homing.has_method("has_target") and homing.has_target():
		out.append(["Homing Attack", ["ui_accept"], false])
	elif has.has("flick") and p.can_dash:
		out.append(["Air Dash", ["ui_accept"], false])
	elif has.has("fly") and (p.flying or p.can_dash):
		out.append(["Fly Up" if p.flying else "Fly", ["ui_accept"], p.flying])
	elif (has.has("glide") or has.has("hover")) and not p.flying:
		out.append(["Glide" if has.has("glide") else "Hover", ["ui_accept"], true])
	# The boost button's move
	if has.has("airspin") and meter >= _cost(has.airspin):
		out.append(["Air Boost", ["airspin"], false])
	elif has.has("swipe_attack") and not p.swipe:
		out.append(["Swipe", ["airspin"], false])
	if has.has("trick") and not p.flying:
		out.append(["Trick", ["trick"], false])
	return out


func _cost(ability: Node) -> float:
	return Test.meter_cost(ability.get("meter_cost")) if "meter_cost" in ability else 0.0


# The list changed
const FADE := 0.1
var _shown := {}             # row key -> its holder

func _rebuild() -> void:
	var keys: Array = []
	for r in _rows:
		keys.append(str(r) + _device)
	for k in _shown.keys():
		if not k in keys:
			_leave(_shown[k])
			_shown.erase(k)
	var at := 0
	for i in _rows.size():
		var k: String = keys[i]
		if not _shown.has(k):
			var r: Array = _rows[i]
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.size_flags_horizontal = Control.SIZE_SHRINK_END
			var bar := _row(r[0], r[1], r[2])
			holder.add_child(bar)
			_box.add_child(holder)
			var want := bar.get_combined_minimum_size()
			bar.size = want
			holder.custom_minimum_size = want
			_enter(bar)
			_shown[k] = holder
		_box.move_child(_shown[k], at)
		at += 1


func _enter(bar: Control) -> void:
	bar.modulate.a = 0.0
	bar.create_tween().tween_property(bar, "modulate:a", 1.0, FADE)


func _leave(holder: Control) -> void:
	if not is_instance_valid(holder):
		return
	var tw := holder.create_tween()
	tw.tween_property(holder, "modulate:a", 0.0, FADE)
	tw.chain().tween_callback(holder.queue_free)


# One prompt: the move's name on a slanted dark-blue bar, then its buttons
func _row(text: String, actions: Array, hold: bool) -> Control:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.08, 0.22, 0.72)
	st.border_color = Color(0.35, 0.6, 1.0, 0.55)
	st.border_width_left = 3
	st.skew = Vector2(0.35, 0)
	st.content_margin_left = 16
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var l := Label.new()
	l.text = text + ("  (hold)" if hold else "")
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	for i in actions.size():
		if i > 0:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", FONT_SIZE)
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(plus)
		row.add_child(_glyph(str(actions[i])))
	return bar


# The button for an action
func _glyph(action: String) -> Control:
	if _device == "touch":
		if TOUCH_ART.has(action) and ResourceLoader.exists(TOUCH_ART[action]):
			var tr := TextureRect.new()
			tr.texture = load(TOUCH_ART[action])
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tr
		return _cap({"ui_up": "Up", "ui_down": "Down", "switch": "Switch", "trick": "Trick", "airspin": "Boost", "ui_accept": "Jump"}.get(action, action), Color(0.2, 0.2, 0.25), false)
	if _device == "pad":
		var n := _pad_name(action)
		return _cap(n, PAD_COLOURS.get(n, Color(0.25, 0.25, 0.3)), n.length() == 1)
	return _cap(_key_name(action), Color(0.92, 0.92, 0.95), false, Color.BLACK)


func _cap(text: String, colour: Color, round_button: bool, ink := Color.WHITE) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = colour
	st.border_color = Color(0, 0, 0, 0.8)
	st.set_border_width_all(2)
	st.set_corner_radius_all(ROW_HEIGHT if round_button else 5)
	st.content_margin_left = 8 if not round_button else 6
	st.content_margin_right = st.content_margin_left
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	l.add_theme_color_override("font_color", ink)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


func _events(action: String) -> Array:
	return InputMap.action_get_events(action) if InputMap.has_action(action) else []


func _key_name(action: String) -> String:
	for e in _events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			if code in [KEY_ENTER, KEY_KP_ENTER]:
				continue   # Enter works too, but isn't the one to show
			return OS.get_keycode_string(code)
	return action


func _pad_name(action: String) -> String:
	for e in _events(action):
		if e is InputEventJoypadButton and PAD_NAMES.has(e.button_index):
			return PAD_NAMES[e.button_index]
	for e in _events(action):
		if e is InputEventJoypadMotion:
			match e.axis:
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_LEFT_Y: return "Up" if e.axis_value < 0 else "Down"
				JOY_AXIS_LEFT_X: return "Left" if e.axis_value < 0 else "Right"
	return action
