extends CanvasLayer
# DISPLAY & CONTROLS screen

signal closed

const DS := preload("res://Scripts/UI/display_settings.gd")

var _first: Control
var _pickers: Array[OptionButton] = []
var _size_row: Control


static func open(parent: Node) -> Node:
	var s = load("res://Scripts/UI/display_screen.gd").new()
	parent.add_child(s)
	return s


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Node = Test.display
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# In the middle of the screen
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # a controller moving down the list scrolls it
	centre.add_child(scroll)
	var page := VBoxContainer.new()
	page.custom_minimum_size = Vector2(820, 0)
	page.add_theme_constant_override("separation", 12)
	scroll.add_child(page)
	var title := Label.new()
	title.text = "DISPLAY & CONTROLS"
	title.add_theme_font_size_override("font_size", 40)
	page.add_child(title)

	if DS.has_window():
		_choice(page, "Window", DS.MODES, d.window_mode, func(i: int) -> void:
			d.save("window_mode", i)
			_size_row.modulate.a = 1.0 if i == 0 else 0.4)
		var sizes: Array = d.sizes()
		var names: Array = sizes.map(func(s: Vector2i) -> String: return "%d x %d" % [s.x, s.y])
		_size_row = _choice(page, "Resolution", names, sizes.find(d.window_size), func(i: int) -> void:
			d.save("window_size", sizes[i])).get_parent()
		_size_row.modulate.a = 1.0 if d.window_mode == 0 else 0.4   # full screen uses the screen's own
	_toggle(page, "VSync", d.vsync, func(on: bool) -> void: d.save("vsync", on))
	_toggle(page, "Move Prompts", d.move_prompts, func(on: bool) -> void: d.save("move_prompts", on))
	var fps_names: Array = DS.FPS.map(func(f: int) -> String: return "Unlimited" if f == 0 else str(f))
	_choice(page, "Max FPS", fps_names, maxi(0, DS.FPS.find(d.max_fps)), func(i: int) -> void: d.save("max_fps", DS.FPS[i]))
	_slider(page, "Brightness", d.brightness, 0.5, 2.0, func(v: float) -> void: d.save("brightness", v))
	_slider(page, "Screen Shake", d.screen_shake, 0.0, 1.5, func(v: float) -> void: d.save("screen_shake", v))
	_slider(page, "Mouse Look", Test.salvage_look, 0.2, 3.0, func(v: float) -> void: Test.save_salvage_look(v))
	_slider(page, "Controller Look", d.stick_look, 0.2, 3.0, func(v: float) -> void: d.save("stick_look", v))
	_toggle(page, "Invert Look Up/Down", d.invert_look, func(on: bool) -> void: d.save("invert_look", on))
	_toggle(page, "Salvage PS1 Filter", d.salvage_ps1, func(on: bool) -> void: d.save("salvage_ps1", on))
	_slider(page, "Field of View", d.fov, 60.0, 110.0, func(v: float) -> void: d.save("fov", v), true)

	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_close)
	page.add_child(back)

	await get_tree().process_frame
	var tall: float = page.get_combined_minimum_size().y
	scroll.custom_minimum_size = Vector2(840, minf(tall, root.size.y - 60.0))
	if _first:
		_first.grab_focus()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 340
	return l


func _row(page: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_label(title))
	page.add_child(row)
	return row


func _choice(page: Control, title: String, names: Array, current: int, pick: Callable) -> OptionButton:
	var row := _row(page, title)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_ALL
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in names:
		opt.add_item(str(n))
	opt.select(clampi(current, 0, names.size() - 1))
	opt.item_selected.connect(pick)
	row.add_child(opt)
	_pickers.append(opt)
	if _first == null:
		_first = opt
	return opt


func _toggle(page: Control, title: String, on: bool, changed: Callable) -> void:
	var row := _row(page, title)
	var t := CheckButton.new()
	t.focus_mode = Control.FOCUS_ALL
	t.button_pressed = on
	t.toggled.connect(changed)
	row.add_child(t)
	if _first == null:
		_first = t


# A slider; shown as a percentage, or as the number itself
func _slider(page: Control, title: String, value: float, lo: float, hi: float, changed: Callable, plain := false) -> void:
	var row := _row(page, title)
	var s := HSlider.new()
	s.focus_mode = Control.FOCUS_ALL
	s.min_value = lo
	s.max_value = hi
	s.step = 1.0 if plain else 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shown := Label.new()
	shown.custom_minimum_size.x = 100
	var fmt := func(v: float) -> String: return ("%d" % roundi(v)) if plain else ("%d%%" % roundi(v * 100.0))
	shown.text = fmt.call(value)
	s.value_changed.connect(func(v: float) -> void:
		shown.text = fmt.call(v)
		changed.call(v))
	row.add_child(s)
	row.add_child(shown)
	if _first == null:
		_first = s


func _input(event: InputEvent) -> void:
	var back: bool = event.is_action_pressed("ui_cancel") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		for o in _pickers:
			if o.get_popup().visible:
				return
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
