@tool
extends Node2D
# A training stage sign

## Board title
@export var title := "RUN"
## Board text
@export_multiline var text := ""
## The move that marks this sign CLEAR
@export var move := "run"
## The character needs one of these to do the move, or the sign says to switch
@export var needs: PackedStringArray = []

const SIGN_WIDTH := 430.0          # board text width
const SIGN_HEIGHT := 120.0         # post height, so boards sit above heads and ring lines
const RED := Color("c4161f")
const WHITE := Color("f2f2f2")

var panel: PanelContainer
var box: StyleBoxFlat
var title_label: Label
var note: Label


func _ready() -> void:
	z_index = 1
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_make_board()


# In the editor
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-3, -SIGN_HEIGHT, 6, SIGN_HEIGHT), Color(0.1, 0.1, 0.12))
	draw_rect(Rect2(-SIGN_WIDTH * 0.5 - 12, -SIGN_HEIGHT - 110, SIGN_WIDTH + 24, 110), RED, false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-SIGN_WIDTH * 0.5, -SIGN_HEIGHT - 80), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)


func _make_board() -> void:
	var post := ColorRect.new()
	post.color = Color(0.1, 0.1, 0.12)
	post.size = Vector2(6, SIGN_HEIGHT)
	post.position = Vector2(-3, -SIGN_HEIGHT)
	add_child(post)

	# Board: dark panel, red bar on the left, title and text
	panel = PanelContainer.new()
	box = StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.04, 0.05, 0.86)
	box.border_color = RED
	box.border_width_left = 5
	box.set_content_margin_all(8)
	box.content_margin_left = 12
	box.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", box)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", WHITE)
	v.add_child(title_label)
	var body := Label.new()
	body.text = fill_keys(text)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(WHITE, 0.85))
	body.add_theme_constant_override("line_spacing", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = SIGN_WIDTH
	v.add_child(body)
	note = Label.new()
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	note.visible = false
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = SIGN_WIDTH
	v.add_child(note)
	add_child(panel)
	# Sit the board on top of the post
	panel.reset_size.call_deferred()
	(func():
		panel.position = Vector2(-panel.size.x * 0.5, -SIGN_HEIGHT - panel.size.y)
	).call_deferred()


func mark_clear() -> void:
	if title_label == null:
		return
	title_label.text = title + "   CLEAR"
	title_label.add_theme_color_override("font_color", RED)
	box.border_color = WHITE


static func fill_keys(t: String) -> String:
	for action in [["jump", "ui_accept"], ["left", "ui_left"], ["right", "ui_right"], ["up", "ui_up"],
			["down", "ui_down"], ["airspin", "airspin"], ["trick", "trick"], ["switch", "switch"]]:
		t = t.replace("{" + action[0] + "}", key_name(action[1]))
	return t


static func key_name(action: String) -> String:
	var keys := []
	var pad := ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and keys.size() < 2:
			var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			if code in [KEY_ENTER, KEY_KP_ENTER]:
				continue   # menu keys; show the gameplay keys instead
			var k := OS.get_keycode_string(code)
			if not keys.has(k):
				keys.append(k)
		elif ev is InputEventJoypadButton and pad == "":
			pad = {0: "A", 1: "B", 2: "X", 3: "Y", 9: "LB", 10: "RB", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}.get(ev.button_index, "")
	var name := " / ".join(keys) if not keys.is_empty() else "?"
	if pad != "" and not Input.get_connected_joypads().is_empty():
		name = pad
	return "[" + name + "]"
