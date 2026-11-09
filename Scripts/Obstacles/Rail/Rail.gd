extends Path2D

@onready var collision_polygon := $Start/CollisionShape2D # Use CollisionPolygon2D for collision shape

@export var path_width: float = 2.5
@export var grind_speed := 400.0

# Dictionary to track multiple players and their grinding states
var grinding_players: Dictionary = {}
var player_followers: Dictionary = {}
var player_speeds: Dictionary = {}  # Each player has their own grind speed
const RAIL_SPEED_MODIFIER : int = 19
const RAIL_BOOST_MAX := 2000.0   # top speed while boosting on a rail (the game's top speed elsewhere)

func _ready():
	var path_points: PackedVector2Array = curve.get_baked_points()
	var polyline := Geometry2D.offset_polyline(path_points, path_width, Geometry2D.JOIN_MITER, Geometry2D.END_SQUARE)
	collision_polygon.polygon = polyline[0]
	# A rail styled to match the stage (rail_skin.gd); the plain line below is the fallback
	_skinned = preload("res://Scripts/Obstacles/Rail/rail_skin.gd").apply(self)
	queue_redraw()

var _skinned := false

func _draw():
	if _skinned:
		return
	var points = curve.get_baked_points()
	if points.size() < 2:
		return
	
	for i in range(points.size() - 1):
		# Draw line between baked points in local space
		draw_line(points[i], points[i + 1], Color.ALICE_BLUE, 6)

func _physics_process(delta):
	# Process each grinding player
	var players_to_remove = []
	
	for player : Player in grinding_players.keys():
		if grinding_players[player] and player and player.grinding:
			var follower = player_followers[player]
			var player_grind_speed = player_speeds[player]
			
			# Lazy coding, but check if the player is damaged based on invul timer
			# and if so, put them back in grinding animation state
			if !player.invincibity.is_stopped() and !player.is_player_dead:
				player.ap.play("skid")
				
			player.direction = 0
			
			# Increase player grind speed based on direction / motion
			var dir = sign(player_grind_speed)
			var speed_increase = dir * follower.rotation
			var player_base_speed = 350
			
			if sign(follower.rotation) * sign(dir) > 0 and abs(player_grind_speed) < player.ABOSLUTE_MAX_SPEED:
				player_grind_speed += speed_increase * RAIL_SPEED_MODIFIER
				
			if abs(player_grind_speed) < player_base_speed:
				player_grind_speed = player_base_speed * dir
			
			# Boosting along the rail: the same button, meter and numbers as the ground boost
			player_grind_speed = _rail_boost(player, player_grind_speed)
				
			# Set the player's speed so it applies when they jump or exit the rail
			# And store player grind speed
			player_speeds[player] = player_grind_speed
			player.motion.x = player_grind_speed
			
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

## Boost while grinding (ground_boost.gd leaves rails to this): pressing boost
## kicks you to the boost's start speed along the rail, holding it keeps speeding
## you up, and both cost meter like on the ground
func _rail_boost(player, speed: float) -> float:
	var dir := signf(speed) if speed != 0.0 else 1.0
	var boost = _boost_component(player)
	if boost == null:
		# Only characters with a ground boost (Sonic, Metal Sonic, Blaze) boost on rails
		if player.is_boosting:
			player.is_boosting = false
			if player.is_player:
				player.boost_sprite.visible = false
				GlobalCanvasLayer.boost = false
		_rail_attack(player, false)
		return speed
	var start_speed: float = boost.max_speed_startup if boost else 1500.0
	var accel: float = boost.x_speed_increase if boost else 15.0
	var start_cost: float = boost.meter_cost_inital if boost else 5.0
	var cost: float = boost.meter_cost if boost else 0.3
	if player.inp_pressed("airspin") and player.my_meter > 0.0:
		if player.inp_just_pressed("airspin") or not player.is_boosting:
			if player.my_meter >= start_cost:
				if player.is_player:
					player.my_meter -= start_cost
					var sfx = player.find_child("BoostStartaudio", true, false)
					if sfx:
						sfx.play()
					player.boost_sprite.play("shockwave")
					GlobalSignals.emit_signal("camerashake")
				speed = maxf(absf(speed), start_speed) * dir
				player.is_boosting = true
		elif player.is_boosting:
			speed += accel * dir
			if player.is_player:
				player.my_meter = maxf(player.my_meter - cost, 0.0)
	elif player.is_boosting:
		player.is_boosting = false
	if player.is_player:
		player.boost_sprite.visible = player.is_boosting
		GlobalCanvasLayer.boost = player.is_boosting
	_rail_attack(player, player.is_boosting)
	if player.is_boosting:
		speed = clampf(speed, -RAIL_BOOST_MAX, RAIL_BOOST_MAX)
	return speed


## While boosting on a rail your attack box is on, so enemies you hit are knocked
## out (like a spin attack); it goes back off when you stop boosting or leave
func _rail_attack(player, on: bool) -> void:
	var box := player.get_node_or_null("Attackbox") as Area2D
	if box == null:
		return
	if on:
		box.monitorable = true
		box.monitoring = true
		player.set_meta("rail_attack", true)
	elif player.has_meta("rail_attack"):
		player.remove_meta("rail_attack")
		box.set_deferred("monitorable", false)
		box.set_deferred("monitoring", false)


## The character's ground boost (its numbers are used on rails too); null for
## characters without one (everyone but Sonic, Metal Sonic and Blaze)
func _boost_component(player) -> Node:
	for n in player.find_children("*", "", true, false):
		var sc = n.get_script()
		if sc and sc.resource_path.ends_with("ground_boost.gd"):
			return n
	return null


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
	if abs(player.motion.x) > 0:
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
	_rail_attack(player, false)
	
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
