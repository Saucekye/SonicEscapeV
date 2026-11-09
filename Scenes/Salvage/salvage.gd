extends Node3D
## SALVAGE: a first-person mini game reached from the rest tree (tree.gd).
## Lethal Company-style, with a PS1 / Mouthwashing look (Shaders/ps1_*.gdshader):
##   1. You start in an elevator. After a moment the doors open.
##   2. A hole in the floor of the landing drops you into the facility below.
##   3. A maze of dark corridors on a checkered floor. Items lie around: look at
##      a piece and press interact to salvage it for rings.
##   4. Find the exit elevator (red EXIT sign), get in and press its ESCAPE
##      button: the doors take 5 seconds to close, and whoever is inside when they
##      shut escapes with their items. Anyone outside is left behind and loses it.
## You're short (eye level about 1 m), the same height as the characters.
## Your team shows up old-school DOOM style, as flat sprites (salvage_teammate.gd):
##   - single player: your 2nd and 3rd picks follow you
##   - local co-op: split screen, 1P top / 2P bottom, each with their own view,
##     controls and rings; your 3rd pick follows 1P. Either of you can press ESCAPE.
##   - online: 1P (the host) starts it for everyone; same facility for all, the
##     others shown where they are, an item someone salvages disappears for everyone,
##     and when anyone presses ESCAPE the elevator leaves for everyone.
## No enemies yet. The floor plan is new each visit.
## Editing in Godot (no code needed):
##   - salvage.tscn: select the Salvage node; its Inspector has the map size (small
##     on early floors, growing to Max Maze Size by Full Size Floor), lamps,
##     item and exit settings (groups: Layout, Lamps, Items, Exit, Look)
##   - start_area.tscn: the elevator you start in, the landing, the hole and the
##     "Have Fun :)" sign. exit_elevator.tscn: the way out (doors face -Z, the wall
##     it backs onto is at +Z). Move, add or delete pieces freely. Markers in the
##     "salvage_light" group are lights; Label3Ds with "paint" metadata are lit text;
##     nodes in "elevator_door" slide (start: to their open_x, exit: to closed_x)
##   - Materials/*.tres: every surface's colours and pattern (shared by everything)
##   - Items/*.tres: each kind of item (name, cost, value, picture or placeholder shape)
##   - Chunks/*.tscn: the corridor chunks the facility is built from, like the 2D
##     levels' chunks (rules in Chunks/salvage_chunk.gd); list variants in the
##     Salvage node's Chunks
##   - salvage_player.tscn / salvage_teammate.tscn / salvage_transition.tscn:
##     movement, the DOOM-style sprites, and the way in
## Salvaged items are added to Test.salvage_items / Test.salvage_value.

const WORLD_SHADER := preload("res://Shaders/ps1_world.gdshader")
const SCREEN_SHADER := preload("res://Shaders/ps1_screen.gdshader")
const GLOW_SHADER := preload("res://Shaders/ps1_glow.gdshader")
const PLAYER := preload("res://Scenes/Salvage/salvage_player.tscn")
const TEAMMATE := preload("res://Scenes/Salvage/salvage_teammate.tscn")
const START_AREA := preload("res://Scenes/Salvage/start_area.tscn")
const EXIT_ELEVATOR := preload("res://Scenes/Salvage/exit_elevator.tscn")
const MIRROR := preload("res://Scenes/Salvage/salvage_mirror.gd")
const MATERIALS_DIR := "res://Scenes/Salvage/Materials/"
const RETURN_SCENE := "res://Scenes/Level/test3.tscn"

const UP_Y := 40.0                    # floor of the enormous room above (start_area.tscn is built around it); the shaft drops from here
const HOLE := 1.1                     # half-size of the hole you drop through (also in start_area.tscn)
const INTRO_TEXT := "SALVAGE\nFind the exit. Salvage items with rings."
const MAX_LAMPS := 48                 # what the shader can light (lamps[] in ps1_world.gdshader)
enum { LAMP_DEAD, LAMP_STUTTER, LAMP_ON }
const SEND_RATE := 20.0               # online position updates per second
const TAG_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.18, 0.18), Color(0.25, 0.9, 0.35), Color(1.0, 0.85, 0.15)]

@export_group("Layout")
@export var max_maze_size := Vector2i(20, 20)   ## corridor cells across and deep at its biggest (floor Full Size Floor and up)
@export var min_maze_size := Vector2i(7, 7)     ## its size on the early floors (up to Small Until Floor)
@export var small_until_floor := 10             ## floors up to this get the smallest facility
@export var full_size_floor := 50               ## by this floor it's grown to its biggest
@export var cell_size := 4.0                ## metres per corridor cell
@export var wall_height := 3.2              ## corridor height (m)
@export_range(0.0, 1.0) var extra_openings := 0.18   ## share of extra walls knocked out, so the maze has loops
@export_range(1, 5) var floor_levels := 3   ## how many floor heights the corridors are on
@export var level_step := 1.6               ## metres between floor heights (each staircase climbs one)
@export_range(0.0, 1.0) var stairs := 0.3   ## share of straight corridors that become staircases
@export_group("Lamps")
@export_range(0, 300) var lamp_count := 110   ## ceiling lamps at the biggest size (fewer on smaller maps; the 48 nearest you light the walls)
@export_range(0.0, 1.0) var dead_lamps := 0.3       ## share of them that are dead
@export_range(0.0, 1.0) var stuttering_lamps := 0.3 ## share that cut out in bursts (the rest stay on)
@export_group("Items")
@export var item_count := 18               ## items at the biggest size (fewer on smaller maps; fewer = more spread out)
@export var item_kinds: Array[SalvageItem] = []   ## which kinds can turn up (files in Items/)
@export_group("Chunks")
## The corridor chunks the facility is built from (Chunks/*.tscn, see
## salvage_chunk.gd). Each spot in the maze gets one whose open sides fit,
## turned to match; add your own variants here.
@export var chunks: Array[PackedScene] = [
	preload("res://Scenes/Salvage/Chunks/dead_end.tscn"),
	preload("res://Scenes/Salvage/Chunks/straight.tscn"),
	preload("res://Scenes/Salvage/Chunks/corner.tscn"),
	preload("res://Scenes/Salvage/Chunks/t_junction.tscn"),
	preload("res://Scenes/Salvage/Chunks/crossroads.tscn"),
	preload("res://Scenes/Salvage/Chunks/stairs.tscn"),
]
@export_group("Rings")
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var ring_sound := "res://Sounds/Obstacles/Rings/ringsfx.MP3"
@export_range(-40.0, 6.0) var ring_volume_db := -18.0   ## the ring pickup sound (quiet)
@export var ring_trail_every := 3           ## a line of rings every this many corridors on the way to the exit (0 = none)
@export var decoy_ring_groups := 6          ## lines of rings off the way to the exit, so they don't always point the right way
@export var ring_texture: Texture2D = preload("res://Sprites/Obstacles/Rings/ringsheet-sheet.png")
@export_group("Exit")
@export var depart_time := 5.0              ## seconds from pressing ESCAPE to the elevator leaving
@export var doors_open_after := 2.6         ## seconds before the start elevator's doors open
@export var intro_text_time := 3.0          ## seconds the "SALVAGE / Find the exit" text stays after the doors open
@export_group("Look")
@export var render_size := Vector2i(400, 225)   ## size each view is drawn at before it's scaled up

var rng := RandomNumberGenerator.new()
var maze_size := Vector2i(20, 20)   # this visit's size, from the floor you're on (_size_for_floor)
var size_scale := 1.0               # this visit's area / the biggest area: lamps, items, doors and rings scale with it
var item_list: Array = []       # [name, cost, value, shape, colour, texture, height] for each kind, from item_kinds
var players: Array = []          # local players (salvage_player.gd): 1, or 2 in co-op
var player: CharacterBody3D      # 1P (used by the follower sprites)
var fade: ColorRect
var mats := {}
var lamps: Array[Vector3] = []
var lamp_states := {}      # lamp index -> LAMP_DEAD / LAMP_STUTTER / LAMP_ON (maze lamps)
var lamp_mats := {}        # lamp index -> [its fixture's material, its halo's material]
var lamp_power := PackedFloat32Array()   # every lamp's brightness this frame
var sign_labels: Array = []   # [Label3D, its colour]: painted words, lit like everything else
var doors: Array[Node3D] = []
var exit_cell := Vector2i.ZERO
var exit_car: Node3D              # the exit elevator; its local +z points into the wall
var exit_doors: Array[Node3D] = []
var departing := false            # ESCAPE was pressed: the doors are closing
var item_nodes: Array[Node3D] = []
var ring_sfx: AudioStreamPlayer
var ring_nodes: Array[Sprite3D] = []  # rings to collect, in the same order for everyone online
var leaving := false
var time := 0.0
var followers: Array = []        # AI teammates following 1P
var partner_sprites := {}        # local player index -> its sprite, seen by the other co-op player
var remote := {}                 # online: peer id -> {"sprite", "target", "escaped"}
var _send_timer := 0.0
var level := {}     # Vector2i -> the cell's floor height (a staircase's lower end)
var stair := {}     # Vector2i -> direction its stairs climb toward (staircase cells only)
var tree_links := {}   # Vector2i -> the cells the maze's paths join it to (no loops)
var maze_body: StaticBody3D   # collision for the maze pieces made in code (the hole's ceiling)
var lamp_spots: Array[Vector3] = []   # where ceiling lamps can hang (the chunks' LampSpot markers)
var _batches := {}  # "material|chunk" -> SurfaceTool: maze pieces merged into few meshes
var _batch_mats := {}   # the same keys -> the material to draw that mesh with
var walls_h := {}   # Vector2i -> true: wall on the +x side of the cell
var walls_v := {}   # Vector2i -> true: wall on the +z side of the cell


func _ready() -> void:
	# Online, everyone builds the same facility from the host's seed
	if Net.online:
		rng.seed = Net.salvage_seed
	else:
		rng.randomize()
	Pause.current_scene = "Salvage"   # the pause menu is for the 2D levels
	_size_for_floor()
	var pads := _setup_input()
	for k in item_kinds:
		if k:
			item_list.append([k.display_name, k.cost, k.value, k.shape, k.color, k.texture, k.height])
	if item_list.is_empty():
		item_list.append(["Item", 5, 30, "square", Color(0.6, 0.6, 0.6), null, 0.5])
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	env.environment = e
	add_child(env)
	_build_materials()
	_build_elevator_level()
	_build_maze()
	_place_lamps()
	_place_items()
	_place_exit()
	_place_rings()
	_build_players(pads)
	_build_others()
	for m in get_tree().get_nodes_in_group("salvage_mirror"):
		m.setup(self, players)   # (salvage_mirror.gd: the mirror in the start elevator)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Net.online:
		Net.lobby_message.connect(_on_net)
	# Fade in, then the doors open
	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, 1.2)
	for p in players:
		p.show_message(INTRO_TEXT, 600.0)   # (until a while after the doors open)
	get_tree().create_timer(doors_open_after).timeout.connect(_open_doors)


## Small on the early floors, growing steadily to its biggest by full_size_floor.
## The counts of lamps, items and decoy rings (set for the biggest map)
## shrink with the area, so a small facility isn't crammed or empty.
func _size_for_floor() -> void:
	var f: int = Test.level
	var t := clampf(float(f - small_until_floor) / maxf(full_size_floor - small_until_floor, 1), 0.0, 1.0)
	maze_size = Vector2i(roundi(lerpf(min_maze_size.x, max_maze_size.x, t)), roundi(lerpf(min_maze_size.y, max_maze_size.y, t)))
	maze_size = maze_size.clamp(Vector2i(3, 3), Vector2i(64, 64))
	size_scale = float(maze_size.x * maze_size.y) / maxf(max_maze_size.x * max_maze_size.y, 1)


func _scaled(full: int, least: int) -> int:
	return maxi(roundi(full * size_scale), mini(least, full))


# ── Input ────────────────────────────────────────────────────────────────────
## 1P: keyboard + mouse (+ the first controller); 2P in co-op: the other controller.
## Returns [1P pad, 2P pad], or [pad, -1] when there's no co-op.
func _setup_input() -> Array:
	var coop := Test.coop_enabled and not Net.online and Test.charactertwo != "" and not Test.mobile
	var pads: Array = Input.get_connected_joypads()
	if not Test.coop_test_pads.is_empty():
		pads = Test.coop_test_pads
	var p1_pad: int = pads[0] if pads.size() >= 1 else -1
	var p2_pad := -1
	if coop:
		if pads.size() >= 2:
			p2_pad = pads[1]
		elif pads.size() == 1:
			p1_pad = -1          # one controller: 2P gets it, 1P plays on keyboard
			p2_pad = pads[0]
		else:
			coop = false         # no controller for 2P
	var keys := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT], "interact": [KEY_E], "sprint": [KEY_SHIFT], "jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C],
	}
	# Controller: sprint is the left trigger (below); crouch is the right bumper or R3
	var buttons := {"interact": [JOY_BUTTON_X], "jump": [JOY_BUTTON_A],
		"crouch": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_RIGHT_STICK]}
	var triggers := {"sprint": JOY_AXIS_TRIGGER_LEFT}
	for prefix in ["sv_", "sv2_"]:
		for a in keys:
			var action: String = prefix + a
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action)
	for a in keys:
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("sv_" + a, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("sv_interact", click)
	for a in buttons:
		for b in buttons[a]:
			if p1_pad >= 0:
				var j1 := InputEventJoypadButton.new()
				j1.button_index = b
				j1.device = p1_pad
				InputMap.action_add_event("sv_" + a, j1)
			if p2_pad >= 0:
				var j2 := InputEventJoypadButton.new()
				j2.button_index = b
				j2.device = p2_pad
				InputMap.action_add_event("sv2_" + a, j2)
	for a in triggers:
		for pair in [["sv_", p1_pad], ["sv2_", p2_pad]]:
			if int(pair[1]) >= 0:
				var t := InputEventJoypadMotion.new()
				t.axis = triggers[a]
				t.axis_value = 1.0
				t.device = int(pair[1])
				InputMap.action_add_event(pair[0] + a, t)
				InputMap.action_set_deadzone(pair[0] + a, 0.3)
	return [p1_pad, p2_pad if coop else -1]


## Mouse look is read before the screen's controls see the mouse, so nothing on
## screen (like co-op's dividing line, right where the captured mouse sits) can
## swallow it. The mouse always belongs to 1P, in co-op too.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not players.is_empty() and not players[0].escaped:
			players[0].look_mouse(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Esc frees the mouse; click to grab it again
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## A surface material: the one saved in Materials/<key>.tres (edit it there), or a
## default made here if that file is missing
func _mat(key: String, pattern: int, a: Color, b := Color.BLACK, tile := 1.0) -> ShaderMaterial:
	var path := MATERIALS_DIR + key + ".tres"
	if ResourceLoader.exists(path):
		mats[key] = load(path)
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("level_height", 3.6)
	# A touch of PS1 texture warp on the elevator; none on the checkered floors, walls and ceilings
	m.set_shader_parameter("affine_amount", 0.0 if pattern in [0, 1, 2, 6] else 0.3)
	mats[key] = m
	return m


func _build_materials() -> void:
	_mat("floor", 0, Color(0.72, 0.71, 0.74), Color(0.015, 0.015, 0.02), 1.4)
	_mat("wall", 1, Color(0.62, 0.61, 0.64), Color(0.015, 0.015, 0.02), 1.4)
	_mat("ceiling", 2, Color(0.5, 0.49, 0.52), Color(0.012, 0.012, 0.016), 1.4)
	_mat("metal", 3, Color(0.26, 0.27, 0.28))
	_mat("door", 3, Color(0.26, 0.2, 0.36))
	_mat("hazard", 6, Color(0.85, 0.7, 0.1), Color(0.05, 0.05, 0.05))
	_mat("lamp", 5, Color(1.0, 0.92, 0.75))
	_mat("exit", 5, Color(0.62, 0.05, 0.04))
	_mat("red", 5, Color(1.0, 0.15, 0.1))
	# The elevator: purple walls with magenta bands, like the reference picture
	_mat("elev_wall", 4, Color(0.3, 0.2, 0.46))
	_mat("elev_band", 4, Color(0.62, 0.14, 0.52))
	_mat("elev_rail", 4, Color(0.07, 0.04, 0.11))
	_mat("elev_floor", 4, Color(0.2, 0.12, 0.34))
	_mat("elev_lamp", 5, Color(1.0, 0.45, 0.47))
	_mat("elev_panel", 4, Color(0.62, 0.63, 0.72))
	_mat("elev_screen", 5, Color(0.72, 0.76, 0.82))
	_mat("elev_button", 4, Color(0.42, 0.5, 0.78))
	_mat("board", 4, Color(0.34, 0.27, 0.19))
	_mat("paint", 4, Color(0.7, 0.06, 0.04))
	_mat("stairs", 3, Color(0.62, 0.07, 0.05))
	_mat("door_frame", 3, Color(0.17, 0.18, 0.2))
	# The grime band along the bottom of the walls repeats every floor height
	mats["wall"].set_shader_parameter("level_height", level_step)


# ── Building blocks ──────────────────────────────────────────────────────────
## A box from min corner to max corner, with collision unless solid is false
func _box(a: Vector3, b: Vector3, mat_key: String, solid := true, parent: Node3D = self) -> Node3D:
	var size := (b - a).abs()
	var center := (a + b) * 0.5
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	# Extra subdivisions so the vertex wobble and warping read on big faces, PS1 style
	bm.subdivide_width = int(clamp(size.x / 2.0, 0, 8))
	bm.subdivide_depth = int(clamp(size.z / 2.0, 0, 8))
	bm.subdivide_height = int(clamp(size.y / 2.0, 0, 4))
	mesh.mesh = bm
	mesh.material_override = mats[mat_key]
	if not solid:
		mesh.position = center
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


## A soft glowing halo around a light (ps1_glow.gdshader)
func _halo(at: Vector3, size: float, color: Color, strength := 0.55) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("glow_color", color)
	m.set_shader_parameter("strength", strength)
	mats["halo_%d" % mats.size()] = m   # (so it flickers with the lamps)
	q.material_override = m
	q.position = at
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


## A cell's centre, at its floor (halfway up, for a staircase)
func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * cell_size, _floor_y(c) + (level_step * 0.5 if stair.has(c) else 0.0), c.y * cell_size)


func _floor_y(c: Vector2i) -> float:
	return level.get(c, 0) * level_step


func _ceil_y(c: Vector2i) -> float:
	return (level.get(c, 0) + (1 if stair.has(c) else 0)) * level_step + wall_height


## The floor height where a cell meets its neighbour in direction d
func _side_level(c: Vector2i, d: Vector2i) -> int:
	var l: int = level.get(c, 0)
	if stair.has(c) and stair[c] == d:
		return l + 1
	return l


# ── The elevator and the landing with the hole (start_area.tscn) ─────────────
func _build_elevator_level() -> void:
	var area := START_AREA.instantiate()
	add_child(area)
	_register_props(area)
	for d in area.find_children("*", "", true, false):
		if d.is_in_group("elevator_door"):
			doors.append(d)


## Pick up what a placed scene brings: its lights (Marker3Ds in "salvage_light")
## and its painted words (Label3Ds with "paint" metadata, lit like the walls)
func _register_props(root: Node) -> void:
	for n in root.find_children("*", "", true, false):
		if n is Marker3D and n.is_in_group("salvage_light"):
			lamps.append(n.global_position)
		elif n is Label3D and n.has_meta("paint"):
			sign_labels.append([n, n.get_meta("paint")])


func _open_doors() -> void:
	for d in doors:
		var t := create_tween()
		t.tween_property(d, "position:x", d.get_meta("open_x"), 1.4).set_trans(Tween.TRANS_SINE)
	# Once they're open (1.4 s) and you've had a moment, the intro text goes
	await get_tree().create_timer(1.4 + intro_text_time).timeout
	for p in players:
		p.hide_message(INTRO_TEXT)


# ── The maze ─────────────────────────────────────────────────────────────────
func _build_maze() -> void:
	# Recursive backtracker; every wall starts up
	for x in maze_size.x:
		for z in maze_size.y:
			walls_h[Vector2i(x, z)] = true
			walls_v[Vector2i(x, z)] = true
			tree_links[Vector2i(x, z)] = []
	var seen := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options := []
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if n.x >= 0 and n.y >= 0 and n.x < maze_size.x and n.y < maze_size.y and not seen.has(n):
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_open(c, d)
		tree_links[c].append(c + d)
		tree_links[c + d].append(c)
		seen[c + d] = true
		stack.append(c + d)
	# Knock out a few more walls so there are loops, like the facility halls
	for x in maze_size.x - 1:
		for z in maze_size.y:
			if rng.randf() < extra_openings:
				walls_h[Vector2i(x, z)] = false
	for x in maze_size.x:
		for z in maze_size.y - 1:
			if rng.randf() < extra_openings:
				walls_v[Vector2i(x, z)] = false
	_assign_levels()
	_build_from_chunks()


## Floor heights: walk the maze's paths out from the landing; some straight
## stretches become staircases that go up or down a level. Loops that would join
## two different heights (or open onto a staircase's side) are walled up again.
func _assign_levels() -> void:
	level[Vector2i.ZERO] = 0
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var top := floor_levels - 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in tree_links[c]:
			if level.has(n):
				continue
			var d: Vector2i = n - c
			var e := _side_level(c, d)
			var links: Array = tree_links[n]
			var straight: bool = links.size() == 2 and links.has(n + d)
			var near_start: bool = maxi(absi(n.x), absi(n.y)) <= 1
			if top > 0 and straight and not near_start and rng.randf() < stairs:
				var up := e < top and (e == 0 or rng.randf() < 0.5)
				if up:
					level[n] = e
					stair[n] = d
				else:
					level[n] = e - 1
					stair[n] = -d
			else:
				level[n] = e
			queue.append(n)
	# Wall up openings that don't line up
	for c in level:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if not level.has(n) or _wall_between(c, n):
				continue
			var bad := _side_level(c, d) != _side_level(n, -d)
			bad = bad or (stair.has(c) and stair[c].x * d.x + stair[c].y * d.y == 0)   # its side
			bad = bad or (stair.has(n) and stair[n].x * d.x + stair[n].y * d.y == 0)
			if bad:
				if d.x == 1: walls_h[c] = true
				else: walls_v[c] = true


func _wall_between(c: Vector2i, n: Vector2i) -> bool:
	var d := n - c
	if d == Vector2i(1, 0): return walls_h.get(c, true)
	if d == Vector2i(-1, 0): return walls_h.get(n, true)
	if d == Vector2i(0, 1): return walls_v.get(c, true)
	return walls_v.get(n, true)


## The facility from its chunks: every maze spot gets a chunk whose open sides
## match (a staircase spot gets a staircase chunk), turned to fit and set at the
## spot's floor height. Their meshes are merged into a few big ones (one per
## material per 5 x 5 spots) so a big facility stays cheap to draw; their
## collision stays as it is.
func _build_from_chunks() -> void:
	maze_body = StaticBody3D.new()
	maze_body.name = "MazeCollision"
	add_child(maze_body)
	# What each chunk offers
	var kinds := []   # [scene, openings, stairs, weight]
	for sc in chunks:
		if sc == null:
			continue
		var probe := sc.instantiate()
		if probe is SalvageChunk:
			kinds.append([sc, probe.openings(), probe.stairs, probe.weight])
		probe.free()
	for x in maze_size.x:
		for z in maze_size.y:
			var c := Vector2i(x, z)
			var need: Array[Vector2i] = []
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var n: Vector2i = c + d
				if level.has(n) and not _wall_between(c, n):
					need.append(d)
			# Chunks that fit, and the turn each needs
			var fits := []
			var total := 0.0
			for k in kinds:
				if k[2] != stair.has(c):
					continue
				for turn in 4:
					if _fits(k[1], turn, need, k[2], stair.get(c, Vector2i.ZERO)):
						fits.append([k[0], turn, k[3]])
						total += k[3]
						break
			var chunk: Node3D
			var turn := 0
			if fits.is_empty():
				# None fits: a plain one made to measure
				var B = load("res://Scenes/Salvage/Chunks/chunk_builder.gd")
				if stair.has(c):
					chunk = B.build(true, true, false, false, true)
					turn = _turn_to(Vector2i(0, 1), stair[c])
				else:
					chunk = B.build(need.has(Vector2i(0, -1)), need.has(Vector2i(0, 1)), need.has(Vector2i(1, 0)), need.has(Vector2i(-1, 0)))
			else:
				var pick := rng.randf() * total
				var chosen = fits[0]
				for f in fits:
					pick -= f[2]
					if pick <= 0.0:
						chosen = f
						break
				chunk = (chosen[0] as PackedScene).instantiate()
				turn = chosen[1]
			chunk.position = Vector3(x * cell_size, _floor_y(c), z * cell_size)
			chunk.rotation.y = turn * PI / 2.0
			add_child(chunk)
			if c == Vector2i.ZERO:
				_cut_hole(chunk)
			_absorb_chunk(chunk, c)
	_flush_batches()


## Do these open sides, turned this many quarter turns, match what's needed?
## (A staircase also has to climb the right way.)
func _fits(open: Array, turn: int, need: Array, is_stairs: bool, climb: Vector2i) -> bool:
	if open.size() != need.size():
		return false
	for o in open:
		if not need.has(_turned(o, turn)):
			return false
	if is_stairs and _turned(Vector2i(0, 1), turn) != climb:
		return false
	return true


## A direction in a chunk's own frame, as it points after this many quarter turns
func _turned(v: Vector2i, turn: int) -> Vector2i:
	for i in turn:
		v = Vector2i(v.y, -v.x)
	return v


func _turn_to(v: Vector2i, want: Vector2i) -> int:
	for t in 4:
		if _turned(v, t) == want:
			return t
	return 0


## The landing spot: its chunk's ceiling comes out and a ceiling with the hole
## you drop through goes in (the shaft above is in start_area.tscn)
func _cut_hole(chunk: Node3D) -> void:
	for n in ["Ceiling", "Collision/CeilingShape"]:
		var node := chunk.get_node_or_null(n)
		if node:
			node.free()
	var half := cell_size * 0.5
	var cy := _ceil_y(Vector2i.ZERO)
	var c := Vector2i.ZERO
	_mbox(Vector3(-half, cy, -half), Vector3(half, cy + 0.2, -HOLE), "ceiling", c)
	_mbox(Vector3(-half, cy, HOLE), Vector3(half, cy + 0.2, half), "ceiling", c)
	_mbox(Vector3(-half, cy, -HOLE), Vector3(-HOLE, cy + 0.2, HOLE), "ceiling", c)
	_mbox(Vector3(HOLE, cy, -HOLE), Vector3(half, cy + 0.2, HOLE), "ceiling", c)


## Take a placed chunk's meshes into the merged ones (and its materials into the
## lighting), and note its lamp spots
func _absorb_chunk(chunk: Node3D, c: Vector2i) -> void:
	for mk in chunk.find_children("*", "Marker3D", true, false):
		if mk.is_in_group("lamp_spot") and c != Vector2i.ZERO:
			lamp_spots.append(mk.global_position)
	for mi in chunk.find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		if m == null:
			continue
		if m is ShaderMaterial and not mats.values().has(m):
			mats["chunk_%d" % m.get_instance_id()] = m   # so the lamps light it too
		_batch_add(mi.mesh, mi.global_transform, m, c)
		mi.free()


## A box in the merged maze meshes (and its collision, unless solid is false)
func _mbox(a: Vector3, b: Vector3, mat_key: String, cell: Vector2i, solid := true) -> void:
	var size := (b - a).abs()
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var center := (a + b) * 0.5
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = int(clamp(size.x / 2.0, 0, 8))
	bm.subdivide_depth = int(clamp(size.z / 2.0, 0, 8))
	bm.subdivide_height = int(clamp(size.y / 2.0, 0, 4))
	_batch_add(bm, Transform3D(Basis(), center), mats[mat_key], cell)
	if solid:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.position = center
		maze_body.add_child(shape)


func _batch_add(mesh: Mesh, xform: Transform3D, mat: Material, cell: Vector2i) -> void:
	var key := "%d|%d|%d" % [mat.get_instance_id(), cell.x / 5, cell.y / 5]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		_batch_mats[key] = mat
	_batches[key].append_from(mesh, 0, xform)


func _flush_batches() -> void:
	for key in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = _batches[key].commit()
		mi.material_override = _batch_mats[key]
		add_child(mi)
	_batches.clear()
	_batch_mats.clear()


func _open(c: Vector2i, d: Vector2i) -> void:
	if d == Vector2i(1, 0): walls_h[c] = false
	elif d == Vector2i(-1, 0): walls_h[c + d] = false
	elif d == Vector2i(0, 1): walls_v[c] = false
	else: walls_v[c + d] = false


func _neighbours(c: Vector2i) -> Array:
	var out := []
	if c.x < maze_size.x - 1 and not walls_h[c]: out.append(c + Vector2i(1, 0))
	if c.x > 0 and not walls_h[c - Vector2i(1, 0)]: out.append(c - Vector2i(1, 0))
	if c.y < maze_size.y - 1 and not walls_v[c]: out.append(c + Vector2i(0, 1))
	if c.y > 0 and not walls_v[c - Vector2i(0, 1)]: out.append(c - Vector2i(0, 1))
	return out


func _distances() -> Dictionary:
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in _neighbours(c):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


# ── Lamps, items and the exit ─────────────────────────────────────────────────
func _place_lamps() -> void:
	# The chunks' lamp spots, shuffled with the run's own random numbers (so online
	# players get the same lamps); some get a lamp
	var spots := lamp_spots.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = spots[i]; spots[i] = spots[j]; spots[j] = tmp
	var n := 0
	for p in spots:
		if n >= _scaled(lamp_count, 14):
			break
		var ceil_h: float = p.y
		# Some lamps are dead, some stutter on and off, the rest barely hold on
		var roll := rng.randf()
		var state := LAMP_DEAD if roll < dead_lamps else (LAMP_STUTTER if roll < dead_lamps + stuttering_lamps else LAMP_ON)
		var key := "lamp_%d" % n
		var lm: ShaderMaterial = mats["lamp"].duplicate()
		mats[key] = lm
		_box(Vector3(p.x - 0.45, ceil_h - 0.1, p.z - 0.25), Vector3(p.x + 0.45, ceil_h, p.z + 0.25), key, false)
		_halo(Vector3(p.x, ceil_h - 0.25, p.z), 2.0, Color(0.95, 0.62, 0.38), 0.4)
		lamp_states[lamps.size()] = state
		lamp_mats[lamps.size()] = [lm, mats["halo_%d" % (mats.size() - 1)]]
		lamps.append(Vector3(p.x, ceil_h - 0.4, p.z))
		n += 1
	for m in mats.values():
		var arr := PackedVector3Array(lamps)
		m.set_shader_parameter("lamps", arr)
		m.set_shader_parameter("lamp_count", mini(lamps.size(), MAX_LAMPS))


## Each lamp's brightness this frame: dead ones stay off, stuttering ones cut out
## in bursts, the rest hum with a faint waver. The shader can light 48 at once, so
## it gets the 48 nearest to the players.
func _update_lamps() -> void:
	lamp_power.resize(lamps.size())
	for i in lamps.size():
		var v := 1.0   # the elevator's, the hole's and the exit's lights stay on
		match lamp_states.get(i, -1):
			LAMP_DEAD:
				v = 0.0
			LAMP_ON:
				v = 0.85 + 0.1 * sin(time * 23.0 + i) * sin(time * 7.3 + i * 2.0)
				if randf() < 0.003:
					v = 0.3
			LAMP_STUTTER:
				# off most of a second, then a few frantic blinks
				var t := fmod(time * (0.6 + 0.07 * i) + i * 0.37, 1.0)
				v = 0.0 if t < 0.55 else (0.8 if randf() < 0.55 else 0.05)
		lamp_power[i] = v
		if not lamp_mats.has(i):
			continue
		var lm: ShaderMaterial = lamp_mats[i][0]
		var glow := 0.12 + 0.88 * v
		lm.set_shader_parameter("color_a", Color(1.0, 0.82, 0.6) * glow if v > 0.0 else Color(0.08, 0.07, 0.06))
		lamp_mats[i][1].set_shader_parameter("strength", 0.4 * v)
	# The nearest lit lamps to any local player
	var order := []
	for i in lamps.size():
		if lamp_power[i] <= 0.0:
			continue
		var dist := INF
		for p in players:
			dist = minf(dist, p.global_position.distance_squared_to(lamps[i]))
		order.append([dist, i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var pos := PackedVector3Array()
	var pw := PackedFloat32Array()
	for k in mini(order.size(), MAX_LAMPS):
		pos.append(lamps[order[k][1]])
		pw.append(lamp_power[order[k][1]])
	pos.resize(MAX_LAMPS)
	pw.resize(MAX_LAMPS)
	for m in mats.values():
		m.set_shader_parameter("lamps", pos)
		m.set_shader_parameter("lamp_power", pw)
		m.set_shader_parameter("lamp_count", mini(order.size(), MAX_LAMPS))


func _place_items() -> void:
	# Spread out across the whole facility: each piece goes in the cell furthest
	# from every piece placed so far (and from where you land), with a nudge
	# toward dead ends, like things tucked away in side rooms
	var chosen: Array[Vector2i] = [Vector2i.ZERO]   # (the landing counts, so none sit right there)
	var cells: Array[Vector2i] = []
	for x in maze_size.x:
		for z in maze_size.y:
			if Vector2i(x, z) != Vector2i.ZERO and not stair.has(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	for i in mini(_scaled(item_count, 6), cells.size()):
		var best := Vector2i.ZERO
		var best_score := -1.0
		for c in cells:
			if chosen.has(c):
				continue
			var gap := INF
			for o in chosen:
				# (a floor up or down counts as a few cells apart, so every level gets some)
				gap = minf(gap, Vector3(c.x - o.x, (level.get(c, 0) - level.get(o, 0)) * 2.5, c.y - o.y).length())
			var score := gap + (0.8 if _neighbours(c).size() == 1 else 0.0) + rng.randf() * 0.6
			if score > best_score:
				best_score = score
				best = c
		chosen.append(best)
		var kind: Array = item_list[rng.randi_range(0, item_list.size() - 1)]
		var p := _cell_center(best) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		item_nodes.append(_make_item(kind, p))


func _make_item(kind: Array, at: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2   # only the interact ray hits items; you walk through it
	body.collision_mask = 0
	body.position = at
	body.rotation.y = rng.randf() * TAU   # (kept so online games place everything the same)
	# A flat sprite that turns to face you, like the characters (DOOM style)
	var tex := _item_texture(kind)
	var height: float = kind[6] if kind.size() > 6 else 0.5
	var spr := Sprite3D.new()
	spr.name = "Sprite"
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.pixel_size = height / float(maxi(tex.get_height(), 1))
	spr.centered = true
	spr.position.y = height * 0.5
	body.add_child(spr)
	var width := height * float(tex.get_width()) / float(maxi(tex.get_height(), 1))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()   # round, so it's as easy to aim at from any side
	cyl.radius = width * 0.5 + 0.15
	cyl.height = height + 0.3
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.set_meta("item", kind)
	add_child(body)
	return body


## An item's picture: its own, or the placeholder shape
func _item_texture(kind: Array) -> Texture2D:
	return kind[5] if kind.size() > 5 and kind[5] != null else _placeholder_texture(kind[3], kind[4])


## Items are lit like the characters: brighter near you and under the lamps
func _update_items() -> void:
	for node in item_nodes:
		if node.visible:
			var spr := node.get_node_or_null("Sprite") as Sprite3D
			if spr:
				# (a little brighter than the characters, so they catch your eye in the dark)
				var l := minf(_light_at(node.global_position + Vector3(0, 0.3, 0)) * 1.25 + 0.08, 1.0)
				spr.modulate = Color(l, l, l)


## Stand-in art until an item has its own picture: a flat shape in its colour with a
## dark outline, drawn at 32 x 32 so it matches the game's chunky pixels
var _placeholder_cache := {}
func _placeholder_texture(shape: String, color: Color) -> Texture2D:
	var key := "%s_%s" % [shape, color.to_html()]
	if _placeholder_cache.has(key):
		return _placeholder_cache[key]
	const N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var inside := func(x: float, y: float) -> bool:
		var u := (x + 0.5) / N * 2.0 - 1.0   # -1..1
		var v := (y + 0.5) / N * 2.0 - 1.0
		match shape:
			"circle": return u * u + v * v <= 0.86
			"triangle": return v >= -0.86 and v <= 0.86 and absf(u) <= (v + 0.86) / 1.72 * 0.92
			"diamond": return absf(u) + absf(v) <= 0.95
			_: return absf(u) <= 0.82 and absf(v) <= 0.82
	var edge := color.darkened(0.7)
	var shine := color.lightened(0.35)
	for y in N:
		for x in N:
			if not inside.call(x, y):
				continue
			var border: bool = not (inside.call(x - 2, y) and inside.call(x + 2, y) and inside.call(x, y - 2) and inside.call(x, y + 2))
			var c := edge if border else color
			if not border and x < N * 0.45 and y < N * 0.45 and inside.call(x - 4, y - 4):
				c = shine if (x + y) % 9 == 0 else c   # a few highlight pixels, top left
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[key] = tex
	return tex


func _place_exit() -> void:
	var dist := _distances()
	# Furthest to walk to, and far away across the map too (a long walk can end
	# right behind the landing's wall otherwise)
	var far := Vector2i.ZERO
	var best := -1.0
	for c in dist:
		if stair.has(c):
			continue
		var score: float = dist[c] + Vector2(c).length() * 2.0
		if score > best:
			best = score
			far = c
	exit_cell = far
	var p := _cell_center(far)
	# Back the elevator onto a side of that cell that's a wall
	var side := Vector3(0, 0, 1)
	if far.y == maze_size.y - 1 or walls_v.get(far, false):
		side = Vector3(0, 0, 1)
	elif far.x == maze_size.x - 1 or walls_h.get(far, false):
		side = Vector3(1, 0, 0)
	elif far.y == 0 or walls_v.get(far - Vector2i(0, 1), false):
		side = Vector3(0, 0, -1)
	else:
		side = Vector3(-1, 0, 0)
	_build_exit_elevator(p, side)
	for m in mats.values():
		m.set_shader_parameter("lamps", PackedVector3Array(lamps))
		m.set_shader_parameter("lamp_count", mini(lamps.size(), MAX_LAMPS))


## Rings to collect. Most lie in lines along the shortest way from the landing to
## the exit, so following them usually leads you out; a few lines are elsewhere.
func _place_rings() -> void:
	ring_sfx = AudioStreamPlayer.new()
	ring_sfx.volume_db = ring_volume_db
	if ResourceLoader.exists(ring_sound):
		ring_sfx.stream = load(ring_sound)
	add_child(ring_sfx)
	# The way out: walk back from the exit to the landing
	var parent := {Vector2i.ZERO: Vector2i.ZERO}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == exit_cell:
			break
		for n in _neighbours(c):
			if not parent.has(n):
				parent[n] = c
				queue.append(n)
	var path: Array[Vector2i] = []
	var at := exit_cell
	while parent.has(at) and at != Vector2i.ZERO:
		path.push_front(at)
		at = parent[at]
	path.push_front(Vector2i.ZERO)
	var on_path := {}
	for c in path:
		on_path[c] = true
	if ring_trail_every > 0:
		for i in range(2, path.size() - 1, ring_trail_every):
			_ring_line(path[i], path[i + 1] - path[i])
	# Decoys: lines in corridors off the way out
	var others: Array[Vector2i] = []
	for c in level:
		if not on_path.has(c) and c != Vector2i.ZERO and c != exit_cell:
			others.append(c)
	others.sort()   # (same order for everyone online)
	for k in mini(_scaled(decoy_ring_groups, 2), others.size()):
		var c: Vector2i = others[rng.randi_range(0, others.size() - 1)]
		var ways := _neighbours(c)
		if not ways.is_empty():
			_ring_line(c, ways[rng.randi_range(0, ways.size() - 1)] - c)


## Three rings in a line through a cell, pointing toward its neighbour in direction d
func _ring_line(c: Vector2i, d: Vector2i) -> void:
	var dir := Vector3(d.x, 0, d.y)
	var center := Vector3(c.x * cell_size, 0, c.y * cell_size)
	for k in [-1.0, 0.0, 1.0]:
		var pos: Vector3 = center + dir * k * 1.1
		pos.y = _floor_at(c, pos) + 0.55
		var r := Sprite3D.new()
		r.texture = ring_texture
		r.hframes = 7
		r.pixel_size = 0.4 / maxf(ring_texture.get_height(), 1.0)
		r.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		r.shaded = false
		r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		r.position = pos
		r.set_meta("index", ring_nodes.size())
		add_child(r)
		ring_nodes.append(r)


## The floor's height at a point in a cell (partway up, on a staircase)
func _floor_at(c: Vector2i, pos: Vector3) -> float:
	if not stair.has(c):
		return _floor_y(c)
	var d: Vector2i = stair[c]
	var along := ((pos.x - c.x * cell_size) * d.x + (pos.z - c.y * cell_size) * d.y) / cell_size + 0.5
	return _floor_y(c) + level_step * clampf(along, 0.0, 1.0)


## Spin the rings, and collect the ones a local player touches
func _update_rings() -> void:
	var spin := int(time * 8.0) % 4
	for r in ring_nodes:
		if not is_instance_valid(r) or r.get_meta("taken", false):
			continue
		r.frame = spin
		for p in players:
			if p.escaped:
				continue
			var off: Vector3 = r.global_position - (p.global_position + Vector3(0, 0.5, 0))
			if Vector2(off.x, off.z).length() < 0.7 and absf(off.y) < 1.0:
				p.rings += 1
				if ring_sfx.stream:
					ring_sfx.play()
				_take_ring(r)
				if Net.online:
					Net.send({"t": "svr", "i": int(r.get_meta("index"))})
				break


## A ring is gone: a little sparkle (the sheet's last frames), then it vanishes
func _take_ring(r: Sprite3D) -> void:
	if r.get_meta("taken", false):
		return
	r.set_meta("taken", true)
	var t := create_tween()
	for f in [4, 5, 6]:
		t.tween_callback(func(): r.frame = f)
		t.tween_interval(0.08)
	t.tween_callback(func(): r.visible = false)


## The way out (exit_elevator.tscn), doors open, backed onto the wall of the exit
## cell. Its own frame has the doors facing -z and the wall behind it at +z.
func _build_exit_elevator(cell_center: Vector3, side: Vector3) -> void:
	var car: Node3D = EXIT_ELEVATOR.instantiate()
	car.position = cell_center
	car.rotation.y = atan2(side.x, side.z)
	add_child(car)
	exit_car = car
	_register_props(car)
	for d in car.find_children("*", "", true, false):
		if d.is_in_group("elevator_door"):
			# open: slid aside behind the front wall; they close when it leaves
			d.position.x = d.get_meta("closed_x") + signf(d.get_meta("closed_x")) * 0.72
			exit_doors.append(d)


## Is this point inside the exit elevator?
func in_exit_car(world: Vector3) -> bool:
	if exit_car == null:
		return false
	var l := exit_car.to_local(world)
	return absf(l.x) < 1.15 and l.z > -0.55 and l.z < 1.6 and l.y > -0.5 and l.y < 2.5


# ── Players ──────────────────────────────────────────────────────────────────
## Render layers: 1 = the world; 2 + i = local player i's own sprite, hidden from
## their own camera so you never see yourself from the inside
func _build_players(pads: Array) -> void:
	var count := 2 if pads[1] >= 0 else 1
	var canvas := CanvasLayer.new()
	canvas.layer = 90   # over everything from the 2D game
	add_child(canvas)
	var res := render_size if count == 1 else Vector2i(render_size.x, render_size.y / 2)
	var chars := [Test.characterone, Test.charactertwo]
	if Net.online and Net.peers.has(Net.my_id):
		chars[0] = Net.peers[Net.my_id]["char"]
	for i in count:
		var p = PLAYER.instantiate()
		p.index = i
		p.actions = "sv_" if i == 0 else "sv2_"
		p.pad = pads[i]
		p.use_mouse = i == 0
		p.character = chars[i]
		add_child(p)
		p.build(self, res, MIRROR.camera_mask(0xFFFFF ^ (1 << (1 + i)), i))
		var spot := _spawn_spot(Net.my_id - 1 if Net.online else i, maxi(Net.peers.size(), count) if Net.online else count)
		p.global_position = spot
		p.rotation.y = PI   # facing the doors (+z)
		# This player's half of the screen (or all of it)
		var area := Control.new()
		area.set_anchors_preset(Control.PRESET_FULL_RECT)
		if count == 2:
			area.anchor_top = 0.5 * i
			area.anchor_bottom = 0.5 * (i + 1)
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(area)
		var screen := TextureRect.new()
		screen.texture = p.view.get_texture()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.stretch_mode = TextureRect.STRETCH_SCALE
		screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # soft, not hard pixels (It Steals)
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE   # (so the mouse reaches 1P's look)
		var m := ShaderMaterial.new()
		m.shader = SCREEN_SHADER
		m.set_shader_parameter("low_res", Vector2(res))
		screen.material = m
		area.add_child(screen)
		var tag := ""
		if count == 2:
			tag = "%dP" % (i + 1)
		elif Net.online:
			tag = "%dP" % Net.my_id
		var tag_col: Color = TAG_COLORS[(Net.my_id - 1 if Net.online else i) % 4]
		p.build_hud(area, tag, tag_col)
		players.append(p)
	if count == 2:
		var line := ColorRect.new()
		line.color = Color.BLACK
		line.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		line.offset_top = -3
		line.offset_bottom = 3
		# It sits right where the captured mouse is, so it mustn't catch the mouse
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(line)
	player = players[0]
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)


## Elevator spots, side by side, for up to 4 players
func _spawn_spot(slot: int, count: int) -> Vector3:
	var spread := 0.6
	var x := (slot - (count - 1) * 0.5) * spread
	return Vector3(clampf(x, -1.2, 1.2), UP_Y + 0.05, -6.6)


## The others, as DOOM-style sprites: AI followers, the co-op partner, online players
func _build_others() -> void:
	# The co-op partner: each local player's sprite, seen only by the other's camera
	if players.size() == 2:
		for i in 2:
			var spr = _make_sprite(players[i].character, 1 << (1 + i))
			if spr:
				partner_sprites[i] = spr
	# AI teammates follow 1P: your 2nd and 3rd picks alone, the 3rd in co-op, none online
	if not Net.online:
		var picks := [Test.characterthree] if players.size() == 2 else [Test.charactertwo, Test.characterthree]
		var n := 0
		for name in picks:
			if name == "" or name == Test.characterone:
				continue
			var tm = _make_sprite(name, 1)
			if tm == null:
				continue
			n += 1
			tm.gap = 1.4 * n
			tm.global_position = player.global_position + Vector3(0.6 * (1 if n == 1 else -1), 0, -0.9)
			followers.append(tm)
	# Online: everyone else in the room
	if Net.online:
		for id in Net.peers:
			if id == Net.my_id:
				continue
			var spr = _make_sprite(str(Net.peers[id]["char"]), 1)
			if spr:
				spr.global_position = _spawn_spot(id - 1, Net.peers.size())
				remote[id] = {"sprite": spr, "target": spr.global_position}


func _make_sprite(character: String, layer: int):
	var spr = TEAMMATE.instantiate()
	if not spr.setup(character):
		spr.free()
		return null
	spr.layers = layer
	add_child(spr)
	return spr


func _physics_process(delta: float) -> void:
	if players.is_empty():
		return
	time += delta
	_update_lamps()
	_update_rings()
	_update_items()
	_update_signs()
	for p in players:
		p.physics(delta)
	var cam: Camera3D = player.cam
	for tm in followers:
		tm.follow(player.global_position, cam, _light_at(tm.global_position + Vector3(0, 0.6, 0)), delta)
	for i in partner_sprites:
		var spr = partner_sprites[i]
		var who = players[i]
		spr.visible = not who.escaped
		spr.drive(who.global_position, players[1 - i].cam, _light_at(who.global_position + Vector3(0, 0.6, 0)), delta, who.anim_state())
	if Net.online:
		_net_update(delta)


## How bright a point is: the same light as the PS1 shader (lamps + the glow around you)
func _light_at(p: Vector3) -> float:
	var d := p.distance_to(player.cam.global_position)
	var l := pow(clampf(1.0 - d / 5.0, 0.0, 1.0), 1.6) * 0.55
	for i in lamps.size():
		var pw: float = lamp_power[i] if i < lamp_power.size() else 1.0
		l += pow(clampf(1.0 - p.distance_to(lamps[i]) / 4.8, 0.0, 1.0), 2.2) * 0.9 * pw
	return clampf(l * exp(-d * 0.02) + 0.01, 0.0, 1.0)


# ── Salvaging and escaping ───────────────────────────────────────────────────
func try_salvage(p, node: Node3D) -> void:
	var kind: Array = node.get_meta("item")
	if p.rings < kind[1]:
		p.show_message("Not enough rings", 1.4)
		return
	p.rings -= kind[1]
	p.carried.append(kind)
	var i := item_nodes.find(node)
	if Net.online and i >= 0:
		Net.send({"t": "svp", "i": i})   # it's gone for everyone
	_remove_item(node)
	p.show_message(kind[0], 1.8)   # just its name
	p.add_item_icon(_item_texture(kind))


func _remove_item(node: Node3D) -> void:
	if is_instance_valid(node):
		node.visible = false
		node.collision_layer = 0
		node.set_meta("taken", true)


## Someone pressed ESCAPE in the exit elevator (a local player, or online
## someone else: "svgo"). The doors close over depart_time seconds, then it leaves.
func press_escape(p) -> void:
	if departing or leaving:
		return
	if Net.online:
		Net.send({"t": "svgo"})
	_depart(p.index + 1 if not Net.online else Net.my_id)


func _depart(by: int) -> void:
	if departing:
		return
	departing = true
	for d in exit_doors:
		var t := create_tween()
		t.tween_property(d, "position:x", d.get_meta("closed_x"), depart_time)
	for p in players:
		p.prompt.text = ""
	# Countdown, with a warning beep each second
	for left in range(int(depart_time), 0, -1):
		for p in players:
			if not p.escaped:
				var where := "Stay inside!" if in_exit_car(p.global_position) else "GET IN!"
				p.show_message("%dP pressed ESCAPE\nThe elevator leaves in %d...  %s" % [by, left, where], 1.2)
		await get_tree().create_timer(1.0).timeout
	# Doors shut: whoever is inside gets out with their items
	for p in players:
		p.escaped = true
		p.prompt.text = ""
		if in_exit_car(p.global_position):
			Test.salvage_items += p.carried.size()
			Test.salvage_value += p.carried_value()
			p.show_message("You escaped empty-handed." if p.carried.is_empty() else \
					"You escaped with %d item%s" % [p.carried.size(), "" if p.carried.size() == 1 else "s"], 4.0)
		else:
			p.show_message("LEFT BEHIND\nThe elevator left without you." + \
					("" if p.carried.is_empty() else ("\nYour item is lost." if p.carried.size() == 1 else "\nYour %d items are lost." % p.carried.size())), 4.0)
	_leave()


func _leave() -> void:
	if leaving:
		return
	leaving = true
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(fade, "color:a", 1.0, 1.0)
	t.tween_callback(_return_to_rest)


func _return_to_rest() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Rebuild the rest area (not the boss) when the level reloads
	var lg = load("res://Scripts/Level/level_generator.gd")
	lg.rest_done_level = -1
	get_tree().change_scene_to_file(RETURN_SCENE)


# ── Online ───────────────────────────────────────────────────────────────────
func _net_update(delta: float) -> void:
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 1.0 / SEND_RATE
		var pos: Vector3 = player.global_position
		Net.send({"t": "sv", "x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01), "a": player.anim_state()})
	for id in remote:
		var r: Dictionary = remote[id]
		var spr = r.sprite
		if is_instance_valid(spr):
			spr.drive(r.target, player.cam, _light_at(r.target + Vector3(0, 0.6, 0)), delta, str(r.get("anim", "")))


func _on_net(m: Dictionary) -> void:
	var who := int(m.get("from", 0))
	match str(m.get("t", "")):
		"sv":
			if remote.has(who):
				remote[who].target = Vector3(float(m.x), float(m.y), float(m.z))
				remote[who].anim = str(m.get("a", ""))
		"svp":
			var i := int(m.i)
			if i >= 0 and i < item_nodes.size():
				_remove_item(item_nodes[i])
				for p in players:
					if p.looking_at == item_nodes[i]:
						p.looking_at = null
		"svgo":
			_depart(who)   # someone pressed ESCAPE
		"svr":
			var ri := int(m.i)
			if ri >= 0 and ri < ring_nodes.size():
				_take_ring(ring_nodes[ri])


## Painted words (the sign, the elevator's labels) are lit like the walls around them
func _update_signs() -> void:
	for entry in sign_labels:
		var l: Label3D = entry[0]
		var b := _light_at(l.global_position)
		l.modulate = entry[1] * (0.35 + 0.65 * b) * minf(b * 3.0, 1.0)
		l.modulate.a = 1.0
		l.outline_modulate = l.modulate

