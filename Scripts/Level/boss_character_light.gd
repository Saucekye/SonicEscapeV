extends Node2D
## Lights the characters while they're inside a boss arena:
##  - the whole sprite is dimmed and cooled, so the lights stand out
##  - a pale rim from above (the moon over the castle)
##  - a coloured rim on the other side, from low down, in the waterline's colour
##  - a glow on their bottom edges from the arena's glowing waterline, in its
##    colour: cyan before the fight, turning red with the arena when the boss's
##    health bar shows up (it reads the arena shader's floor_line colour)
##  - the waterline glow breathes slowly, and gets a little stronger and warmer
##    once the arena is red
## Leaving the arena puts each character's stage lighting back.
## Added by boss_arena.gd to every boss arena (Scenes/Effects/boss_character_light.tscn:
## edit the numbers there).

const CHARACTER_SHADER := preload("res://Shaders/character_light.gdshader")
const SAVED := ["tint", "rim_color", "rim_strength", "light_dir", "under_color", "under_strength", "rim2_color", "rim2_strength", "rim2_dir"]

@export_group("Before the fight (blue)")
@export var tint := Color(0.74, 0.78, 0.94)          ## multiplies the whole sprite
@export var rim_color := Color(0.82, 0.88, 1.0)      ## rim light from above
@export_range(0.0, 1.0) var rim_strength := 0.9
@export var light_from := Vector2(-0.5, -1.0)        ## where the top light comes FROM (x right, y down)
@export_range(0.0, 1.0) var under_strength := 0.85   ## waterline glow on the bottom edges
@export_range(0.0, 1.0) var side_strength := 0.7     ## waterline-coloured rim on the other side
@export var side_from := Vector2(1.0, 0.6)           ## where that side light comes FROM

@export_group("During the fight (red)")
@export var red_tint := Color(0.86, 0.72, 0.74)
@export var red_rim_color := Color(1.0, 0.82, 0.78)
@export_range(0.0, 1.0) var red_under_strength := 1.0

@export_group("Breathing")
@export_range(0.0, 0.5) var pulse_amount := 0.15     ## how much the waterline glow rises and falls
@export var pulse_speed := 1.6                       ## radians per second

## Set by boss_arena.gd
var arena: Control
var arena_material: ShaderMaterial
var _lit := {}   # character -> {"material": ShaderMaterial, "saved": Dictionary or null}
var _time := 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(arena) or arena_material == null:
		return
	_time += delta
	var area := arena.get_global_rect()
	var floor_line: Color = arena_material.get_shader_parameter("floor_line")
	if floor_line == null:
		floor_line = Color(0.47, 1.0, 0.92)
	# 0 = the blue arena, 1 = fully red (the floor line fades from cyan to red)
	var red := clampf((floor_line.r - 0.47) / (1.0 - 0.47), 0.0, 1.0)
	var pulse := 1.0 + sin(_time * pulse_speed) * pulse_amount
	for character in get_tree().get_nodes_in_group("all_characters"):
		if not is_instance_valid(character) or not character is Node2D:
			continue
		var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			continue
		var inside := area.has_point((character as Node2D).global_position)
		if inside:
			var m := _material_for(character, sprite)
			if m == null:
				continue
			m.set_shader_parameter("tint", tint.lerp(red_tint, red))
			m.set_shader_parameter("rim_color", rim_color.lerp(red_rim_color, red))
			m.set_shader_parameter("rim_strength", rim_strength)
			m.set_shader_parameter("light_dir", light_from)
			m.set_shader_parameter("under_color", floor_line)
			m.set_shader_parameter("under_strength", clampf(lerpf(under_strength, red_under_strength, red) * pulse, 0.0, 1.0))
			m.set_shader_parameter("rim2_color", floor_line)
			m.set_shader_parameter("rim2_strength", clampf(side_strength * pulse, 0.0, 1.0))
			m.set_shader_parameter("rim2_dir", side_from)
			m.set_shader_parameter("flip", -1.0 if sprite.flip_h else 1.0)
		elif _lit.has(character):
			_restore(character)
	for character in _lit.keys():
		if not is_instance_valid(character):
			_lit.erase(character)


## The character's lighting material: the stage's one (atmosphere.gd), or a new
## one if it has none. Never replaces a different material the character uses.
func _material_for(character: Node, sprite: Sprite2D) -> ShaderMaterial:
	if _lit.has(character):
		return _lit[character].material
	var m := sprite.material as ShaderMaterial
	var saved = null
	if m != null and m.shader == CHARACTER_SHADER:
		saved = {}
		for key in SAVED:
			saved[key] = m.get_shader_parameter(key)
	elif sprite.material == null:
		m = ShaderMaterial.new()
		m.shader = CHARACTER_SHADER
		sprite.material = m
	else:
		return null
	_lit[character] = {"material": m, "saved": saved}
	return m


func _restore(character: Node) -> void:
	var entry: Dictionary = _lit[character]
	_lit.erase(character)
	var m: ShaderMaterial = entry.material
	if entry.saved == null:
		# It had no material before
		var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
		if sprite and sprite.material == m:
			sprite.material = null
		return
	for key in entry.saved:
		m.set_shader_parameter(key, entry.saved[key])
	m.set_shader_parameter("under_strength", 0.0)
	m.set_shader_parameter("rim2_strength", 0.0)


func _exit_tree() -> void:
	for character in _lit.keys():
		if is_instance_valid(character):
			_restore(character)
