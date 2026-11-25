extends CanvasLayer
# The SAVE FILE screen

signal closed


var _note: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_CENTER)
	page.custom_minimum_size = Vector2(760, 0)
	page.position = Vector2(-380, -230)
	page.add_theme_constant_override("separation", 14)
	root.add_child(page)

	var title := Label.new()
	title.text = "SAVE FILE"
	title.add_theme_font_size_override("font_size", 40)
	page.add_child(title)

	var records := Label.new()
	records.text = "Best floor time: %s\nDeepest floor reached: %s\nTimes beaten: %d" % [
		Test.bestTimeText.trim_prefix("BEST TIME: ") if Test.bestTimeFloat < INF else "-",
		str(Test.deepest_floor) if Test.deepest_floor > 0 else "-",
		Test.times_beaten]
	page.add_child(records)

	var about := Label.new()
	about.text = "Your save holds your records, settings, controls, key bindings and playlists. Download it to keep a backup, or to carry it to another browser or computer and load it there."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 760
	page.add_child(about)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	page.add_child(buttons)
	var down := _button(buttons, "Download Save", _download)
	_button(buttons, "Load Save", _upload)
	_button(buttons, "Back", close)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 760
	page.add_child(_note)
	down.grab_focus.call_deferred()


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _download() -> void:
	SaveFile.download(func(message: String) -> void:
		if message != "":
			_note.text = message)


func _upload() -> void:
	_note.text = "Pick your save file (%s)..." % SaveFile.DOWNLOAD_NAME
	SaveFile.upload(func(message: String, loaded: bool) -> void:
		_note.text = message
		if loaded:
			await get_tree().create_timer(1.5).timeout
			SaveFile.restart(get_tree()))


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	var back: bool = event.is_action_pressed("ui_cancel") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		get_viewport().set_input_as_handled()
		close()
