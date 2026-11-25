extends Node
# Display and look settings

const SECTION := "display"
const SIZES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]
const MODES := ["Windowed", "Fullscreen", "Exclusive Fullscreen"]
const FPS := [0, 30, 60, 120, 144, 165, 240]   # 0 = no cap

var window_mode := 1                  # MODES
var window_size := Vector2i(1600, 900)
var vsync := true
var max_fps := 0
var brightness := 1.0                 # 1 = as made; higher lifts the dark parts
var screen_shake := 1.0               # 0 = none
var stick_look := 1.0                 # controller look speed
var invert_look := false
var fov := 80.0                       # Salvage's first-person view, side to side
var salvage_ps1 := true              # Salvage's PS1 filter
var move_prompts := true              # the moves you can do right now, down the right side

var _bright_layer: CanvasLayer
var _bright: ColorRect

const BRIGHT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(pow(max(c, vec3(0.0)), vec3(1.0 / brightness)), 1.0);
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_saved()
	apply()


# Desktop only: window size and mode mean nothing in a browser or on a phone
static func has_window() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web")


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Test.SETTINGS_PATH) != OK:
		return
	window_mode = clampi(int(cfg.get_value(SECTION, "window_mode", window_mode)), 0, MODES.size() - 1)
	window_size = cfg.get_value(SECTION, "window_size", window_size)
	vsync = bool(cfg.get_value(SECTION, "vsync", vsync))
	max_fps = int(cfg.get_value(SECTION, "max_fps", max_fps))
	brightness = clampf(float(cfg.get_value(SECTION, "brightness", brightness)), 0.5, 2.0)
	screen_shake = clampf(float(cfg.get_value(SECTION, "screen_shake", screen_shake)), 0.0, 1.5)
	stick_look = clampf(float(cfg.get_value(SECTION, "stick_look", stick_look)), 0.2, 3.0)
	invert_look = bool(cfg.get_value(SECTION, "invert_look", invert_look))
	fov = clampf(float(cfg.get_value(SECTION, "fov", fov)), 60.0, 110.0)
	move_prompts = bool(cfg.get_value(SECTION, "move_prompts", move_prompts))
	salvage_ps1 = bool(cfg.get_value(SECTION, "salvage_ps1", salvage_ps1))


func save(key: String, value: Variant) -> void:
	set(key, value)
	var cfg := ConfigFile.new()
	cfg.load(Test.SETTINGS_PATH)
	cfg.set_value(SECTION, key, value)
	cfg.save(Test.SETTINGS_PATH)
	apply()


func apply() -> void:
	if has_window():
		_apply_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	_apply_brightness()


func _apply_window() -> void:
	var want: int = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][window_mode]
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	if want == DisplayServer.WINDOW_MODE_WINDOWED:
		var screen := DisplayServer.window_get_current_screen()
		var room := DisplayServer.screen_get_usable_rect(screen)
		var s := Vector2i(mini(window_size.x, room.size.x), mini(window_size.y, room.size.y))
		if DisplayServer.window_get_size() != s:
			DisplayServer.window_set_size(s)
			DisplayServer.window_set_position(room.position + (room.size - s) / 2)


# Window sizes that fit this screen
func sizes() -> Array:
	var room := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array = []
	for s in SIZES:
		if s.x <= room.x and s.y <= room.y:
			out.append(s)
	if out.is_empty():
		out.append(SIZES[0])
	if not window_size in out:
		out.append(window_size)
	return out


# Brightness: a layer over everything that lifts
func _apply_brightness() -> void:
	var on := absf(brightness - 1.0) > 0.01
	if on and _bright_layer == null:
		_bright_layer = CanvasLayer.new()
		_bright_layer.layer = 127
		add_child(_bright_layer)
		_bright = ColorRect.new()
		_bright.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bright.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sh := Shader.new()
		sh.code = BRIGHT_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_bright.material = mat
		_bright_layer.add_child(_bright)
	if _bright_layer:
		_bright_layer.visible = on
		(_bright.material as ShaderMaterial).set_shader_parameter("brightness", brightness)
