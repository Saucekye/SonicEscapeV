extends Node2D

var bestTimeFloat := INF
var bestTimeText := ""
var music = false
var musicplaying = false
var mobile = false
var end = false
var rings = 0
var meter = 100
var maxmeter = 100
var scene_loaded = false
var trick = ""
var quit = false
var ridenemies = false
var fail = false
var level = 0
var current_background : int = 0
var current_background_name : String = ""

var characterone: String = ""
var charactertwo: String = ""
var characterthree: String = ""

var boss_rotation_order: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
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
	


func build_boss_rotation():
	rng.randomize()
	boss_rotation_order = [0, 1, 2, 3]  # 0=boss, 1=boss1, 2=boss2, 3=rest
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
	print("Scene fully loaded and ready!")
	
	# Example: Start background music, enable input, etc.
	# enable_gameplay()

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
