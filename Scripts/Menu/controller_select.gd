extends Node2D
## Controller (and keyboard) navigation for the character select screen, which
## was mouse-only.
##   D-pad / left stick / arrow keys: move the cursor between characters,
##     TUTORIALS and START (moves to whatever is nearest in that direction)
##   A / Enter / Space: pick or un-pick the character under the cursor, open the
##     tutorials, or start (once at least one character is picked)
##   B: un-pick the character under the cursor, or the most recent pick
##   Start: move the cursor onto START (press A there to begin)
## The cursor uses the screen's own hover effects (the same ones the mouse
## triggers), with no extra marker. It steps aside when the mouse moves, so mouse
## play works exactly as before.
## Created by character_select_screen.gd.

const REPEAT_DELAY := 0.35      # seconds before a held direction repeats
const REPEAT_RATE := 0.13

var screen: Control             # the character select screen
var items: Array = []           # SelectableCharacters, then Tutorial, then Start
var index := 0
var active := false             # cursor shown (after the first controller/keyboard input)
var _held_dir := Vector2.ZERO
var _repeat := 0.0
var _hovered: Object = null


func setup(select_screen: Control) -> void:
	screen = select_screen
	var manager := screen.get_node_or_null("Charborder")
	if manager:
		for c in manager.find_children("*", "SelectableCharacter"):
			items.append(c)
	if screen.has_node("Tutorial"):
		items.append(screen.get_node("Tutorial"))
	if screen.has_node("Online"):
		items.append(screen.get_node("Online"))
	if screen.has_node("Start"):
		items.append(screen.get_node("Start"))
	z_index = 200
	z_as_relative = false


func _process(delta: float) -> void:
	if items.is_empty() or _blocked():
		return
	var dir := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if dir.length() < 0.5:
		dir = Vector2.ZERO
	else:
		# Pick the main direction so diagonals on the stick don't skip around
		dir = Vector2(sign(dir.x), 0) if abs(dir.x) >= abs(dir.y) else Vector2(0, sign(dir.y))
	if dir != Vector2.ZERO:
		if dir != _held_dir:
			_held_dir = dir
			_repeat = REPEAT_DELAY
			_move(dir)
		else:
			_repeat -= delta
			if _repeat <= 0.0:
				_repeat = REPEAT_RATE
				_move(dir)
	else:
		_held_dir = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if items.is_empty() or _blocked():
		return
	if event is InputEventMouseMotion and event.relative.length() > 2.0:
		_set_active(false)
		return
	# (Each press is marked handled BEFORE acting on it: picking ONLINE or START
	# changes scene straight away, and this node is out of the tree after that.)
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				get_viewport().set_input_as_handled()
				_accept()
			JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				_back()
			JOY_BUTTON_START:
				# Only moves the cursor onto START; the game begins when you press A on it
				if active:
					index = items.size() - 1
					_hover(items[index])
				else:
					index = items.size() - 1
					_set_active(true)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and active:
			get_viewport().set_input_as_handled()
			_accept()
		elif event.keycode == KEY_BACKSPACE and active:
			get_viewport().set_input_as_handled()
			_back()


func _blocked() -> bool:
	# Not while the tutorial dialogue is up, or while the game is paused
	if get_tree().paused:
		return true
	var cover := screen.get_node_or_null("TutorialElements/TutorialCover") as CanvasItem
	return cover != null and cover.visible


func _set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if on:
		_hover(items[index])
	else:
		_unhover()


func _move(dir: Vector2) -> void:
	if not active:
		_set_active(true)       # first press just shows the cursor where it is
		return
	var from := _center(items[index])
	var best := -1
	var best_score := INF
	# First look in a cone in the pressed direction; if nothing's there, anything that way
	for cone in [true, false]:
		for i in items.size():
			if i == index or not _usable(items[i]):
				continue
			var d := _center(items[i]) - from
			var along := d.dot(dir)
			var across := absf(d.dot(Vector2(-dir.y, dir.x)))
			if along <= 4.0 or (cone and across > along * 1.2):
				continue
			var score := along + across * 2.2   # prefer things straight ahead
			if score < best_score:
				best_score = score
				best = i
		if best >= 0:
			break
	if best >= 0:
		index = best
		_hover(items[index])


func _usable(item: Object) -> bool:
	return item is CanvasItem and (item as CanvasItem).is_visible_in_tree()


func _accept() -> void:
	if not active:
		_set_active(true)
		return
	var item = items[index]
	if item is SelectableCharacter:
		item.select_sprite()          # toggles: picks, or un-picks if already picked
		var snd = item.get_node_or_null("AudioStreamPlayer2")
		if snd:
			snd.play()
	elif item.has_signal("tutorial"):
		if item.name == "Online":
			set_process_input(false)   # this screen is about to go away
			set_process(false)
		item.emit_signal("tutorial")
	elif item.has_signal("sprite_clicked"):
		if item.has_method("is_selection_allowed") and not item.is_selection_allowed():
			_nudge(item)              # nothing picked yet
			return
		set_process_input(false)
		set_process(false)
		item.emit_signal("sprite_clicked", item)


func _back() -> void:
	var item = items[index] if active else null
	if item is SelectableCharacter and item.is_selected:
		item.deselect_sprite()
		return
	var manager := screen.get_node_or_null("Charborder")
	if manager and "selected_characters" in manager and not manager.selected_characters.is_empty():
		manager.selected_characters.back().deselect_sprite()


func _hover(item: Object) -> void:
	_unhover()
	_hovered = item
	if item is SelectableCharacter:
		item._on_mouse_entered()      # same hover animation and sound as the mouse
	elif item.has_method("set_hovered"):
		item.set_hovered(true)


func _unhover() -> void:
	if _hovered and is_instance_valid(_hovered):
		if _hovered is SelectableCharacter:
			_hovered._on_mouse_exited()
		elif _hovered.has_method("set_hovered"):
			_hovered.set_hovered(false)
	_hovered = null


func _nudge(item: Object) -> void:
	# A little shake on START when nobody's been picked yet
	if item is Node2D:
		var n := item as Node2D
		var p := n.position
		var t := n.create_tween()
		for k in [12, -10, 7, -4, 0]:
			t.tween_property(n, "position", p + Vector2(k, 0), 0.04)


func _box(item: Object) -> Rect2:
	# The item's visible rectangle on screen, in global coordinates (accounts for
	# scale, sprite sheets and labels that are scaled up)
	if item is Control:
		var c := item as Control
		var xf := c.get_global_transform()
		var r := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
		r = r.expand(xf * c.size)
		return r.abs()
	if item is Sprite2D:
		var s := item as Sprite2D
		var lr := s.get_rect()                  # one frame, offset and centring included
		var xf := s.get_global_transform()
		var r := Rect2(xf * lr.position, Vector2.ZERO)
		r = r.expand(xf * lr.end)
		return r.abs()
	if item is Node2D:
		return Rect2((item as Node2D).global_position - Vector2(80, 60), Vector2(160, 120))
	return Rect2()


func _center(item: Object) -> Vector2:
	return _box(item).get_center()


func _extent(item: Object) -> Vector2:
	# Half-size of the bracket for this item
	return _box(item).size * 0.5 + Vector2(10, 8)
