class_name RushTheme
## Menu style in the game's red, white and black, kept restrained to
## suit the analog-horror tone: flat translucent black bars with a thin edge, plain
## white text, and the selected option filled solid red with a white marker on its
## left, like an old broadcast / VHS menu. No slant, no drop shadows, no glow.
## Every colour and size below is easy to change.

const RED := Color("c4161f")        # selected option
const RED_DARK := Color("6e0a10")   # pressed
const BLACK := Color("0a0a0c")      # bars, backdrops, tracks
const GREY := Color("3a3a40")       # thin edges on unselected bars
const WHITE := Color("f2f2f2")      # text and the selection marker
const INK := Color("000000")        # text outline
const TEXT_SIZE := 22               # pause menu text size
const BAR_ALPHA := 0.72             # how see-through the unselected bars are

static var _cached: Theme
static var _cached_global: Theme


## Full style: pause menu and HUD controls.
static func build() -> Theme:
	if _cached:
		return _cached
	var t := build_global().duplicate(true)

	# ── Labels: plain white, thin outline for readability over the game ──
	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 3)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	# ── Panels: no frame, the dark backdrop does the work ──
	var panel := _flat(Color(0, 0, 0, 0))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	for type in ["Button", "OptionButton", "CheckButton", "Label", "PopupMenu"]:
		t.set_font_size("font_size", type, TEXT_SIZE)

	_cached = t
	return t


## Lighter style applied to the whole game (title, character select, results...):
## buttons, dropdowns, toggles and sliders only. Labels, panels and font sizes
## are left alone so existing screens keep their layout.
static func build_global() -> Theme:
	if _cached_global:
		return _cached_global
	var t := Theme.new()

	# ── Buttons ──
	t.set_stylebox("normal", "Button", _bar(Color(BLACK, BAR_ALPHA), GREY))
	t.set_stylebox("hover", "Button", _bar(Color(RED, 0.85), RED, true))
	t.set_stylebox("focus", "Button", _bar(RED, RED, true))
	t.set_stylebox("pressed", "Button", _bar(RED_DARK, RED_DARK, true))
	t.set_stylebox("disabled", "Button", _bar(Color(BLACK, 0.4), Color(GREY, 0.5)))
	_text_colors(t, "Button")
	t.set_constant("outline_size", "Button", 0)

	# ── Option / dropdown buttons ──
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	_text_colors(t, "OptionButton")
	t.set_constant("outline_size", "OptionButton", 0)

	# ── Dropdown list ──
	var list := _flat(Color(BLACK, 0.95))
	list.border_color = GREY
	list.set_border_width_all(1)
	list.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", list)
	t.set_stylebox("hover", "PopupMenu", _flat(RED))
	t.set_color("font_color", "PopupMenu", WHITE)
	t.set_color("font_hover_color", "PopupMenu", WHITE)
	t.set_constant("outline_size", "PopupMenu", 0)

	# ── Sliders: thin grey track, red fill ──
	var track := _flat(GREY)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := _flat(RED)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	# ── Focus on toggles and sliders: a thin red underline ──
	var focus_line := _flat(Color(0, 0, 0, 0))
	focus_line.border_color = RED
	focus_line.border_width_bottom = 2
	_text_colors(t, "CheckButton")
	# Toggles: no box behind the switch (they'd otherwise inherit the button bars)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckButton", _flat(Color(0, 0, 0, 0)))
	t.set_stylebox("focus", "CheckButton", focus_line)
	t.set_stylebox("focus", "HSlider", focus_line)

	_cached_global = t
	return t


static func _bar(bg: Color, edge: Color, selected := false) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(1)
	if selected:
		# White marker down the left edge of the selected option
		b.border_color = WHITE
		b.border_width_left = 4
		b.border_width_top = 0
		b.border_width_right = 0
		b.border_width_bottom = 0
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 5
	b.content_margin_bottom = 5
	b.anti_aliasing = false
	return b


static func _flat(bg: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.anti_aliasing = false
	return b


static func _text_colors(t: Theme, type: String) -> void:
	t.set_color("font_color", type, Color(WHITE, 0.82))
	t.set_color("font_hover_color", type, WHITE)
	t.set_color("font_focus_color", type, WHITE)
	t.set_color("font_pressed_color", type, WHITE)
	t.set_color("font_hover_pressed_color", type, WHITE)
	t.set_color("font_disabled_color", type, Color(WHITE, 0.35))
