extends Control
## Online lobby (Scenes/Menu/online_lobby.tscn), reached from character select.
##   HOST: makes a room and shows its 4-letter code to share.
##   JOIN: type the code you were given.
## In the room every player picks their character (left / right), and 1P (the
## host) presses START. Works with mouse, keyboard or controller.
## The networking itself is in net.gd (autoload "Net").

const RED := Color(0.86, 0.08, 0.08)

var _menu: VBoxContainer
var _code_edit: LineEdit
var _server_edit: LineEdit
var _status: Label
var _room: VBoxContainer
var _code_label: Label
var _address_label: Label   # HOST ON MY PC: the addresses friends type in SERVER
var _router_line := ""
var _direct_label: Label    # "Direct connections: 1/1" (p2p.gd)
var _slots: Array = []        # [Label, TextureRect] per player slot
var _start_btn: Button
var _icons := {}


func _ready() -> void:
	Pause.current_scene = ""
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("ONLINE", 72, Color.WHITE)
	title.position = Vector2(0, 40)
	title.size = Vector2(1600, 90)
	add_child(title)

	# Host / join menu
	_menu = VBoxContainer.new()
	_menu.position = Vector2(560, 170)
	_menu.size = Vector2(480, 300)
	_menu.add_theme_constant_override("separation", 18)
	add_child(_menu)
	var host_btn := _button("HOST A GAME", _on_host)
	_menu.add_child(host_btn)
	# Player to player: this game is the server, friends connect straight to it.
	# (Not in the web version: a browser can't accept connections; it hosts and
	# joins through the online server.)
	if not OS.has_feature("web"):
		_menu.add_child(_button("HOST ON MY PC", _on_host_pc))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "ROOM CODE"
	_code_edit.max_length = 4
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_size_override("font_size", 40)
	_code_edit.custom_minimum_size = Vector2(0, 64)
	_code_edit.text_changed.connect(func(t): _code_edit.text = t.to_upper(); _code_edit.caret_column = t.length())
	_code_edit.text_submitted.connect(func(_t): _on_join())
	_menu.add_child(_code_edit)
	_menu.add_child(_button("JOIN WITH CODE", _on_join))
	_menu.add_child(_button("BACK", _on_back))
	# Which relay server to meet on (everyone in a game must use the same one).
	# Paste the address the host gives you; it's remembered.
	var server_row := HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 10)
	var server_l := _label("SERVER", 20, Color(0.75, 0.75, 0.8))
	server_row.add_child(server_l)
	_server_edit = LineEdit.new()
	_server_edit.text = Net.server_url()
	_server_edit.placeholder_text = "a friend's address, or empty for the online server"
	_server_edit.add_theme_font_size_override("font_size", 18)
	_server_edit.custom_minimum_size = Vector2(380, 40)
	_server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_edit.select_all_on_focus = true
	_server_edit.text_submitted.connect(func(_t): _apply_server())
	_server_edit.focus_exited.connect(_apply_server)
	server_row.add_child(_server_edit)
	_menu.add_child(server_row)
	# Direct connections between players (p2p.gd) on or off
	if Net.p2p and Net.p2p.supported:
		var direct := CheckButton.new()
		direct.text = "DIRECT CONNECTIONS"
		direct.button_pressed = Net.p2p.is_enabled()
		direct.add_theme_font_size_override("font_size", 20)
		direct.alignment = HORIZONTAL_ALIGNMENT_CENTER
		direct.toggled.connect(func(on: bool) -> void: Net.p2p.set_enabled(on))
		_menu.add_child(direct)

	# In a room
	_room = VBoxContainer.new()
	_room.position = Vector2(300, 150)
	_room.size = Vector2(1000, 500)
	_room.add_theme_constant_override("separation", 14)
	_room.visible = false
	add_child(_room)
	_code_label = _label("", 48, Color.WHITE)
	_room.add_child(_code_label)
	_address_label = _label("", 22, Color(0.75, 0.9, 1.0))
	_address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (long lines pushed the room off to the side)
	_address_label.custom_minimum_size = Vector2(1000, 0)
	_address_label.visible = false
	_room.add_child(_address_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	_room.add_child(row)
	for i in 4:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(210, 260)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(160, 160)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		col.add_child(icon)
		var name_l := _label("", 26, Color.WHITE)
		col.add_child(name_l)
		row.add_child(col)
		_slots.append([name_l, icon])
	var hint := _label("LEFT / RIGHT to choose your character", 22, Color(0.75, 0.75, 0.8))
	_room.add_child(hint)
	_direct_label = _label("", 18, Color(0.55, 0.85, 0.6))
	_room.add_child(_direct_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	_room.add_child(buttons)
	buttons.add_child(_button("<", func(): _cycle(-1)))
	_start_btn = _button("START", _on_start)
	buttons.add_child(_start_btn)
	buttons.add_child(_button(">", func(): _cycle(1)))
	buttons.add_child(_button("LEAVE", _on_leave))

	_status = _label("", 26, Color(1, 0.4, 0.4))
	_status.position = Vector2(0, 760)
	_status.size = Vector2(1600, 40)
	add_child(_status)

	Net.room_created.connect(func(_c): _show_room())
	Net.net_status.connect(func(t): _status.text = t)
	Net.joined_room.connect(func(_c, _i): _show_room())
	Net.peers_changed.connect(_refresh)
	if Net.p2p:
		Net.p2p.changed.connect(_refresh)
	Net.net_error.connect(func(t): _status.text = t; if Net.room_code == "": _show_menu())
	if Net.last_error != "":
		_status.text = Net.last_error
		Net.last_error = ""
	_show_menu()
	# Automated tests: SONIC_ONLINE_TEST=host or =join:CODE
	var auto := OS.get_environment("SONIC_ONLINE_TEST")
	if auto == "host":
		_on_host()
	elif auto.begins_with("join:"):
		_code_edit.text = auto.substr(5)
		_on_join()


func _apply_server() -> void:
	if _server_edit:
		_server_edit.text = Net.set_server_url(_server_edit.text)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 32)
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(cb)
	return b


func _show_menu() -> void:
	_menu.visible = true
	_room.visible = false
	(_menu.get_child(0) as Button).grab_focus()


func _show_room() -> void:
	_menu.visible = false
	_room.visible = true
	_status.text = ""
	_start_btn.grab_focus()
	_refresh()


func _refresh() -> void:
	if not _room.visible:
		return
	_code_label.text = "ROOM CODE:  " + Net.room_code
	_address_label.visible = Net.hosting_on_my_pc()
	if Net.hosting_on_my_pc():
		var addrs := Net.LOCAL_RELAY.local_addresses()
		_address_label.text = "Friends type this in SERVER, then the code:\n%s%s" % [
			"   or   ".join(addrs) if not addrs.is_empty() else "(no network found)", _router_line]
	for i in 4:
		var id := i + 1
		var name_l: Label = _slots[i][0]
		var icon: TextureRect = _slots[i][1]
		if Net.peers.has(id):
			var c: String = Net.peers[id]["char"]
			name_l.text = "%dP%s\n%s" % [id, "  (YOU)" if id == Net.my_id else "", c.to_upper()]
			name_l.add_theme_color_override("font_color", Net.TAG_COLORS[i])
			icon.texture = _icon(c)
			icon.modulate = Color.WHITE
		else:
			name_l.text = "%dP\nWAITING..." % id
			name_l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
			icon.texture = null
	var direct := Net.direct_status()
	_direct_label.text = ("Direct connections: " + direct) if direct != "" else ""
	_start_btn.disabled = not Net.is_host
	_start_btn.text = "START" if Net.is_host else "1P STARTS"


func _icon(char_name: String) -> Texture2D:
	if not _icons.has(char_name):
		var tex: Texture2D = null
		var scene := Content.character_scene(char_name)
		if scene:
			var inst = scene.instantiate()
			tex = inst.get("icon_character")
			inst.free()
		_icons[char_name] = tex
	return _icons[char_name]


func _cycle(dir: int) -> void:
	if not Net.peers.has(Net.my_id):
		return
	var names := Content.character_ids()
	var i := names.find(Net.peers[Net.my_id]["char"])
	Net.pick(names[wrapi(i + dir, 0, names.size())])


func _unhandled_input(event: InputEvent) -> void:
	if not _room.visible:
		return
	if event.is_action_pressed("ui_left"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_leave()


func _on_host() -> void:
	_apply_server()
	_status.text = "Connecting..."
	Net.host_room()


func _on_host_pc() -> void:
	_status.text = "Starting the game server on this PC..."
	_router_line = "\n(checking whether the router lets friends in over the internet...)"
	var problem := Net.host_on_my_pc()
	if problem != "":
		_status.text = problem
		return
	if Net.local_relay:
		Net.local_relay.router_result.connect(func(ip: String) -> void:
			_router_line = ("\nOver the internet:  %s   (the router opened port %d)" % [ip, Net.LOCAL_RELAY.PORT]) if ip != "" \
				else "\nFriends outside your home: use Tailscale or Radmin VPN (the router didn't open port %d)" % Net.LOCAL_RELAY.PORT
			_refresh())


func _on_join() -> void:
	_apply_server()
	if _code_edit.text.strip_edges().length() != 4:
		_status.text = "Type the 4-letter room code"
		return
	_status.text = "Joining..."
	Net.join_room(_code_edit.text)


func _on_start() -> void:
	if Net.is_host:
		Net.start_game()


func _on_leave() -> void:
	Net.leave()
	_show_menu()


func _on_back() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://Scenes/Menu/character_select_screen.tscn")
