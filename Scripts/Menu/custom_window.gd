extends Control
# The character select screen's CUSTOM window

static var reopen := false     # open again after the screen reloads

var screen: Control
var manager: Node              # the screen's CharacterManager
var _list: GridContainer
var _list_box: Control
var _empty: Label
var _form: Control
var _name_edit: LineEdit
var _base_pick: OptionButton
var _sheet_label: Label
var _portrait_label: Label
var _preview: TextureRect
var _status: Label
var _sheet_path := ""
var _portrait_path := ""
var _dialog: FileDialog
var _dialog_for := ""          # "sheet", "portrait" or "template"
var _cards := {}               # id -> Button

const RED := Color(0.86, 0.08, 0.1)
const CARD := Vector2(200, 168)


func setup(select_screen: Control) -> void:
	screen = select_screen
	manager = screen.get_node_or_null("Charborder")
	name = "CustomWindow"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -500
	panel.offset_top = -300
	panel.offset_right = 500
	panel.offset_bottom = 300
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.04, 0.04, 0.05)
	box_style.border_color = RED
	box_style.set_border_width_all(4)
	box_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", box_style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("CUSTOM CHARACTERS", 40, HORIZONTAL_ALIGNMENT_CENTER))
	# The list
	_list_box = VBoxContainer.new()
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_list_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 5
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_list)
	_empty = _label("No custom characters yet.\nClick NEW and pick your sprite sheet,\nor drag a sprite sheet onto the game.", 24, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_list_box.add_child(_empty)
	var row := _row(_list_box)
	_button(row, "NEW", func(): _show_form(true))
	if not OS.has_feature("mobile"):   # phones can't open a folder
		_button(row, "FOLDER", func():
			CustomCharacters.make_folder()
			OS.shell_open(ProjectSettings.globalize_path(CustomCharacters.DIR)))
	_button(row, "CLOSE", close)
	_build_form(v)
	_fill()
	get_window().files_dropped.connect(_on_files_dropped)
	if reopen:
		reopen = false
		open.call_deferred()


func open() -> void:
	visible = true
	_show_form(false)


func close() -> void:
	visible = false
	if _dialog:
		_dialog.hide()


# Your custom characters as cards
func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_cards.clear()
	var count := 0
	for e in Content.characters():
		if e.custom_dir == "":
			continue
		count += 1
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.toggle_mode = true
		b.icon = e.select_icon_active
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = e.display_name.to_upper()
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 14)
		_card_style(b, e.hover_color)
		var slot := _slot(e.id)
		if slot:
			b.button_pressed = slot.is_selected
			b.toggled.connect(func(_on: bool) -> void:
				slot.select_sprite()
				_sync())
			b.mouse_entered.connect(func(): slot.set_hovered(true))
			b.mouse_exited.connect(func(): slot.set_hovered(false))
			b.focus_entered.connect(func(): slot.set_hovered(true))
			b.focus_exited.connect(func(): slot.set_hovered(false))
		_list.add_child(b)
		_cards[e.id] = b
	_empty.visible = count == 0
	_list.get_parent().visible = count > 0


# Cards match who's picked
func _sync() -> void:
	for id in _cards:
		var slot := _slot(id)
		if slot:
			_cards[id].set_pressed_no_signal(slot.is_selected)


func _slot(id: String) -> SelectableCharacter:
	return manager.get_node_or_null(NodePath("CustomSlots/" + id)) as SelectableCharacter if manager else null


# NEW: a name, whose moves, your sheet
func _build_form(parent: Control) -> void:
	_form = VBoxContainer.new()
	_form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 12)
	parent.add_child(_form)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form.add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	left.add_child(_label("NAME", 22))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "My Character"
	_name_edit.add_theme_font_size_override("font_size", 22)
	left.add_child(_name_edit)
	left.add_child(_label("MOVES OF", 22))
	_base_pick = OptionButton.new()
	_base_pick.add_theme_font_size_override("font_size", 22)
	for e in Content.characters():
		if e.custom_dir == "":
			_base_pick.add_item(e.id)
	left.add_child(_base_pick)
	var r1 := _row(left)
	_button(r1, "SPRITE SHEET", func(): _pick("sheet"))
	_sheet_label = _label("", 18)
	r1.add_child(_sheet_label)
	var r2 := _row(left)
	_button(r2, "PORTRAIT", func(): _pick("portrait"))
	_portrait_label = _label("optional", 18)
	r2.add_child(_portrait_label)
	var tip := _label("Your sheet uses the same layout as the MOVES OF character's.\nTEMPLATE saves theirs to draw over.", 16)
	tip.modulate = Color(0.7, 0.7, 0.75)
	left.add_child(tip)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(300, 300)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_preview)
	_status = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_status.modulate = Color(1, 0.45, 0.45)
	_form.add_child(_status)
	var row := _row(_form)
	_button(row, "CREATE", _create)
	_button(row, "TEMPLATE", func(): _pick("template"))
	_button(row, "BACK", func(): _show_form(false))


func _show_form(on: bool) -> void:
	_form.visible = on
	_list_box.visible = not on
	_status.text = ""
	if on:
		_name_edit.grab_focus.call_deferred()
	elif _cards.size() > 0:
		_cards.values()[0].grab_focus.call_deferred()
	else:
		var b := _list_box.find_children("*", "Button", true, false)
		if not b.is_empty():
			b[0].grab_focus.call_deferred()


# The computer's own file picker
func _pick(what: String) -> void:
	_dialog_for = what
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.use_native_dialog = true
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_selected.connect(_on_file)
		add_child(_dialog)
	if what == "template":
		_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_dialog.title = "Save the template sheet"
		_dialog.filters = PackedStringArray(["*.png ; PNG picture"])
		_dialog.current_file = "%s_sheet.png" % _base_pick.get_item_text(_base_pick.selected)
	else:
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.title = "Pick your sprite sheet" if what == "sheet" else "Pick your portrait"
		_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
	_dialog.popup_centered_ratio(0.7)


func _on_file(path: String) -> void:
	match _dialog_for:
		"sheet":
			_set_sheet(path)
		"portrait":
			_set_portrait(path)
		"template":
			var err := CustomCharacters.save_template(_base_pick.get_item_text(_base_pick.selected), path)
			_status.modulate = Color(0.6, 1, 0.6) if err == "" else Color(1, 0.45, 0.45)
			_status.text = "Saved %s" % path.get_file() if err == "" else err


func _set_sheet(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_status.text = "%s isn't a picture the game can read" % path.get_file()
		return
	_sheet_path = path
	_sheet_label.text = path.get_file()
	_preview.texture = ImageTexture.create_from_image(img)
	if _name_edit.text.strip_edges() == "":
		_name_edit.text = path.get_file().get_basename().replace("_", " ").replace("-", " ").substr(0, 24)
	_status.text = ""


func _set_portrait(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_status.text = "%s isn't a picture the game can read" % path.get_file()
		return
	_portrait_path = path
	_portrait_label.text = path.get_file()


# Pictures dragged onto the game window
func _on_files_dropped(files: PackedStringArray) -> void:
	if not is_inside_tree() or not screen.is_inside_tree():
		return
	for f in files:
		if not f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			continue
		if not visible:
			open()
		if not _form.visible:
			_show_form(true)
		if _sheet_path == "":
			_set_sheet(f)
		else:
			_set_portrait(f)


func _create() -> void:
	_status.modulate = Color(1, 0.45, 0.45)
	if _sheet_path == "":
		_status.text = "Pick your sprite sheet first"
		return
	var err := CustomCharacters.create(_name_edit.text, _base_pick.get_item_text(_base_pick.selected), _sheet_path, _portrait_path)
	if err != "":
		_status.text = err
		return
	reopen = true
	get_tree().reload_current_scene()   # shows it, in this window


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _form.visible:
			_show_form(false)
		else:
			close()


# LOOKS

func _label(text: String, size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 18)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 48)
	b.add_theme_font_size_override("font_size", 22)
	_card_style(b, RED)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _card_style(b: Button, colour: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.1, 0.1, 0.12) if state == "normal" else Color(0.18, 0.18, 0.2)
		s.border_color = colour if state != "normal" else Color(0.35, 0.35, 0.4)
		s.set_border_width_all(4 if state in ["pressed", "hover_pressed"] else 2)
		if state in ["pressed", "hover_pressed"]:
			s.bg_color = colour.darkened(0.55)
		s.set_content_margin_all(8)
		if state == "focus":
			s.draw_center = false   # just the outline, over whatever it is
			s.border_color = Color.WHITE
		b.add_theme_stylebox_override(state, s)
