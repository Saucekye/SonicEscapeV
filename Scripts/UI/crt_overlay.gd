extends CanvasLayer
## The analog CRT look.
##  - FULL preset (curved tube, strong scanlines, VHS tracking band, glitch bursts)
##    shows on the pause menu only.
##  - SUBTLE preset during gameplay and other screens: light scanlines, grain and
##    fringing, a flat screen, no tracking band and no glitch bursts, so it never
##    gets in the way of play.
## It blends smoothly between the two when you pause / unpause.
## Created once by the Test autoload, so it stays on across scene changes.
## Toggle with Pause > Settings > CRT (Test.crt_enabled).

const SHADER := preload("res://Shaders/analog_crt.gdshader")

const FULL := {
	"curvature": 0.025, "corner_round": 0.02, "scanline_strength": 0.22, "mask_strength": 0.07,
	"aberration_px": 1.2, "grain": 0.045, "flicker": 0.012, "vignette": 0.22, "brightness": 1.12,
	"tracking_strength": 0.35, "desaturate": 0.08,
}
const SUBTLE := {
	"curvature": 0.0, "corner_round": 0.0, "scanline_strength": 0.07, "mask_strength": 0.025,
	"aberration_px": 0.6, "grain": 0.018, "flicker": 0.003, "vignette": 0.1, "brightness": 1.035,
	"tracking_strength": 0.0, "desaturate": 0.03,
}
const BLEND_SPEED := 4.0   # how fast it switches between the two looks

## Seconds between glitch bursts on the pause menu (random in this range); 0 and 0 = none
@export var glitch_every_min := 9.0
@export var glitch_every_max := 22.0

var material: ShaderMaterial
var rect: ColorRect
var _mix := 0.0            # 0 = subtle, 1 = full
var _next_glitch := 4.0
var _glitch_left := 0.0


func _ready() -> void:
	layer = 128                         # above the HUD (10) and the pause menu (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	add_child(rect)
	_apply(0.0)


func _process(delta: float) -> void:
	visible = Test.crt_enabled
	if not visible:
		return
	var target := 1.0 if get_tree().paused else 0.0
	_mix = move_toward(_mix, target, delta * BLEND_SPEED)
	_apply(_mix)
	_update_glitch(delta)
	_update_skips()


## Sprites drawn without the CRT effect (at most two): the HUD's player icon.
## Called by Icon.gd. They get the full effect while paused, like everything else.
var _skips: Array = []

func exclude(sprites: Array) -> void:
	_skips = sprites.slice(0, 2)


func _update_skips() -> void:
	var on := _mix < 0.5
	material.set_shader_parameter("skip_on", on)
	if not on:
		return
	var vp := get_viewport()
	var screen := Vector2(vp.size)
	for i in 2:
		var key := "skip%d" % i
		var s = _skips[i] if i < _skips.size() else null
		var ok: bool = s != null and is_instance_valid(s) and s is Sprite2D and s.is_visible_in_tree() and s.texture != null \
				and s.modulate.a * s.self_modulate.a > 0.05 and screen.x > 0.0
		material.set_shader_parameter(key + "_on", ok)
		if not ok:
			continue
		var sp := s as Sprite2D
		var r := sp.get_rect()
		# Frame (0..1) -> sprite local -> canvas -> window pixels -> screen UV
		var frame_to_local := Transform2D(Vector2(r.size.x, 0), Vector2(0, r.size.y), r.position)
		if sp.flip_h:
			frame_to_local = Transform2D(Vector2(-r.size.x, 0), Vector2(0, r.size.y), r.position + Vector2(r.size.x, 0))
		var to_uv := Transform2D(Vector2(1.0 / screen.x, 0), Vector2(0, 1.0 / screen.y), Vector2.ZERO)
		var xf := (to_uv * vp.get_final_transform() * sp.get_global_transform_with_canvas() * frame_to_local).affine_inverse()
		material.set_shader_parameter(key + "_x", xf.x)
		material.set_shader_parameter(key + "_y", xf.y)
		material.set_shader_parameter(key + "_o", xf.origin)
		var tex_size := sp.texture.get_size()
		var region := Rect2(Vector2.ZERO, tex_size)
		if sp.region_enabled:
			region = sp.region_rect
		var fw := region.size.x / sp.hframes
		var fh := region.size.y / sp.vframes
		var fpos := region.position + Vector2((sp.frame % sp.hframes) * fw, (sp.frame / sp.hframes) * fh)
		material.set_shader_parameter(key + "_region", Vector4(fpos.x / tex_size.x, fpos.y / tex_size.y, fw / tex_size.x, fh / tex_size.y))
		material.set_shader_parameter("skip_tex%d" % i, sp.texture)


func _apply(t: float) -> void:
	for key in FULL:
		material.set_shader_parameter(key, lerp(float(SUBTLE[key]), float(FULL[key]), t))


func _update_glitch(delta: float) -> void:
	# Automatic bursts only on the pause menu; burst() still works any time
	if _mix > 0.9 and glitch_every_max > 0.0:
		_next_glitch -= delta
		if _next_glitch <= 0.0:
			_next_glitch = randf_range(glitch_every_min, glitch_every_max)
			_glitch_left = randf_range(0.12, 0.3)
	if _glitch_left > 0.0:
		_glitch_left -= delta
		# Stuttery strength, like a bad tape
		material.set_shader_parameter("glitch", randf_range(0.4, 1.0) if randf() < 0.7 else 0.0)
	else:
		material.set_shader_parameter("glitch", 0.0)


## Call for a manual glitch at any time (e.g. when the player gets hurt)
func burst(seconds := 0.25) -> void:
	_glitch_left = seconds
