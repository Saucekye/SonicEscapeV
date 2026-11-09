extends Node2D

var bestTimeFloat := INF
var bestTimeText := ""
var elapsed_sesion_time : float = 0	## Total run time: the sum of every floor and boss split (timer.gd)
var in_rest_area := false	## True in rest areas, where neither timer runs (level_generator.gd)
var floor_done := false	## True once this floor's goal is touched or its boss is beaten; the timers stop
var music = false
var rest = false
var musicplaying = false
## Touch controls turn on automatically on phones and tablets (mobile web too).
## Set force_touch_controls to true to test the touch layout on a PC.
var force_touch_controls := false
## Camera zoom setting (Pause > Settings > Zoom). 0 = Wide (further
## back than the original view), 1 = Close (the original view), 2 = Closest.
var zoom_level := 1
## Stage atmosphere (haze, colour grade, glow, particles).
## Pause > Settings > Effects turns it off on slower machines.
var effects_enabled := true
## Dress the terrain with Sonic Rush Adventure tiles. false = the original silhouette terrain.
var rush_terrain := true
## The music widget (song picker + video box) only shows for a few seconds
## when a song starts, and while paused. true = always on screen like before.
var music_widget_always := false
## True in a boss arena (chunk_boss.gd): the song can't be changed and the music box,
## Teto included, stays hidden
var music_locked := false
## Salvage mini game (Scenes/Salvage/salvage.gd): items brought out this run, and its total value
var salvage_items := 0
var salvage_value := 0
var salvage_done_level := -1   # the floor whose rest area you've already been into Salvage from (once per rest area)
## Analog CRT look over the whole game (Pause > Settings > CRT)
var crt_enabled := false
var crt: CanvasLayer
var mobile = force_touch_controls or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
var touch_controls_v2 := false	## true while the new touch controls (mobile_controls.gd) are in charge
var touch_style := 0	## Touch controls: 0 = thumbstick, 1 = d-pad (Pause > Settings; saved in user://settings.cfg)

const SETTINGS_PATH := "user://settings.cfg"

func save_touch_style(style: int) -> void:
	touch_style = style
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)          # keep anything else that's in there
	cfg.set_value("controls", "touch_style", style)
	cfg.save(SETTINGS_PATH)

## Local co-op (Pause > Settings > Co-op; saved in user://settings.cfg). With it on
## and at least two characters picked, the second character is Player 2 (see coop.gd).
var coop_enabled := false
var coop_test_pads: Array = []	## automated tests only: pretend these controllers are connected

func save_coop(on: bool) -> void:
	coop_enabled = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("controls", "coop", on)
	cfg.save(SETTINGS_PATH)

## Actions the characters read; co-op makes a "p1_" and "p2_" copy of each
const PLAYER_ACTIONS := ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "airspin", "airup", "trick", "crouch", "dash"]

## Builds each co-op player's own controls from the current bindings (so rebinds
## carry over). Two or more controllers: P1 = keyboard + first controller,
## P2 = second controller. One controller: P1 = keyboard, P2 = the controller.
## Returns [p1 controller, p2 controller] (-1 = none).
func setup_coop_actions() -> Array:
	var pads: Array = Input.get_connected_joypads()
	if not coop_test_pads.is_empty():
		pads = coop_test_pads
	var p1_pad := -1
	var p2_pad := -1
	if pads.size() >= 2:
		p1_pad = pads[0]
		p2_pad = pads[1]
	elif pads.size() == 1:
		p2_pad = pads[0]
	for action in PLAYER_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for prefix in ["p1_", "p2_"]:
			var copy: String = prefix + action
			if InputMap.has_action(copy):
				InputMap.erase_action(copy)
			InputMap.add_action(copy, InputMap.action_get_deadzone(action))
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_add_event("p1_" + action, e.duplicate())
			elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
				if p1_pad >= 0:
					var e1: InputEvent = e.duplicate()
					e1.device = p1_pad
					InputMap.action_add_event("p1_" + action, e1)
				if p2_pad >= 0:
					var e2: InputEvent = e.duplicate()
					e2.device = p2_pad
					InputMap.action_add_event("p2_" + action, e2)
	return [p1_pad, p2_pad]

## Rebindable actions (the Keybind screen); saved under [keybinds] in the same file
const KEYBIND_ACTIONS := ["ui_accept", "airspin", "airup", "trick", "ui_left", "ui_right", "ui_up", "ui_down"]

func save_keybinds() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)          # keep anything else that's in there
	for action in KEYBIND_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var list := []
		for e in InputMap.action_get_events(action):
			var d := _event_to_dict(e)
			if not d.is_empty():
				list.append(d)
		cfg.set_value("keybinds", action, list)
	cfg.save(SETTINGS_PATH)

func clear_saved_keybinds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section("keybinds"):
		cfg.erase_section("keybinds")
		cfg.save(SETTINGS_PATH)

func _load_keybinds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section("keybinds"):
		return
	for action in KEYBIND_ACTIONS:
		if not InputMap.has_action(action) or not cfg.has_section_key("keybinds", action):
			continue
		var events := []
		for d in cfg.get_value("keybinds", action, []):
			var e := _dict_to_event(d)
			if e:
				events.append(e)
		if events.is_empty():
			continue                 # never leave an action with nothing bound
		InputMap.action_erase_events(action)
		for e in events:
			InputMap.action_add_event(action, e)

func _event_to_dict(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"type": "key", "keycode": e.keycode, "physical": e.physical_keycode}
	if e is InputEventJoypadButton:
		return {"type": "joy_button", "button": e.button_index}
	if e is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": e.axis, "value": e.axis_value}
	return {}

func _dict_to_event(d) -> InputEvent:
	if not d is Dictionary:
		return null
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.keycode = int(d.get("keycode", 0))
			k.physical_keycode = int(d.get("physical", 0))
			return k if (k.keycode != 0 or k.physical_keycode != 0) else null
		"joy_button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d.get("button", 0))
			return b
		"joy_axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d.get("axis", 0))
			m.axis_value = float(d.get("value", 1.0))
			return m
	return null

func _load_touch_style() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		touch_style = int(cfg.get_value("controls", "touch_style", 0))
		coop_enabled = bool(cfg.get_value("controls", "coop", false))
var end = false
var rings = 0
var p2_rings := 0	## co-op Player 2's rings (Player 1 uses rings); see Player.my_rings
var p2_meter: float = 100	## co-op Player 2's meter (Player 1 uses meter)
var mikus_saved := 0	## Mikus brought to the goal (or kept safe through a boss) this run; worth MIKU_SCORE each on the results screen
const MIKU_SCORE := 1000
var tricks_done := 0	## Air tricks done this run; worth TRICK_SCORE each on the results screen
const TRICK_SCORE := 50
var meter = 100
var maxmeter = 100
var scene_loaded = false
var trick = ""
var quit = false
var ridenemies = false
var fail = false
var final = false
var level = 0
var complete = false
var current_background : int = 0
var current_background_name : String = ""
var current_character_index : int = 0

var characterone: String = ""
var charactertwo: String = ""
var characterthree: String = ""

const FORMATION_OFFSETS := [
	Vector2(-50, 0),
	Vector2(-65, 0),
]

const FORMATION_STOP_RANGE := 40.0          ## Distance from target slot where AI stops closing in
const FORMATION_SEPARATION_DISTANCE := 60.0  ## Min distance AI followers keep from each other
const FORMATION_SEPARATION_STRENGTH := 1.5   ## How hard followers push apart when too close

var boss_rotation_order: Array = []
var rng := RandomNumberGenerator.new()

## Set by the editor's Play buttons (Sonic Escape panel): the next floor uses
## only this level chunk, or is this boss fight.
var playtest_chunk: PackedScene = null
var playtest_arena: PackedScene = null


func _ready() -> void:
	_apply_playtest()
	_load_touch_style()
	_load_keybinds()   # rebound keys carry over between runs
	# Red / white / black buttons, dropdowns, toggles and sliders on every
	# screen (labels, panels and sizes are left alone so layouts don't change)
	get_tree().root.theme = preload("res://Scripts/UI/rush_theme.gd").build_global()
	# Analog CRT over everything; lives on this autoload so it survives scene changes
	crt = preload("res://Scripts/UI/crt_overlay.gd").new()
	add_child(crt)
	print(mobile)
	get_tree().paused = false
	Pause.current_scene = "Node2D"
	meter = 100
	music = true
	
	# Ensure scene is fully loaded before proceeding
	await ensure_scene_loaded()
	
	# Initialize variables (fix: remove redundant var declarations)

	
	# Set up mobile controls
	if mobile == true:
		if has_node("CanvasLayer/TouchScreenButton"):
			$CanvasLayer/TouchScreenButton.visible = true
	
	# Mark scene as ready
	scene_loaded = true
	
	# Call any initialization that should happen after loading
	initialize_scene()
	


## The Sonic Escape panel's Play buttons leave a note in user://playtest.cfg and
## start the game in the level scene; this sets the run up to match.
func _apply_playtest() -> void:
	const NOTE := "user://playtest.cfg"
	if not OS.has_feature("editor") or not FileAccess.file_exists(NOTE):
		return
	var cfg := ConfigFile.new()
	cfg.load(NOTE)
	DirAccess.remove_absolute(NOTE)
	characterone = str(cfg.get_value("play", "character", "Sonic"))
	charactertwo = ""
	characterthree = ""
	level = 2
	match str(cfg.get_value("play", "mode", "")):
		"boss":
			level = 4
			playtest_arena = load(str(cfg.get_value("play", "arena", "")))
			load("res://Scripts/Level/level_generator.gd").rest_done_level = 4   # straight into the fight
		"level":
			playtest_chunk = load(str(cfg.get_value("play", "chunk", "")))
	print("Playtest: %s as %s" % [cfg.get_value("play", "mode", ""), characterone])


func build_boss_rotation():
	rng.randomize()
	if Net.online:
		rng.seed = Net.run_seed   # same boss order for every online player
	boss_rotation_order = range(Content.bosses().size())   # indexes into Content.bosses()
	for i in range(boss_rotation_order.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = boss_rotation_order[i]
		boss_rotation_order[i] = boss_rotation_order[j]
		boss_rotation_order[j] = tmp

# Ensure all nodes and resources are fully loaded
func ensure_scene_loaded() -> void:
	# Wait for the scene tree to be fully ready
	await get_tree().process_frame
	
	# Wait for all child nodes to be ready
	await wait_for_children_ready()
	
	# Optional: Wait for any resources to load
	await wait_for_resources()

# Wait for all child nodes to be ready
func wait_for_children_ready() -> void:
	var children_to_wait = []
	
	# Get all children recursively
	var all_children = get_all_children(self)
	
	for child in all_children:
		if not child.is_node_ready():
			children_to_wait.append(child)
	
	# Wait for each child to be ready
	for child in children_to_wait:
		if is_instance_valid(child):
			await child.ready

# Recursively get all children
func get_all_children(node: Node) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(get_all_children(child))
	return children

# Wait for any resources that might still be loading
func wait_for_resources() -> void:
	# Wait a frame to ensure all resources are processed
	await get_tree().process_frame
	
	# Optional: Check for specific resources if needed
	# For example, if you have textures or audio that need to load:
	"""
	if has_node("SomeSprite"):
		var sprite = $SomeSprite
		while sprite.texture == null:
			await get_tree().process_frame
	"""

# Initialize scene after everything is loaded
func initialize_scene() -> void:
	# Put any initialization code here that should run after loading
	# (for example: start background music, enable input)
	pass

# Fixed function name and added null checking
func _on_button_2_pressed() -> void:
	# Ensure scene is loaded before handling input
	if not scene_loaded:
		return
	
	# Check if the TouchScreenButton exists before accessing it
	if not has_node("CanvasLayer/TouchScreenButton"):
		print("TouchScreenButton not found!")
		return
	
	var touch_button = $CanvasLayer/TouchScreenButton
	
	if touch_button.visible == false:
		touch_button.visible = true
		mobile = true
	else:
		touch_button.visible = false
		mobile = false

# Optional: Prevent any gameplay input until scene is loaded
func _input(event: InputEvent) -> void:
	if not scene_loaded:
		get_viewport().set_input_as_handled()
		return

# Alternative simpler approach if you don't need the complex loading
func simple_ready() -> void:
	# Just wait a couple frames to ensure everything is loaded
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Initialize variables
	meter = 100
	
	# Set up mobile controls
	if mobile == true and has_node("CanvasLayer/TouchScreenButton"):
		$CanvasLayer/TouchScreenButton.visible = true
	
	scene_loaded = true

func _on_button_pressed() -> void:
	#rings = 0
	meter = 100
	get_tree().reload_current_scene()
	
func fade_and_change_scene() -> void:
	# Alternative approach: Add overlay to viewport to ensure it's cleaned up on scene change
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 1000
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to the main scene tree so it gets cleaned up automatically
	overlay_layer.add_child(overlay)
	get_tree().current_scene.add_child(overlay_layer)
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	#if has_node("AudioStreamPlayer"):
	tween.parallel().tween_property(MusicManager, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	# Scene change will automatically clean up the overlay
	get_tree().change_scene_to_file("uid://dwkxx7a6fwjqv")


func _process(delta: float) -> void:
	if quit == true:
		quit = false
		fade_and_change_scene()
		
	# (The total run time is added up by the HUD timer, timer.gd, so it matches the
	# floor and boss splits exactly and leaves out rest areas, intros and transitions.)
