@tool
class_name ReflectiveWater
extends ColorRect
## Drop-in reflective water.
## Add it to any level chunk (Add Node > ReflectiveWater), then drag its size
## to cover the water area. The top edge is the waterline: everything above it
## on screen is mirrored into the water with ripples.
## It's purely visual; add your own Area2D if the water should affect movement.

const WATER_SHADER := preload("res://Shaders/reflective_water.gdshader")

@export var water_color := Color(0.1, 0.35, 0.75, 0.92):
	set(v): water_color = v; _push()
@export var reflection_tint := Color(0.75, 0.9, 1.0):
	set(v): reflection_tint = v; _push()
@export_range(0.0, 1.0) var reflectivity := 0.55:
	set(v): reflectivity = v; _push()
@export var ripple_strength := 0.004:
	set(v): ripple_strength = v; _push()
@export var surface_color := Color(0.85, 0.97, 1.0):
	set(v): surface_color = v; _push()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material == null or not (material is ShaderMaterial):
		var m := ShaderMaterial.new()
		m.shader = WATER_SHADER
		material = m
	_push()


func _push() -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("water_color", water_color)
	m.set_shader_parameter("reflection_tint", reflection_tint)
	m.set_shader_parameter("reflectivity", reflectivity)
	m.set_shader_parameter("ripple_strength", ripple_strength)
	m.set_shader_parameter("surface_color", surface_color)


func _process(_delta: float) -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	# Where the waterline sits on screen this frame (0 = top, 1 = bottom)
	var top := get_global_transform_with_canvas() * Vector2.ZERO
	var view_h := get_viewport_rect().size.y
	if view_h > 0.0:
		m.set_shader_parameter("surface_uv_y", top.y / view_h)
