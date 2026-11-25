extends Node2D

var bestTimeFloat := INF
var bestTimeText := ""
var elapsed_sesion_time : float = 0	# Total run time
var in_rest_area := false	# True in rest areas, where neither timer runs
var reading_page := false	# the rest tree's page is open
var floor_done := false	# True once this floor's goal is touched or its boss is beaten
var music = false
var rest = false
var musicplaying = false
# Touch controls turn on automatically on phones and tablets
var force_touch_controls := false
# Camera zoom setting
var zoom_level := 1
var zoom_chosen := false   # picked in the pause menu
# The music widget only shows for a few seconds when a song starts, and while paused
var music_widget_always := false
# True in a boss arena
var music_locked := false
# Salvage: items brought out this run, and the upgrades they gave
var salvage_items := 0
var owned_items: Array[String] = []   # the lasting upgrades you have, by item file
var meter_bonus := 0                  # extra max meter on top of 100
var full_meter_each_floor := false    # start every floor with a full meter
var boost_bonus := 0                  # % faster boost
var boss_hits := 1                    # how much each hit takes off a boss
const SUPER_BOSS_HITS := 2            # super forms hit bosses this many times harder
var boss_damage: int:                 # what a hit takes off right now
	get: return boss_hits * (SUPER_BOSS_HITS if anyone_super() else 1)
var extra_lives := 0                  # dying with one of these left starts the floor over instead
const RINGS_FOR_LIFE := 100           # every 100 rings you have
var _ring_life_at := RINGS_FOR_LIFE   # the ring count for the next one
var ring_loss_scale := 1.0            # share of the usual rings you lose when hit
var speed_bonus := 0                  # % faster running
var jump_bonus := 0                   # % higher jumps
var meter_scale := 1.0                # share of the usual meter moves use
var fly_bonus := 0                    # Longer Flight items
var trick_meter_bonus := 0            # Trick Meter items
var salvage_stuns := 0                # Stun items: stuns you have each Salvage visit
var salvage_saves := 0                # Survive items
var chaos_emeralds := 0               # Chaos Emeralds got out of Salvage this run
var super_emeralds := 0               # then the Super Emeralds, like Sonic 3 & Knuckles
var shield_items := 0                 # Shield items you have
var shields_each_floor := 0           # shields you're given fresh on every floor
var shields_left := 0                 # shields you have right now

# A new run: none of the Salvage upgrades
func clear_upgrades() -> void:
	salvage_items = 0
	owned_items.clear()
	set_meter_bonus(0)
	full_meter_each_floor = false
	boost_bonus = 0
	boss_hits = 1
	extra_lives = 0
	_ring_life_at = RINGS_FOR_LIFE
	ring_loss_scale = 1.0
	speed_bonus = 0
	jump_bonus = 0
	meter_scale = 1.0
	shields_each_floor = 0
	shield_items = 0
	shields_left = 0
	chaos_emeralds = 0
	super_emeralds = 0
	salvage_stuns = 0
	salvage_saves = 0
	fly_bonus = 0
	trick_meter_bonus = 0


# What a move costs after Moves Use Less Meter
func meter_cost(cost: float) -> float:
	return cost * meter_scale


# Running speed, with Run Faster
func speed_scale() -> float:
	return 1.0 + speed_bonus / 100.0


# Is a player in a super form right now?
func anyone_super() -> bool:
	if not is_inside_tree():
		return false
	if not get_tree().get_nodes_in_group("super_form").is_empty():
		return true
	for p in get_tree().get_nodes_in_group("all_characters"):
		if p.get("is_super"):
			return true
	return false


# Flying drains this much of what it used to
func fly_drain_scale() -> float:
	return 1.0 / (1.0 + fly_bonus / 100.0)


# Meter a trick gives, with Trick Meter items
func trick_meter(base: float) -> float:
	return base * (1.0 + trick_meter_bonus / 100.0)


const SUPER_EMERALDS := 7
const SUPER_RINGS := 50   # rings you need to turn super


# Jump strength for Jump Higher's extra height
func jump_scale() -> float:
	return sqrt(1.0 + jump_bonus / 100.0)


# The ground boost, with Faster Boost
func boost_scale() -> float:
	return 1.0 + boost_bonus / 100.0


# Rings lost from this many when hit, after Lose Fewer Rings
func rings_lost(loss: int) -> int:
	return roundi(loss * ring_loss_scale)

func set_meter_bonus(bonus: int) -> void:
	meter_bonus = bonus
	maxmeter = 100 + bonus
	meter = minf(meter, maxmeter)
var salvage_done_level := -1   # the floor whose rest area you've already been into Salvage from
var market_done_level := -1   # the floor whose rest area you've had your free item from
var salvage_danger := false   # this Salvage was entered from the Rewrite tree
var back_from_salvage := false   # the next floor to load is the rest area Salvage brought you back to
var mobile = force_touch_controls or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
var touch_controls_v2 := false	# true while the new touch controls
var touch_style := 0	# Touch controls

const SETTINGS_PATH := "user://settings.cfg"

func save_touch_style(style: int) -> void:
	touch_style = style
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)          # keep anything else that's in there
	cfg.set_value("controls", "touch_style", style)
	cfg.save(SETTINGS_PATH)


# Salvage seen from above instead of first person
var salvage_top_down := false
var salvage_look := 1.0   # Salvage look sensitivity

func save_salvage_look(v: float) -> void:
	salvage_look = clampf(v, 0.2, 3.0)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("controls", "salvage_look", salvage_look)
	cfg.save(SETTINGS_PATH)


func save_top_down(on: bool) -> void:
	salvage_top_down = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("controls", "salvage_top_down", on)
	cfg.save(SETTINGS_PATH)



# Progress, kept in the same file under [progress]
var deepest_floor := 0
var times_beaten := 0

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	bestTimeFloat = float(cfg.get_value("progress", "best_time", INF))
	if bestTimeFloat < INF:
		bestTimeText = "BEST TIME: " + _format_time(bestTimeFloat)
	deepest_floor = int(cfg.get_value("progress", "deepest_floor", 0))
	times_beaten = int(cfg.get_value("progress", "times_beaten", 0))

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)          # keep anything else that's in there
	if bestTimeFloat < INF:
		cfg.set_value("progress", "best_time", bestTimeFloat)
	cfg.set_value("progress", "deepest_floor", deepest_floor)
	cfg.set_value("progress", "times_beaten", times_beaten)
	cfg.save(SETTINGS_PATH)

# A floor started
func note_floor(floor_number: int) -> void:
	if floor_number > deepest_floor and not playtesting:
		deepest_floor = floor_number
		save_progress()

# The game was beaten
func note_beaten() -> void:
	times_beaten += 1
	save_progress()

# A setting from the pause menu, kept under [settings]
func save_setting(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", key, value)
	cfg.save(SETTINGS_PATH)

func load_setting(key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return default
	return cfg.get_value("settings", key, default)

static func _format_time(t: float) -> String:
	var total_cs := int(round(t * 100.0))
	return "%d:%02d:%02d" % [total_cs / 6000, (total_cs / 100) % 60, total_cs % 100]

# Rebindable actions
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

# Salvage's keys
const SALVAGE_KEY_ACTIONS := ["forward", "back", "left", "right", "jump", "sprint", "crouch", "interact", "map", "trick", "stun"]

func save_salvage_key(action: String, e: InputEvent) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var d := _event_to_dict(e)
	if not d.is_empty():
		cfg.set_value("salvage_keys", action, d)
		cfg.save(SETTINGS_PATH)

func salvage_key(action: String) -> InputEvent:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section_key("salvage_keys", action):
		return null
	return _dict_to_event(cfg.get_value("salvage_keys", action))

func clear_salvage_keys() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section("salvage_keys"):
		cfg.erase_section("salvage_keys")
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
	if e is InputEventMouseButton:
		return {"type": "mouse", "button": e.button_index}
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
		"mouse":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(d.get("button", 1))
			return mb
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
		salvage_top_down = bool(cfg.get_value("controls", "salvage_top_down", false))
		salvage_look = clampf(float(cfg.get_value("controls", "salvage_look", 1.0)), 0.2, 3.0)
var end = false
var rings = 0
var mikus_saved := 0	# Mikus brought to the goal
const MIKU_SCORE := 1000
var tricks_done := 0	# Air tricks done this run
const TRICK_SCORE := 50
const ITEM_SCORE := 500   # each item you still have at the end of the run
const RANK_S := 20000     # the score you need for each rank
const RANK_A := 15000
const RANK_B := 11000


# The run's score as it stands
func run_score() -> Dictionary:
	var minutes := elapsed_sesion_time / 60.0
	# Full time bonus up to 10 minutes, then 2000 less for every 5 minutes after
	var time_bonus: int = 10000 if minutes <= 10 else maxi(10000 - (int((int(minutes) - 10) / 5) * 2000), 0)
	var ring_bonus: int = rings * 100
	var miku_bonus: int = mikus_saved * MIKU_SCORE
	var trick_bonus: int = tricks_done * TRICK_SCORE
	var item_bonus: int = owned_items.size() * ITEM_SCORE   # the Salvage items you've kept
	var total: int = time_bonus + ring_bonus + miku_bonus + trick_bonus + item_bonus
	var rank := "S" if total >= RANK_S else ("A" if total >= RANK_A else ("B" if total >= RANK_B else ("C" if total >= 4000 else ("D" if total >= 2000 else "E"))))
	return {"time": time_bonus, "rings": ring_bonus, "mikus": miku_bonus, "tricks": trick_bonus, "items": item_bonus, "total": total, "rank": rank}


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
var characterfour: String = ""   # up to 4 picks

const FORMATION_OFFSETS := [   # each follower's place behind the leader
	Vector2(-75, 0),
	Vector2(-145, 0),
	Vector2(-215, 0),
]

const FORMATION_STOP_RANGE := 20.0          ## Distance from target slot where AI stops closing in
const FORMATION_SEPARATION_DISTANCE := 66.0  ## Min distance AI followers keep from each other
const FORMATION_SEPARATION_STRENGTH := 1.5   ## How hard followers push apart when too close

var boss_rotation_order: Array = []
var rng := RandomNumberGenerator.new()

# Set by the editor's Play buttons
var playtest_chunk: PackedScene = null
var playtest_arena: PackedScene = null
var playtest_look: Texture2D = null      # Play on a Miku look or an OC
var playtest_rescue_is_oc := false
var playtest_enemy: PackedScene = null
var playtesting := false   # started from the Sonic Escape panel's Play


# Bump this to put everyone's sound settings back to the defaults once
const AUDIO_RESET := 1

func _reset_audio_once() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	if int(cfg.get_value("settings", "audio_reset", 0)) >= AUDIO_RESET:
		return
	for key in ["music_volume", "sfx_volume"]:
		if cfg.has_section_key("settings", key):
			cfg.erase_section_key("settings", key)
	cfg.set_value("settings", "audio_reset", AUDIO_RESET)
	cfg.save(SETTINGS_PATH)


var display: Node   # display_settings.gd


# The voice-line echo
const VOICE_ECHO_BUS := "VoiceEcho"

func _make_voice_echo() -> void:
	if AudioServer.get_bus_index(VOICE_ECHO_BUS) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, VOICE_ECHO_BUS)
	AudioServer.set_bus_send(i, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
	var echo := AudioEffectDelay.new()
	echo.dry = 1.0
	echo.tap1_active = true
	echo.tap1_delay_ms = 110.0
	echo.tap1_level_db = -8.0
	echo.tap1_pan = -0.15
	echo.tap2_active = true
	echo.tap2_delay_ms = 230.0
	echo.tap2_level_db = -14.0
	echo.tap2_pan = 0.15
	echo.feedback_active = true
	echo.feedback_delay_ms = 340.0
	echo.feedback_level_db = -22.0
	AudioServer.add_bus_effect(i, echo)


func _ready() -> void:
	_make_voice_echo()
	display = preload("res://Scripts/UI/display_settings.gd").new()
	display.name = "Display"
	add_child(display)
	_reset_audio_once()
	_apply_playtest()
	_load_touch_style()
	_load_keybinds()   # rebound keys carry over between runs
	_load_progress()
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
	


# The Sonic Escape panel's Play buttons leave a note in user://playtest.cfg
func _apply_playtest() -> void:
	const NOTE := "user://playtest.cfg"
	if not OS.has_feature("editor") or not FileAccess.file_exists(NOTE):
		return
	var cfg := ConfigFile.new()
	cfg.load(NOTE)
	DirAccess.remove_absolute(NOTE)
	playtesting = true
	characterone = str(cfg.get_value("play", "character", "Sonic"))
	charactertwo = ""
	characterthree = ""
	characterfour = ""
	level = 2
	match str(cfg.get_value("play", "mode", "")):
		"boss":
			level = 4
			playtest_arena = load(str(cfg.get_value("play", "arena", "")))
			load("res://Scripts/Level/level_generator.gd").rest_done_level = 4   # straight into the fight
		"level":
			playtest_chunk = load(str(cfg.get_value("play", "chunk", "")))
		"enemy":
			playtest_enemy = load(str(cfg.get_value("play", "enemy", "")))   # a row of them near the start
		"rescue":
			playtest_look = load(str(cfg.get_value("play", "look", "")))
			playtest_rescue_is_oc = bool(cfg.get_value("play", "is_oc", false))
	print("Playtest: %s as %s" % [cfg.get_value("play", "mode", ""), characterone])


func build_boss_rotation():
	rng.randomize()
	boss_rotation_order = range(Content.bosses().size())   # indexes into Content.bosses
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


# 100 rings: an extra life, like the classics
func _check_ring_life() -> void:
	if rings < _ring_life_at:
		return
	while rings >= _ring_life_at:
		extra_lives += 1
		_ring_life_at += RINGS_FOR_LIFE
	var me := get_tree().get_first_node_in_group("active_player") as Node2D
	if me == null:
		return
	if "sfx" in me and me.sfx:
		me.sfx.pitch_scale = 1.5
		me.sfx.stream = load("res://Sounds/SonicSFX/sparklesfx.MP3")
		me.sfx.play()
	var label := Label.new()
	label.text = "1UP"
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 50)
	label.z_index = 50
	me.get_parent().add_child(label)
	var follow := func(rise: float):
		if is_instance_valid(me):
			label.global_position = me.global_position + Vector2(-100, -95 - rise)
	follow.call(0.0)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_method(follow, 0.0, 40.0, 1.2)
	t.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.8)
	t.chain().tween_callback(label.queue_free)


func _process(delta: float) -> void:
	_check_ring_life()
	if quit == true:
		quit = false
		fade_and_change_scene()
		
