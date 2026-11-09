extends Node2D
## The training stage. Level 1 is always this stage (every run, not
## skippable), in the spirit of Cuphead's tutorial: one linear course with a sign
## at each station showing the move and its button, and something to practise it on.
## Each sign marks itself CLEAR once you've actually done the move.
##
## Built in code from your own terrain tile, so collisions, slopes-free footing,
## the Rush terrain skin, reflections and weather all work exactly like other chunks.
## Created by level_generator.gd when Test.level == 1.

const TILE := 48.0                  # world units per tile (16 px tiles at scale 3)
const SOLID := Vector2i(2, 1)       # the plain solid block your chunks are built from
const DEPTH := 22                   # rows of ground below the surface

## Terrain, as runs of columns: [first_x, last_x, top_row]. Row 0 is normal ground
## height; negative rows are higher, positive rows are lower.
const TERRAIN := [
	[-8, -3, -14],   # back wall
	[-2, 27, 0],     # RUN, JUMP
	[28, 31, -2],    # jump steps
	[32, 35, 0],
	[36, 39, -3],
	[40, 69, 0],     # SPINDASH runway, WALL JUMP shaft floor starts at 70
	[70, 76, 0],     # shaft floor
	[77, 90, -8],    # top of the shaft wall, plateau
	[91, 94, -4],    # step down
	[95, 115, 0],    # AIR TRICK spring
	[116, 121, -4],  # STOMP ledge
	[122, 132, 0],
	[133, 146, 3],   # AIRSPIN trench (shallow, safe)
	[147, 182, 0],   # SWITCH, PICK UP, exit
]
## Floating blocks: [first_x, last_x, top_row, bottom_row]
const FLOATING := [
	[69, 70, -11, -4],  # left wall of the shaft (gap underneath to walk in)
]
const END_X := 182

## Stations: tile x of the sign, title, text, the move that clears it,
## and the abilities (component node names) a character needs for it.
## {jump} etc. are replaced with the player's current key bindings.
const STATIONS := [
	{"x": 9, "title": "RUN", "text": "Hold {left} / {right} to run.\nKeep holding to build speed.", "move": "run", "needs": []},
	{"x": 21, "title": "JUMP", "text": "Press {jump} to jump.\nHold it for a high jump, tap it for a short hop.", "move": "jump", "needs": []},
	{"x": 47, "title": "SPINDASH", "text": "Stand still and hold {down}.\nTap {jump} to rev up, then let go of {down}.", "move": "spindash", "needs": []},
	{"x": 62, "title": "WALL JUMP", "text": "Jump at a wall, then press {jump} to kick off it.\nKick between the walls to climb the shaft.", "move": "walljump", "needs": ["WallJump", "WallClimb", "Fly"]},
	{"x": 99, "title": "AIR TRICK", "text": "Bounce on the spring and press {trick} in the air.\nTricks fill your boost meter.", "move": "trick", "needs": ["Trick"]},
	{"x": 111, "title": "STOMP", "text": "In the air, hold {down} and press {airspin}.\nStomp again as you land to bounce higher.", "move": "stomp", "needs": ["Stomp"]},
	{"x": 127, "title": "AIRSPIN", "text": "In the air, hold a direction and press {airspin}.\nIt costs boost, so trick to refill it.", "move": "airspin", "needs": ["Airspin"]},
	{"x": 149, "title": "SWITCH", "text": "Press {switch} on the ground to swap characters.\nEach one has different moves.", "move": "switch", "needs": []},
	{"x": 162, "title": "PICK UP", "text": "Hold {up} next to Miku to pick her up, {trick} to throw.\nTails and Cream: hold {jump} in the air to fly.\nTeammates grab on.", "move": "pickup", "needs": []},
]

const SPRING_SCENE := preload("res://Scenes/Obstacles/Spring/Spring.tscn")
const RING_SCENE := preload("res://Scenes/Obstacles/Rings/Rings.tscn")
const MIKU_SCENE := preload("res://Scenes/Obstacles/Miku/miku.tscn")
const MAP_SCRIPT := preload("res://Scripts/UI/map.gd")

const SIGN_WIDTH := 430.0          # board text width (world units)
const SIGN_HEIGHT := 120.0         # post height, so boards sit above heads and ring lines

const RED := Color("c4161f")
const WHITE := Color("f2f2f2")

var signs := {}          # move -> {"panel", "title", "note", "data"}
var done := {}           # move -> true
var helper_spring: Area2D
var _was_spinning := false
var _was_on_wall := false
var _player: CharacterBody2D


static func create(tile_set: TileSet) -> Node2D:
	var stage: Node2D = load("res://Scripts/Level/tutorial_stage.gd").new()
	stage.name = "TutorialStage"
	stage._build(tile_set)
	return stage


func _build(tile_set: TileSet) -> void:
	# Same structure as a level chunk: Level/TileMapLayer, Start, End
	var level := Node2D.new()
	level.name = "Level"
	add_child(level)
	var tm := TileMapLayer.new()
	tm.name = "TileMapLayer"
	tm.tile_set = tile_set
	tm.scale = Vector2(3, 3)
	tm.set_script(MAP_SCRIPT)          # per-stage tile colours + Rush skin, like other chunks
	for run in TERRAIN:
		for x in range(run[0], run[1] + 1):
			for y in range(run[2], DEPTH):
				tm.set_cell(Vector2i(x, y), 0, SOLID)
	for blk in FLOATING:
		for x in range(blk[0], blk[1] + 1):
			for y in range(blk[2], blk[3] + 1):
				tm.set_cell(Vector2i(x, y), 0, SOLID)
	level.add_child(tm)

	var start := Marker2D.new()
	start.name = "Start"
	start.position = Vector2(4 * TILE, 0)
	add_child(start)
	var end := Marker2D.new()
	end.name = "End"
	end.position = Vector2((END_X + 1) * TILE, 0)
	add_child(end)

	_build_props()
	for st in STATIONS:
		_build_sign(st)


func _top_row(x: int) -> int:
	for run in TERRAIN:
		if x >= run[0] and x <= run[1]:
			return run[2]
	return 0


func _build_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	# Rings along the runs, as a reward line
	for x in range(50, 62, 1):
		_ring(props, Vector2(x * TILE, -1.5 * TILE))
	for y in range(3, 11):
		_ring(props, Vector2(104.5 * TILE, -y * TILE))
	for x in range(134, 146, 1):
		_ring(props, Vector2(x * TILE, -2.5 * TILE))
	# Air trick spring
	var spring := SPRING_SCENE.instantiate()
	spring.position = Vector2(104.5 * TILE, 0)
	spring.set("spring_velocity", Vector2(0, -1400))
	spring.set("show_arc", false)
	props.add_child(spring)
	# Helper spring in the wall-jump shaft, only for characters that can't
	# wall jump, climb or fly (so nobody can get stuck)
	helper_spring = SPRING_SCENE.instantiate()
	# Right at the foot of the tall wall, where a stuck player ends up, angled up and over
	helper_spring.position = Vector2(76.3 * TILE, 0)
	helper_spring.set("spring_velocity", Vector2(260, -1650))
	helper_spring.set("show_arc", false)
	props.add_child(helper_spring)
	# Miku to pick up
	var miku := MIKU_SCENE.instantiate()
	miku.scale = Vector2(125, 125)
	miku.position = Vector2(167 * TILE, -1.2 * TILE)
	props.add_child(miku)


func _ring(parent: Node, pos: Vector2) -> void:
	var r := RING_SCENE.instantiate()
	r.position = pos
	parent.add_child(r)


# ── Signs ───────────────────────────────────────────────────────────────────
func _build_sign(st: Dictionary) -> void:
	var base_y := _top_row(st.x) * TILE
	var sign := Node2D.new()
	sign.name = "Sign_" + st.move
	sign.position = Vector2(st.x * TILE, base_y)
	sign.z_index = -1
	add_child(sign)

	# Post
	var post := ColorRect.new()
	post.color = Color(0.1, 0.1, 0.12)
	post.size = Vector2(6, SIGN_HEIGHT)
	post.position = Vector2(-3, -SIGN_HEIGHT)
	sign.add_child(post)

	# Board: dark panel, red bar on the left, title and text
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
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
	var title := Label.new()
	title.text = st.title
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", WHITE)
	v.add_child(title)
	var body := Label.new()
	body.text = _fill_keys(st.text)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(WHITE, 0.85))
	body.add_theme_constant_override("line_spacing", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = SIGN_WIDTH
	v.add_child(body)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	note.visible = false
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = SIGN_WIDTH
	v.add_child(note)
	sign.add_child(panel)
	# Sit the board on top of the post
	panel.reset_size.call_deferred()
	(func():
		panel.position = Vector2(-panel.size.x * 0.5, -SIGN_HEIGHT - panel.size.y)
	).call_deferred()
	signs[st.move] = {"panel": panel, "box": box, "title": title, "note": note, "data": st}


func _fill_keys(text: String) -> String:
	for action in [["jump", "ui_accept"], ["left", "ui_left"], ["right", "ui_right"], ["up", "ui_up"],
			["down", "ui_down"], ["airspin", "airspin"], ["trick", "trick"], ["switch", "switch"]]:
		text = text.replace("{" + action[0] + "}", _key_name(action[1]))
	return text


func _key_name(action: String) -> String:
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


func _mark(move: String) -> void:
	if done.has(move) or not signs.has(move):
		return
	done[move] = true
	var s: Dictionary = signs[move]
	s.title.text = s.data.title + "   CLEAR"
	s.title.add_theme_color_override("font_color", RED)
	s.box.border_color = WHITE


# ── Tracking which moves the player has done ────────────────────────────────
func _ready() -> void:
	process_physics_priority = 1000   # run after the characters have moved this frame
	if GlobalSignals.has_signal("switch_new_active_player"):
		GlobalSignals.switch_new_active_player.connect(func(_p): _mark("switch"))


func _physics_process(_delta: float) -> void:
	_player = get_tree().get_first_node_in_group("active_player") as CharacterBody2D
	if _player == null:
		var all := get_tree().get_nodes_in_group("all_characters")
		if all.is_empty():
			return
		_player = all[0]
	var p := _player
	var on_floor := p.is_on_floor()

	if on_floor and abs(p.velocity.x) > 500.0:
		_mark("run")
	if not on_floor and p.get("has_jumped") and p.velocity.y < -250.0:
		_mark("jump")
	var spinning: bool = p.get("is_spinningdash") == true
	if _was_spinning and not spinning and p.get("ball") == true:
		_mark("spindash")
	_was_spinning = spinning
	var on_wall: bool = p.get("hanging_on_wall") == true
	if _was_on_wall and not on_wall and abs(float(p.get("motion").x)) >= 900.0 and float(p.get("motion").y) < 0.0:
		_mark("walljump")
	_was_on_wall = on_wall
	if not on_floor and GlobalCanvasLayer.get("tricks") and int(GlobalCanvasLayer.tricks) > 0:
		_mark("trick")
	if p.get("next_bounce") == true and p.get("falling") == true:
		_mark("stomp")
	var ap = p.get("ap")
	if ap and ap.current_animation == "airspin":
		_mark("airspin")
	for c in get_tree().get_nodes_in_group("all_characters"):
		if c.get("hang") == true or c.get("held_item") != null:
			_mark("pickup")

	_update_ability_notes(p)


func _update_ability_notes(p: Node) -> void:
	# Signs say when the current character can't do a move
	for move in signs:
		var s: Dictionary = signs[move]
		var needs: Array = s.data.needs
		var can := needs.is_empty()
		for n in needs:
			if p.has_node(n):
				can = true
		s.note.visible = not can and not done.has(move)
		if s.note.visible:
			s.note.text = "This character can't do this. Switch with " + _key_name("switch") + "."
	# The shaft's helper spring is only there for characters that can't climb it
	var can_climb := p.has_node("WallJump") or p.has_node("WallClimb") or p.has_node("Fly")
	if helper_spring:
		helper_spring.visible = not can_climb
		helper_spring.process_mode = Node.PROCESS_MODE_DISABLED if can_climb else Node.PROCESS_MODE_INHERIT
