extends Sprite2D
var base_position = Vector2.ZERO
var mobile_var = "Good"
var rng = RandomNumberGenerator.new()
var music_bus_index = AudioServer.get_bus_index("Music")
var textures = []
var texture_change = false
var follower_spawned = false
var follower_scene = preload("res://Scenes/Obstacles/2011X/exe.tscn")
var follower_instance = null

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	$CanvasLayer/Label2.anchor_left = 0.5
	$CanvasLayer/Label2.anchor_top = 0.5
	$CanvasLayer/Label2.anchor_right = 0.5
	$CanvasLayer/Label2.anchor_bottom = 0.5
	base_position = Vector2(536,280)
	$CanvasLayer/Label2.position = base_position
	$CanvasLayer/Label2.pivot_offset = $CanvasLayer/Label2.size / 2
	
	textures = [
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Obstacles/2011X/Sprite-00062.png"),
		preload("res://Sprites/Background/Eggman/Sprite-0006.png"),
		preload("res://Sprites/Background/Eggman/Sprite-0006.png"),
		preload("res://Sprites/Background/Eggman/Sprite-0006.png"),
	]

func update_position_based_on_orientation():
	var screen_size = get_viewport().size
	var is_mobile_res = abs(screen_size.x - 1600) < 10 and abs(screen_size.y - 720) < 10
	mobile_var = "Good"

func spawn_follower():
	# Option 1: If you created a scene file (follower.tscn)
	follower_instance = follower_scene.instantiate()
	get_parent().get_parent().add_child(follower_instance)
	follower_spawned = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$CanvasLayer/Label2.text = str(GlobalCanvasLayer.tricks)
	$CanvasLayer/Label2.scale = Vector2(10+GlobalCanvasLayer.tricks, 10+GlobalCanvasLayer.tricks)
	var shake_intensity = min(GlobalCanvasLayer.tricks, 50)
	var shake_offset = Vector2(rng.randf_range(-shake_intensity/4, shake_intensity/4), rng.randf_range(-shake_intensity, shake_intensity))
	$CanvasLayer/Label2.position = base_position + shake_offset
	
	if GlobalCanvasLayer.tricks < 3:
		$CanvasLayer/Label2.visible = false
		$CanvasLayer/TextureRect.modulate.a = 0
		$CanvasLayer/TextureRect2.modulate.a = 0
		AudioServer.set_bus_volume_db(music_bus_index, 0)
		texture_change = false
	else:
		$CanvasLayer/Label2.visible = true
		
	if GlobalCanvasLayer.tricks > 20:
		$CanvasLayer/Label2.modulate = Color(1, 0, 0)
		$CanvasLayer/TextureRect.modulate.a = min(GlobalCanvasLayer.tricks / 22.0, 1.0)
		
		var random_index = rng.randi_range(0, textures.size() - 1)
		var new_texture = textures[random_index]
		if texture_change == false:  
			$CanvasLayer/TextureRect.texture = new_texture
			texture_change = true
			
			# Spawn follower if texture is Sprite-00062.png
			if new_texture.resource_path == "res://Sprites/Obstacles/2011X/Sprite-00062.png" and not follower_spawned:
				spawn_follower()
			
	elif GlobalCanvasLayer.tricks > 15:
		$CanvasLayer/TextureRect2.modulate.a = min(GlobalCanvasLayer.tricks / 22.0, 1.0)
		var new_volume = max(-GlobalCanvasLayer.tricks * 1.25, -80)
		AudioServer.set_bus_volume_db(music_bus_index, new_volume)
		
	elif GlobalCanvasLayer.tricks > 9:
		$CanvasLayer/Label2.modulate = Color(1, 1, 0) 
	else:
		$CanvasLayer/Label2.modulate = Color(1, 1, 1)
	
	match Test.trick:
		"good":
			$AnimationPlayer.play(mobile_var)
			$Label.text = "GOOD!"
			$Label.modulate = Color(1, 1, 1)
			
	
		"great":
			$AnimationPlayer.play(mobile_var)
			$Label.text = "GREAT!!"
			$Label.modulate = Color(1, 1, 1)
		
		"awesome":
			$AnimationPlayer.play(mobile_var)
			$Label.text = "AWESOME!!!"
			$Label.modulate = Color(1, 1, 0)
		
		"amazing":
			$AnimationPlayer.play(mobile_var)
			$Label.text = "AMAZING!!!!!!"
			$Label.modulate = Color(1, 0, 0)
			
		"outstanding":
			$AnimationPlayer.play(mobile_var)
			$Label.text = "OUTSTANDING!!!"
			$Label.modulate = Color(1, 1, 0)
			
	Test.trick = ""
		
