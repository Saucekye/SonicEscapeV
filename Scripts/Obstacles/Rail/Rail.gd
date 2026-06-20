extends Path2D

@export var grind_speed := 400.0
@onready var collision_polygon := $Start/CollisionShape2D # Use CollisionPolygon2D for collision shape

# Dictionary to track multiple players and their grinding states
var grinding_players: Dictionary = {}
var player_followers: Dictionary = {}
var player_speeds: Dictionary = {}  # Each player has their own grind speed
var base_speed = 250
@export var path_width: float = 2.5

func _ready():
	var path_points: PackedVector2Array = curve.get_baked_points()
	var polyline := Geometry2D.offset_polyline(path_points, path_width, Geometry2D.JOIN_MITER, Geometry2D.END_SQUARE)
	collision_polygon.polygon = polyline[0]

func _draw():
	var points = curve.get_baked_points()
	if points.size() < 2:
		return
	
	for i in range(points.size() - 1):
		# Draw line between baked points in local space
		draw_line(points[i], points[i + 1], Color.ALICE_BLUE, 6)

func _physics_process(delta):
	# Process each grinding player
	var players_to_remove = []
	
	for player in grinding_players.keys():
		if grinding_players[player] and player and player.grinding:
			var follower = player_followers[player]
			var player_grind_speed = player_speeds[player]
			
			player.direction = 0
			
			# Check if we're about to go past the ends BEFORE updating progress
			var new_progress = follower.progress + player_grind_speed * delta
			var rail_length = curve.get_baked_length()
			
			if new_progress <= 0 or new_progress >= rail_length:
				print("Player reached end of rail. Progress would be: ", new_progress, " Length: ", rail_length)
				print("Player grinding state before stop: ", player.grinding)
				player.rot = 0
				stop_grind(player)
				players_to_remove.append(player)
				continue
			
			# Only update progress if we're not at the ends
			follower.progress = new_progress
			
			var forward = follower.transform.x.normalized()
			var normal = Vector2(-forward.y, forward.x)
			var offset_distance = -35.0
			
			player.global_position = follower.global_position + normal * offset_distance
			player.rot = follower.rotation
			player.time_elapsed = 80 # fixed typo
		else:
			# Only stop grinding if it was active for this player
			if player in grinding_players and grinding_players[player]:
				stop_grind(player)
				players_to_remove.append(player)
	
	# Clean up players that stopped grinding
	for player in players_to_remove:
		grinding_players.erase(player)

func start_grind(player):
	if not player:
		return
	
	# Create a new PathFollow2D for this player if it doesn't exist
	if not player in player_followers:
		var follower = PathFollow2D.new()
		add_child(follower)
		player_followers[player] = follower
	
	var follower = player_followers[player]
	grinding_players[player] = true
	var player_base_speed = 350
	
	#if player.time_elapsed >= 50:
	player_base_speed = abs(player.motion.x) * 1.05
	
	var sprite = player.get_node_or_null("Sprite2D")
	var direction_sign = 1
	if sprite and sprite.flip_h:
		direction_sign = -1
	
	# Store individual speed for this player
	player_speeds[player] = player_base_speed * direction_sign
	
	# Set follower to closest position on path from player's current position
	follower.progress = curve.get_closest_offset(to_local(player.global_position))
	player.global_position = follower.global_position
	player.direction = 0
	
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("skid")

func stop_grind(player):
	if not player:
		return
	
	print("stop_grind called. Player grinding state: ", player.grinding)
	
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("jump")
	
	var sprite = player.get_node_or_null("Sprite2D")
	var direction_sign = 1
	if sprite and sprite.flip_h:
		direction_sign = -1
	
	var upward_boost = -500
	var launch_speed = 800 * direction_sign
	if abs(player.motion.x) > 800:
		launch_speed = abs(player.motion.x) * direction_sign
	
	# Check grinding state BEFORE setting to false
	if player.grinding:
		print("Launching player with forward momentum")
		var follower = player_followers[player]
		var forward = follower.transform.x.normalized()
		player.motion = forward * launch_speed
		player.motion.y += upward_boost
	else:
		print("Giving player basic jump")
		player.motion.y = player.jump_velocity
		player.motion.y += -100
	
	player.grinding = false
	grinding_players[player] = false
	player.rot = 0
	
	# Clean up the PathFollow2D node for this player
	if player in player_followers:
		player_followers[player].queue_free()
		player_followers.erase(player)

func _on_start_area_entered(area: Area2D) -> void:
	# Detect player entering grind area
	if area.is_in_group("Player"):
		var player = area.get_parent()
		if player and not (player in grinding_players and grinding_players[player]):
			player.grinding = true
			start_grind(player)
