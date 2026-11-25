extends CharacterBody3D
# One player in the Salvage mini game

@export_group("Movement")
@export var walk_speed := 4.2
@export var sprint_speed := 6.6
@export var crouch_speed := 1.8            ## only used under a shelf
@export var jump_speed := 5.2
@export var gravity := 18.0
@export var max_fall_speed := 12.0         ## top falling speed
@export_group("Spindash")
@export var spindash_speed := 9.0          ## launch speed (m/s), plus the next value per rev
@export var spindash_speed_per_rev := 2.0
@export var spindash_max_revs := 5
@export var spindash_slowdown := 4.5       ## how fast the roll slows down
@export_range(-40.0, 6.0) var spindash_volume_db := -16.0   ## how loud the rev and release sounds are
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var rev_sound := "res://Sounds/SonicSFX/rev.MP3"
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var dash_sound := "res://Sounds/SonicSFX/spindash.MP3"
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var jump_sound := "res://Sounds/SonicSFX/Jump.wav"   ## Sonic's jump, from the levels
@export var step_volume_db := -15.0          ## your own footsteps
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var trick_sound := "res://Sounds/SonicSFX/sparklesfx.MP3"   ## an air trick: the same jingle as in the levels
@export_group("Body and camera")
@export var eye_height := 1.0              ## you're short: about the same height as your teammates
@export var crouch_eye_height := 0.55
@export var spindash_eye_height := 0.45
@export var body_height := 1.1
@export var crouch_body_height := 0.6      ## low enough to crawl under a shelf
@export var fov := 80.0                    ## side to side, in a full-screen view
@export var reach := 2.4                   ## how far away you can salvage an item or press a button
const TOP_DOWN_REACH_Y := 1.15   # top-down: the height you reach out at
@export_group("Controls")
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6

var index := 0
var actions := "sv_"        # this player's input actions
var pad := 0                # controller for this player's sticks
var use_mouse := true
var character := ""         # who you are
var head: Node3D
var cam: Camera3D
var view: SubViewport
var hud: Control
var hud_rings: Label
var hud_meter: TextureProgressBar
var hud_items: HBoxContainer      # what you are carrying, under the meter
const ITEM_ICON_SIZE := 40.0       # size of each picture in that row
var prompt: Label
var message: Label
var carried: Array = []
var has_emerald := false     # carrying the Chaos Emerald


# A quick flash over the screen
func flash_screen(color: Color, for_time: float) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, for_time)
	tw.tween_callback(flash.queue_free)
var looking_at: Node3D = null
var escaped := false
var map: Control                # salvage_map.gd
var caught_color := Color(0.25, 0.0, 0.0)   # the flash when a hunter gets you
var caught_fade := 1.2                      # seconds to fade from it to black
var hurt_left := 0.0        # can't be hurt again until this runs out
const HURT_SHOWN := 0.55    # the hurt pose shows until hurt_left drops to this
var knock := Vector3.ZERO   # thrown back by spikes
var knock_left := 0.0
var ragdoll: RigidBody3D    # after dying, your view rides along with your flung body
var shake := 0.0            # camera shake left
var top_down := false       # motion sickness mode
var top_down_height := 11.0
var screen: TextureRect     # where this player's view is drawn
var cross: Label
var vision: Control         # top-down sight
var fog_env: Environment    # this view's own fog, thick inside a foggy area
var dead := false           # caught by a hunter
var rhythm: Node = null     # playing the TV's rhythm game
var reading: Control = null # reading a sign close up
var watching: Node3D        # caught: who you're spectating
var _orbit := Vector2(0.0, -0.3)   # spectating: turn and tilt of the camera around them
var _spectate_wait := 0.0
var _snap := false
var knocked: RigidBody3D     # thrown by a hit you lived through
var grabbed_by: Node3D       # the Spider's got you
var _knock_layer := 1
const BLEND_BACK := 0.3     # seconds for the camera to get back into your eyes after a knockdown
const BLEND_STEPS := 5.0    # in this many jumps
var _blend_from := Transform3D.IDENTITY
var _eye_view: Array = []   # first-person fov, aspect and far, kept while you look from above
var _blend_left := 0.0
var _behind := 0.0          # caught: how far the camera sits back from your flying body
var _dark: ColorRect        # the dark you see once caught
var bob := 0.0
var beats := {}             # your run animations -> when the feet land
var _beat_t := 0.0
var _beat_anim := ""
const TEAMMATE_SCRIPT := preload("res://Scenes/Salvage/salvage_teammate.gd")
var game: Node3D            # salvage.gd
var steps: Array = []       # your character's own footstep sounds
var step_player: AudioStreamPlayer
var step_i := 0
var crouching := false
var small := false          # body shrunk
var hidden := false         # crouched behind or under cover
var sheltered := false      # crouched right under cover
var body_shape: CollisionShape3D
var hud_hidden: Label
var _msg_tween: Tween
var revs := 0               # spindash charge
var spin_speed := 0.0       # > 0 while rolling from a spindash
var eye := eye_height
var sfx: AudioStreamPlayer

# This player's rings
var rings: int:
	get: return Test.rings
	set(v): Test.rings = v


func build(game_node: Node3D, low_res: Vector2i, cull_mask: int) -> void:
	game = game_node
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = body_height
	shape.shape = cap
	shape.position.y = body_height * 0.5
	add_child(shape)
	body_shape = shape
	head = Node3D.new()
	head.position.y = eye_height
	add_child(head)
	view = SubViewport.new()
	view.size = low_res
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.audio_listener_enable_3d = true   # sounds out in the building are heard from your camera
	game.add_child(view)
	cam = Camera3D.new()
	cam.fov = _base_fov()
	cam.near = 0.05
	cam.far = 60
	# Full screen: the fov is side to side
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.cull_mask = cull_mask               # don't draw your own sprite in your own view
	view.add_child(cam)
	cam.current = true
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = spindash_volume_db
	add_child(sfx)


func physics(delta: float) -> void:
	_shake(delta)
	if is_instance_valid(knocked):
		# Thrown: you go where your body goes, the camera watching from behind
		global_position = knocked.global_position - Vector3(0, 0.3, 0)
		if top_down:
			_top_down_cam(global_position)
		elif _behind > 0.0:
			_orbit_look(delta)
			_follow_from_behind(knocked.global_position, _behind, 0.0 if _snap else delta)
			_snap = false
		else:
			cam.global_transform = knocked.global_transform
		return
	if is_instance_valid(grabbed_by) and not dead and not escaped:
		# Dragged along the floor by the Spider
		global_position = grabbed_by.drag_point()
		velocity = Vector3.ZERO
		spin_speed = 0.0
		revs = 0
		crouching = false
		var look := Vector2(_joy(JOY_AXIS_RIGHT_X), _joy(JOY_AXIS_RIGHT_Y))
		if look.length() > 0.2 and not game.menu_open():
			rotate_y(-look.x * stick_sensitivity * delta)
			head.rotation.x = clamp(head.rotation.x - look.y * stick_sensitivity * delta, -1.45, 1.45)
		eye = move_toward(eye, 0.35, delta * 4.0)   # low: on the floor
		head.position.y = eye + randf_range(-0.02, 0.02)
		if top_down:
			_top_down_cam(global_position)
		else:
			cam.global_transform = head.global_transform
		return
	elif grabbed_by != null and not is_instance_valid(grabbed_by):
		grabbed_by = null
	if escaped:
		if dead and _spectate(delta):
			return
		if top_down:
			var at := ragdoll.global_position if ragdoll and is_instance_valid(ragdoll) else global_position
			_top_down_cam(at)
		elif own_death >= 0.0:
			cam.global_transform = head.global_transform * _fall   # down where you stood, not with your body
		elif ragdoll and is_instance_valid(ragdoll):
			if _behind > 0.0:
				_orbit_look(delta)
				_follow_from_behind(ragdoll.global_position, _behind, 0.0 if _snap else delta)
				_snap = false
			else:
				cam.global_transform = ragdoll.global_transform
		else:
			cam.global_transform = head.global_transform
		return
	# Nothing you press counts while the pause menu is open
	var blocked: bool = game.menu_open() or busy()
	# Look: right stick
	var look := Vector2(_joy(JOY_AXIS_RIGHT_X), _joy(JOY_AXIS_RIGHT_Y))
	if top_down:
		# Face where you aim
		if look.length() > 0.3 and not blocked:
			rotation.y = atan2(-look.x, -look.y)
		elif use_mouse and not blocked and not Test.mobile:
			_face_mouse()
	elif look.length() > 0.2 and not blocked:
		var stick_sens: float = stick_sensitivity * Test.display.stick_look   # Settings: Controller Look
		var up: float = -look.y if Test.display.invert_look else look.y
		rotate_y(-look.x * stick_sens * delta)
		head.rotation.x = clamp(head.rotation.x - up * stick_sens * delta, -1.45, 1.45)
	# Move: keys / left stick
	var input := Input.get_vector(actions + "left", actions + "right", actions + "forward", actions + "back")
	var stick := Vector2(_joy(JOY_AXIS_LEFT_X), _joy(JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		input = stick
	if blocked:
		input = Vector2.ZERO
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	if top_down:
		dir = Vector3(input.x, 0, input.y)   # up on the screen is north
		# Nothing aiming
		if input.length() > 0.2 and look.length() <= 0.3 and (not use_mouse or Test.mobile) and spin_speed <= 0.0:
			rotation.y = lerp_angle(rotation.y, atan2(-input.x, -input.y), clampf(delta * 12.0, 0.0, 1.0))
	dir.y = 0
	dir = dir.limit_length(1.0)

	var run: float = Test.speed_scale()
	var speed: float = (sprint_speed if Input.is_action_pressed(actions + "sprint") and not blocked else walk_speed) * run
	var crouch_held := Input.is_action_pressed(actions + "crouch") and not blocked
	var jump_pressed := Input.is_action_just_pressed(actions + "jump") and not blocked
	if spin_speed > 0.0:
		# Rolling from a spindash
		var fwd := -transform.basis.z
		velocity.x = fwd.x * spin_speed
		velocity.z = fwd.z * spin_speed
		spin_speed -= spindash_slowdown * delta
		if is_on_floor() and jump_pressed:
			velocity.y = jump_speed * Test.jump_scale()   # jump out of the roll, keeping the speed
			_sound(jump_sound, 1.0)
		if spin_speed <= walk_speed * run or get_slide_collision_count() > 0 and _hit_wall():
			spin_speed = 0.0
	else:
		# Under a shelf you stay crouched until there's room to stand
		var forced := small and _blocked_above()
		crouching = (crouch_held and is_on_floor()) or forced
		if crouching:
			speed = crouch_speed * run
			# Crouching holds you still, except under something
			if not forced and not _blocked_above():
				dir = Vector3.ZERO
			if crouch_held and jump_pressed and is_on_floor():
				# Rev the spindash
				revs = mini(revs + 1, spindash_max_revs)
				_sound(rev_sound, clampf(revs / 2.0, 1.0, 2.0))
			if revs > 0 and crouch_held:
				dir = Vector3.ZERO   # held in place while revving
		if revs > 0 and not crouch_held:
			# Let go of crouch
			spin_speed = (spindash_speed + spindash_speed_per_rev * revs) * Test.boost_scale()
			revs = 0
			_sound(dash_sound, 1.5)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if is_on_floor() and jump_pressed and not crouching:
			velocity.y = jump_speed * Test.jump_scale()
			_sound(jump_sound, 1.0)
	_trick(blocked)
	hurt_left -= delta
	if knock_left > 0.0:
		knock_left -= delta
		velocity.x = knock.x
		velocity.z = knock.z
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
	_set_small(crouching or spin_speed > 0.0)
	move_and_slide()
	sheltered = crouching and _under_cover()
	hidden = sheltered or (crouching and _near_cover())
	if hud_hidden:
		hud_hidden.visible = hidden
	# Eye height and field of view
	var want_eye := spindash_eye_height if spin_speed > 0.0 else (crouch_eye_height if crouching else eye_height)
	eye = move_toward(eye, want_eye, delta * 4.0)
	if not top_down:
		var kick := 14.0 if spin_speed > 0.0 else 0.0
		cam.fov = lerpf(cam.fov, _base_fov() + kick, clampf(delta * 8.0, 0.0, 1.0))
	if spin_speed <= 0.0 and is_on_floor() and dir.length() > 0.1:
		var before := floori(bob / PI)
		bob += delta * speed * 2.4
		var anim := anim_state()
		if beats.has(anim):
			# In time with your character's run animation
			if anim != _beat_anim:
				_beat_anim = anim
				_beat_t = 0.0
			var length: float = beats[anim][0]
			var from := fmod(_beat_t, length) / length
			_beat_t += delta
			var hit = TEAMMATE_SCRIPT.beat_between(beats[anim][1], from, fmod(_beat_t, length) / length)
			if hit != null and not crouching:
				_footstep(hit[1])
		elif floori(bob / PI) != before and not crouching:
			_footstep()   # one step each time the head bob dips
	else:
		_beat_anim = ""
	head.position.y = eye + sin(bob) * 0.03
	if revs > 0:
		head.position.y += randf_range(-0.01, 0.01)   # shaking while it revs
	if top_down:
		_top_down_cam(global_position)
	elif _blend_left > 0.0:
		# Just up from a knockdown
		_blend_left = maxf(_blend_left - delta, 0.0)
		var k := 1.0 - _blend_left / BLEND_BACK
		k = floorf(k * BLEND_STEPS) / BLEND_STEPS
		k = 1.0 - pow(1.0 - k, 3.0)
		cam.global_transform = _blend_from.interpolate_with(head.global_transform, k)
	else:
		cam.global_transform = head.global_transform
	if global_position.y < -20.0:
		# Fell out of the maze
		if not dead and not escaped:
			game.hazard_kill(self, Vector3(0, -3, 0))
		if global_position.y < -20.0:
			global_position.y = -20.0
			velocity = Vector3.ZERO
	_update_interact()
	if InputMap.has_action(actions + "stun") and Input.is_action_just_pressed(actions + "stun") and not busy() and not game.menu_open():
		game.use_stun(self)


# Shrink the body to crawl under things, or stand back up
func _set_small(on: bool) -> void:
	if on == small or body_shape == null:
		return
	if not on and _blocked_above():
		crouching = true   # no room to stand
		return
	small = on
	var h := crouch_body_height if on else body_height
	(body_shape.shape as CapsuleShape3D).height = maxf(h, 0.6)
	body_shape.position.y = maxf(h, 0.6) * 0.5


# Would standing up hit something?
func _blocked_above() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = body_height
	q.shape = cap
	q.transform = Transform3D(Basis(), global_position + Vector3(0, body_height * 0.5 + 0.03, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# Something to hide under
func _under_cover() -> bool:
	var from := global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 1.6, 0), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider.is_in_group("salvage_cover")


# Something to hide behind
func _near_cover() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	q.shape = sphere
	q.transform = Transform3D(Basis(), global_position + Vector3(0, 0.45, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if r.collider and r.collider.is_in_group("salvage_cover"):
			return true
	return false


# Rolled into a wall head-on
func _hit_wall() -> bool:
	var fwd := -transform.basis.z
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.5 and n.dot(fwd) < -0.7:
			return true
	return false


func _sound(path: String, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	sfx.stream = load(path)
	sfx.pitch_scale = pitch
	sfx.play()


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _shake(delta: float) -> void:
	shake = maxf(shake - delta * 1.4, 0.0)
	var s: float = shake * minf(shake, 1.0) * Test.display.screen_shake   # gentle when it's small, violent close up
	cam.h_offset = randf_range(-1.0, 1.0) * s * 0.2
	cam.v_offset = randf_range(-1.0, 1.0) * s * 0.2
	if s > 0.0:
		cam.rotation.z = randf_range(-1.0, 1.0) * s * 0.05   # rocked side to side too
	elif cam.rotation.z != 0.0 and not escaped:
		cam.rotation.z = 0.0


# Spikes or a blast got you
func hurt(from: Vector3, push: float, up := 4.5) -> void:
	hurt_left = 1.2
	var away := Vector3(global_position.x - from.x, 0, global_position.z - from.z)
	if away.length() < 0.05:
		away = -Vector3(velocity.x, 0, velocity.z)
	knock = away.normalized() * push
	knock_left = 0.35
	velocity.y = up
	spin_speed = 0.0
	revs = 0
	_sound("res://Sounds/SonicSFX/Spiked.wav", 1.0)


func _footstep(sound: AudioStream = null) -> void:
	if step_player == null:
		return
	step_player.stream = sound if sound != null else steps[step_i % steps.size()]
	step_player.pitch_scale = randf_range(0.94, 1.06)
	step_player.play()
	step_i += 1
	game.echo_step(self)   # a Bracken stalking you walks in step


func _base_fov() -> float:
	var wider: float = Test.display.fov / 80.0
	return fov * wider


# What your character is doing, for its sprite
func anim_state() -> String:
	if hurt_left > HURT_SHOWN:
		return "hurt"   # knocked back by spikes, like getting hit in the levels
	if spin_speed > 0.0:
		return "ball"
	if revs > 0:
		return "revup"
	if crouching:
		return "Crouch"
	if not is_on_floor():
		return trick_pose if trick_pose != "" else "jump"
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > walk_speed * Test.speed_scale() + 0.5:
		return "Dash"
	if flat > 0.3:
		return "run"
	return "stance"


# Air tricks, like in the levels
var trick_pose := ""
var _trick_i := 0
const TRICKS := ["trick1", "trick2", "trick3", "trick4"]

func _trick(blocked: bool) -> void:
	if is_on_floor():
		trick_pose = ""
		return
	if blocked or spin_speed > 0.0 or not Input.is_action_just_pressed(actions + "trick"):
		return
	trick_pose = TRICKS[_trick_i % TRICKS.size()]
	_trick_i += 1
	_sound(trick_sound, 1.0)


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.3


# Caught: after a moment, watch someone still alive from just behind them
func _spectate(delta: float) -> bool:
	if _spectate_wait > 0.0:
		_spectate_wait -= delta
		return false
	var list: Array = game.spectate_targets(self)
	if list.is_empty():
		if watching != null:
			watching = null
			_fade_dark(0.96)   # nobody left to watch
		return false
	var blocked: bool = game.menu_open()
	var next := not blocked and (Input.is_action_just_pressed(actions + "jump") or Input.is_action_just_pressed(actions + "interact"))
	if not is_instance_valid(watching) or not list.has(watching) or next:
		var first := watching == null
		watching = list[(list.find(watching) + 1) % list.size()] if is_instance_valid(watching) else list[0]
		if first:
			_fade_dark(0.0)
			_orbit = Vector2(watching.global_rotation.y, -0.3)
	if not blocked:
		_orbit_look(delta)
	if top_down:
		_top_down_cam(watching.global_position)
		return true
	_follow_from_behind(watching.global_position + Vector3.UP * 0.8, game.spectate_distance, 0.0)
	return true


# Caught: pull the camera back from your own body as it goes flying
func third_person(distance: float) -> void:
	_behind = distance
	_orbit = Vector2(rotation.y, -0.45)
	_snap = true   # straight there, not sliding out of your own head


func _orbit_look(delta: float) -> void:
	var look := Vector2(_joy(JOY_AXIS_RIGHT_X), _joy(JOY_AXIS_RIGHT_Y))
	if look.length() > 0.2:
		_orbit_by(look * game.spectate_turn_speed * delta)


# The camera a little behind and above something, looking at it
func _follow_from_behind(at: Vector3, distance: float, delta: float) -> void:
	var want := _clear_view(at, _orbit.y, distance)
	if want.distance_to(at) < distance * 0.5:
		# A wall right behind
		var above := _clear_view(at, -1.25, distance)
		if above.distance_to(at) > want.distance_to(at):
			want = above
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 8.0, 0.0, 1.0)) if delta > 0.0 else want
	if not cam.global_position.is_equal_approx(at):
		cam.look_at(at)


# A hit you lived through
func knock_down(body: RigidBody3D, distance: float) -> void:
	knocked = body
	_knock_layer = collision_layer
	collision_layer = 0   # out of the way of your own body
	velocity = Vector3.ZERO
	knock_left = 0.0
	spin_speed = 0.0
	revs = 0
	if distance > 0.0:
		third_person(distance)


# Back on your feet where your body ended up, facing where the camera was
func get_up() -> void:
	var at := knocked.global_position
	knocked = null
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	global_position = hit.position if not hit.is_empty() else at - Vector3(0, 0.3, 0)
	collision_layer = _knock_layer
	velocity = Vector3.ZERO
	if _behind > 0.0:
		rotation.y = _orbit.x
		head.rotation.x = 0.0
	_behind = 0.0
	# Back into your eyes in a few quick steps rather than a cut
	if not top_down:
		_blend_from = cam.global_transform
		_blend_left = BLEND_BACK


# Where the camera can sit, this far back from something at this tilt
func _clear_view(at: Vector3, tilt: float, distance: float) -> Vector3:
	var back := Basis.from_euler(Vector3(tilt, _orbit.x, 0.0)) * Vector3.BACK
	var want: Vector3 = at + back * distance
	var q := PhysicsRayQueryParameters3D.create(at, want, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = at + (hit.position - at) * 0.85
	return want


func orbit_mouse(relative: Vector2) -> void:
	if is_instance_valid(watching) or _behind > 0.0:
		_orbit_by(relative * mouse_sensitivity * Test.salvage_look)


func _orbit_by(by: Vector2) -> void:
	_orbit.x -= by.x
	_orbit.y = clampf(_orbit.y - by.y, -1.3, 0.5)


func _fade_dark(to: float) -> void:
	if is_instance_valid(_dark):
		_dark.create_tween().tween_property(_dark, "color:a", to, 0.6)


func look_mouse(relative: Vector2) -> void:
	var sens := mouse_sensitivity * Test.salvage_look   # Settings: Mouse Look
	rotate_y(-relative.x * sens)
	if not top_down:
		var up: float = -relative.y if Test.display.invert_look else relative.y
		head.rotation.x = clamp(head.rotation.x - up * sens, -1.45, 1.45)


# Motion sickness mode
func use_top_down(height: float, fov: float) -> void:
	if not top_down:
		_eye_view = [cam.fov, cam.keep_aspect, cam.far]
	top_down = true
	top_down_height = height
	cam.fov = fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = height + 20.0
	head.rotation.x = 0.0
	if cross:
		cross.visible = false


# Back to seeing through your own eyes
func use_first_person() -> void:
	if not top_down:
		return
	top_down = false
	if not _eye_view.is_empty():
		cam.fov = _eye_view[0]
		cam.keep_aspect = _eye_view[1]
		cam.far = _eye_view[2]
	if cross:
		cross.visible = true
	cam.global_transform = head.global_transform


func _top_down_cam(at: Vector3) -> void:
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0, 0)), at + Vector3(0, top_down_height, 0))


# Turn to face the mouse pointer, on the floor
func _face_mouse() -> void:
	if screen == null or not screen.is_visible_in_tree():
		return
	var m := screen.get_local_mouse_position()
	if screen.size.x <= 0.0:
		return
	var px := m / screen.size * Vector2(view.size)
	var from := cam.project_ray_origin(px)
	var normal := cam.project_ray_normal(px)
	if absf(normal.y) < 0.01:
		return
	var t := (global_position.y + 1.0 - from.y) / normal.y
	var on_floor := from + normal * t
	var to := on_floor - global_position
	if Vector2(to.x, to.z).length() > 0.3:
		rotation.y = atan2(-to.x, -to.z)


func _joy(axis: JoyAxis) -> float:
	return Input.get_joy_axis(pad, axis) if pad >= 0 else 0.0


func _update_interact() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var aims: Array[Vector3] = [-cam.global_transform.basis.z * reach]
	if top_down:
		# Nobody aims up or down from above
		from = global_position + Vector3.UP * TOP_DOWN_REACH_Y
		var ahead := -global_transform.basis.z
		aims = [ahead * (reach + 0.3), (ahead * cos(0.6) + Vector3.DOWN * sin(0.6)) * (reach + 0.6)]
	looking_at = null
	if busy():
		aims = []
	for aim in aims:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + aim, 2))
		if hit and (hit.collider.has_meta("item") or hit.collider.has_meta("emerald") or hit.collider.has_meta("emerald_case") or hit.collider.has_meta("button") or hit.collider.has_meta("latch") or hit.collider.has_meta("miku") or hit.collider.has_meta("sign")):
			looking_at = hit.collider
			break
	# From above it's hard to aim at the ESCAPE button
	if top_down and not busy() and game.in_exit_car(global_position) and game.exit_button() and not game.emerald_taken \
			and not (looking_at and looking_at.has_meta("emerald")):
		looking_at = game.exit_button()
	if reading != null:
		prompt.text = ""
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			_close_sign()
	elif looking_at and looking_at.has_meta("sign"):
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + "Read"
		prompt.modulate = Color(1, 1, 1)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			_open_sign(looking_at.get_meta("sign"))
	elif looking_at and looking_at.has_meta("latch"):
		# A fog latch: pull it to clear that area's fog
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		var pulled: bool = game.latch_pulled(looking_at)
		prompt.text = "" if pulled else key + "Pull"
		prompt.modulate = Color(1, 1, 1)
		if not pulled and Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.pull_latch(looking_at)
	elif looking_at and looking_at.has_meta("miku"):
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + "Follow"
		prompt.modulate = Color(0.55, 1.0, 0.95)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.take_miku(self, looking_at)
	elif looking_at and looking_at.has_meta("emerald_case") and is_instance_valid(game.emerald_node):
		looking_at = game.emerald_node
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + ("Take the Super Emerald" if game.is_super_emerald() else "Take the Chaos Emerald")
		prompt.modulate = Color(0.45, 1.0, 0.5)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.take_emerald(self)
	elif looking_at and looking_at.has_meta("emerald_case"):
		# The empty case
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.modulate = Color(1, 0.5, 0.45)
		if has_emerald and game.can_put_back():
			prompt.text = key + "Put it back"
			if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
				game.put_emerald_back(self)
		else:
			prompt.text = ""
	elif looking_at and looking_at.has_meta("emerald"):
		# The Chaos Emerald
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + ("Take the Super Emerald" if game.is_super_emerald() else "Take the Chaos Emerald")
		prompt.modulate = Color(0.45, 1.0, 0.5)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.take_emerald(self)
	elif looking_at and looking_at.has_meta("button") and game.emerald_taken:
		# Took the emerald
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.modulate = Color(1, 0.5, 0.45)
		if has_emerald and game.can_put_back():
			prompt.text = key + "Put it back"
			if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
				game.put_emerald_back(self)
		else:
			prompt.text = "Too late"
			if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
				game.play_dead_button()
	elif looking_at and looking_at.has_meta("button"):
		# The exit elevator's ESCAPE button
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = "" if game.departing else key + "Press ESCAPE"
		prompt.modulate = Color(1, 0.5, 0.45)
		if not game.departing and Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.press_escape(self)
	elif looking_at:
		var kind: Array = looking_at.get_meta("item")
		var cost: int = kind[1]
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		var does: String = kind[8] if kind.size() > 8 else kind[0]   # what it does, not what it's called
		if cost == 0:
			prompt.text = key + does
			prompt.modulate = Color(1, 1, 1)
		elif rings >= cost:
			prompt.text = "%s%s  -  %d rings" % [key, does, cost]
			prompt.modulate = Color(1, 1, 1)
		else:
			prompt.text = "%s  -  needs %d rings" % [does, cost]
			prompt.modulate = Color(1, 0.45, 0.4)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.try_salvage(self, looking_at)
	elif busy():
		prompt.text = ""
	elif game.can_chaos_control(self):
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + "Chaos Control"
		prompt.modulate = Color(0.45, 1.0, 0.5)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.chaos_control(self)
	elif game.near_tv(self):
		var key := "" if Test.mobile else ("[E] " if use_mouse else "[X] ")
		prompt.text = key + "Play"
		prompt.modulate = Color(1.0, 0.8, 0.35)
		if Input.is_action_just_pressed(actions + "interact") and not game.menu_open():
			game.start_rhythm(self)
	else:
		prompt.text = ""
	if hud_rings:
		hud_rings.text = str(rings).pad_zeros(3)
		var ring_ap := hud_rings.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ring_ap:
			var want := "Low" if rings <= 0 else "RESET"
			if ring_ap.current_animation != want and ring_ap.has_animation(want):
				ring_ap.play(want)
	if hud_meter:
		hud_meter.max_value = Test.maxmeter
		hud_meter.value = Test.meter


# Busy with something on screen
func busy() -> bool:
	return rhythm != null or reading != null


# A sign up close
func _open_sign(page: Array) -> void:
	if hud == null:
		return
	reading = ColorRect.new()
	(reading as ColorRect).color = Color(0.02, 0.02, 0.03, 0.85)
	reading.size = hud.size
	reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px: float = hud.size.y
	var title := _label(int(px * 0.07), HORIZONTAL_ALIGNMENT_CENTER)
	title.text = page[0]
	title.modulate = Color(1.0, 0.35, 0.3)
	title.position = Vector2(0, px * 0.08)
	title.size = Vector2(hud.size.x, px * 0.1)
	reading.add_child(title)
	var body := _label(int(px * 0.04), HORIZONTAL_ALIGNMENT_CENTER)
	body.text = page[1]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(hud.size.x * 0.1, px * 0.22)
	body.size = Vector2(hud.size.x * 0.8, px * 0.7)
	reading.add_child(body)
	hud.add_child(reading)
	_sign_opened = Engine.get_process_frames()


var _sign_opened := 0
func _close_sign() -> void:
	if reading == null or Engine.get_process_frames() == _sign_opened:
		return
	reading.queue_free()
	reading = null


# HUD, inside this player's half of the screen
func build_hud(area: Control, tag: String, tag_color: Color) -> void:
	hud = area
	_add_icon_panel()
	hud_hidden = _label(22, HORIZONTAL_ALIGNMENT_LEFT)
	hud_hidden.text = "HIDDEN"
	hud_hidden.modulate = Color(0.55, 0.8, 1.0)
	hud_hidden.position = Vector2(250, 22)
	hud_hidden.visible = false
	hud.add_child(hud_hidden)
	if tag != "":
		var t := _label(30, HORIZONTAL_ALIGNMENT_RIGHT)
		t.text = tag
		t.modulate = tag_color
		t.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		t.position = Vector2(-140, 14)
		t.size = Vector2(110, 40)
		hud.add_child(t)
	cross = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(20, 18)
	cross.size = Vector2(40, 36)
	hud.add_child(cross)
	prompt = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.size = Vector2(900, 40)
	prompt.position = Vector2(-450, -90)
	hud.add_child(prompt)
	message = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message.size = Vector2(1000, 100)
	message.position = Vector2(-500, 60)
	hud.add_child(message)


# The game's own character icon panel
func _add_icon_panel() -> void:
	var ui: Node = (load("res://Scenes/Level/UIGAME.tscn") as PackedScene).instantiate()
	for part in ["Sprite2D", "Sprite2Dicon", "Label", "AnimationPlayer"]:
		var n := ui.get_node_or_null(part)
		if n == null:
			continue
		ui.remove_child(n)
		n.owner = null
		_strip(n)
		hud.add_child(n)
	ui.free()
	var bg := hud.get_node_or_null("Sprite2D") as Sprite2D
	var icon := hud.get_node_or_null("Sprite2Dicon") as Sprite2D
	hud_rings = hud.get_node_or_null("Label") as Label
	if bg:
		# Only the panel and its meter bar
		for child in bg.get_children():
			if child.name != "TextureProgressBar":
				child.free()
		hud_meter = bg.get_node_or_null("TextureProgressBar") as TextureProgressBar
	# Your character's portrait and panel
	var scene := Content.character_scene(character)
	if scene:
		var c: Node = scene.instantiate()
		if icon and c.get("icon_character"):
			icon.texture = c.icon_character
		if bg and c.get("icon_background"):
			bg.texture = c.icon_background
		steps = TEAMMATE_SCRIPT.step_sounds(c)
		beats = TEAMMATE_SCRIPT.step_beats(c)
		c.free()
	if not steps.is_empty():
		step_player = AudioStreamPlayer.new()
		step_player.bus = preload("res://Scenes/Salvage/salvage_teammate.gd").echo_bus()
		step_player.volume_db = step_volume_db
		add_child(step_player)
	# Top-left, exactly where it sits in the levels Above the 3D view
	for n in [bg, icon, hud_rings]:
		if n:
			n.z_index = 3
	if bg:
		bg.position = Vector2(99.7, 69.7)
		bg.scale = Vector2(3, 3)
	if icon:
		icon.position = Vector2(80, 45)
		icon.scale = Vector2(0.1364, 0.1456)
	if hud_rings:
		hud_rings.position = Vector2(52, 79)
		hud_rings.scale = Vector2(2.5, 2.5)
	var ap := hud.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation("play"):
		ap.play("play")   # the panel's own animated background
	# The items you have picked up, in a row under the meter
	hud_items = HBoxContainer.new()
	hud_items.name = "Items"
	hud_items.position = Vector2(36, 150)
	hud_items.add_theme_constant_override("separation", 6)
	hud_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_items.z_index = 3
	hud.add_child(hud_items)


# An item you just picked up
func add_item_icon(tex: Texture2D) -> void:
	if hud_items == null or tex == null:
		return
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	hud_items.add_child(holder)
	icon.scale = Vector2(1.8, 1.8)
	var t := icon.create_tween()
	t.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A hunter got you
func jumpscare(tex: Texture2D, sound: String, hold: float, flash: float, linger: float, aim := 0.0) -> void:
	if hud == null or tex == null:
		return
	var screen := _scare_layer()
	var view := hud.size
	_scaring = true
	var face := TextureRect.new()
	face.texture = tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right up in your face
	var k: float = game.jumpscare_closeness
	var w := maxf(view.x * 1.15 * k, view.y * 1.5 * k * tex.get_width() / float(tex.get_height()))
	face.size = Vector2(w, w * tex.get_height() / float(tex.get_width()))
	var rest := Vector2((view.x - face.size.x) * 0.5, -face.size.y * (0.02 + aim) - view.y * 0.04)
	face.pivot_offset = Vector2(face.size.x * 0.5, view.y * 0.5 - rest.y)
	face.position = rest + Vector2(0, view.y * 0.6)
	face.scale = Vector2(0.45, 0.45)
	if game.jumpscare_black:
		# Nothing behind it but black
		var back := ColorRect.new()
		back.color = Color.BLACK
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(back)
	screen.add_child(face)
	var red := ColorRect.new()
	red.color = Color(1, 0, 0, 0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(red)
	var t := screen.create_tween()
	# Up from below and into your face
	t.tween_property(face, "position", rest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(face, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Shaking there
	t.tween_method(func(f: float):
		var jolt: float = view.x * game.jumpscare_shake
		face.position = rest + _wild(f * hold, view) + Vector2(randf_range(-jolt, jolt), randf_range(-jolt, jolt))
		face.rotation = randf_range(-0.03, 0.03)
		face.scale = Vector2.ONE * (1.0 + 0.04 * sin(f * hold * game.jumpscare_shake_speed)), 0.0, 1.0, hold)
	# Red
	t.tween_property(red, "color:a", 0.55, 0.05)
	t.tween_callback(func():
		face.queue_free()
		red.color = Color.RED)
	t.tween_interval(flash)
	# The red fades into the dark
	t.tween_callback(func():
		_scaring = false
		if _game_over:
			_game_over_text(screen))
	t.tween_property(red, "color", Color(0.3, 0.0, 0.0), 0.5)
	t.tween_property(red, "color", Color.BLACK, linger).set_ease(Tween.EASE_IN)
	# Then back to the dark you watch from
	t.tween_callback(func():
		if not _game_over:
			for c in screen.get_children():
				c.create_tween().tween_property(c, "modulate:a", 0.0, 0.8).finished.connect(c.queue_free))
	if ResourceLoader.exists(sound):
		var snd := AudioStreamPlayer.new()
		snd.stream = load(sound)
		snd.volume_db = game.jumpscare_volume_db   # loud
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)


# Everyone's been caught
func show_game_over() -> void:
	if hud == null or _game_over:
		return
	_game_over = true

	(func():
		if not _scaring:
			_game_over_text(_scare_layer())).call_deferred()


func _game_over_text(screen: Control) -> void:
	var label := Label.new()
	label.text = "GAME OVER"
	label.add_theme_font_override("font", GAME_OVER_FONT)
	label.add_theme_font_size_override("font_size", int(hud.size.y * 0.16))
	label.add_theme_color_override("font_color", Color(1, 0.05, 0.05))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.z_index = 2
	screen.add_child(label)
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.6)


# On the way out
func show_result(made_it: bool) -> void:
	if hud == null:
		return
	var screen := _scare_layer()
	var label := Label.new()
	label.text = "ESCAPED" if made_it else "DIDN'T ESCAPE"
	label.add_theme_font_override("font", GAME_OVER_FONT)
	label.add_theme_font_size_override("font_size", int(hud.size.y * (0.08 if _game_over else 0.12)))
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92) if made_it else Color(0.75, 0.1, 0.1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _game_over:
		label.offset_top = hud.size.y * 0.3   # under GAME OVER
		label.offset_bottom = hud.size.y * 0.3
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.z_index = 2
	screen.add_child(label)
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.6)


const GAME_OVER_FONT := preload("res://Fonts/diest64.ttf")
var _scare: Control
var _scaring := false            # a jumpscare is still in your face
var _game_over := false


# Everything above the HUD that the jumpscare and GAME OVER draw on
func _scare_layer() -> Control:
	if not is_instance_valid(_scare):
		_scare = Control.new()
		_scare.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scare.clip_contents = true
		hud.add_child(_scare)
	hud.move_child(_scare, -1)
	return _scare


func remove_emerald_icon() -> void:
	if hud_items:
		for c in hud_items.get_children():
			if c.has_meta("emerald"):
				c.queue_free()


func clear_item_icons() -> void:
	if hud_items:
		for c in hud_items.get_children():
			c.queue_free()


# Copies don't need the level HUD's scripts
func _strip(n: Node) -> void:
	if not (n is AnimationPlayer):
		n.set_script(null)
	for c in n.get_children():
		_strip(c)


func show_message(text: String, seconds: float) -> void:
	message.text = text
	message.modulate.a = 1.0
	if _msg_tween:
		_msg_tween.kill()   # a new message replaces the old one's fade-out
	_msg_tween = message.create_tween()
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(message, "modulate:a", 0.0, 0.6)


# Fade out the message now, if it's still this one
func hide_message(text: String) -> void:
	if message.text == text and message.modulate.a > 0.0:
		show_message(text, 0.0)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


# Slender Man's static over your view
var _static: ColorRect
const STATIC_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 3.0);
	float n = h(px + floor(TIME * 30.0) * vec2(7.13, 3.31));
	float a = amount * amount * 0.85 + amount * 0.1;
	COLOR = vec4(vec3(n), a * (0.55 + 0.45 * n));
}
"""

func set_static(a: float) -> void:
	if dead:
		a = 0.0
	if _static == null:
		if a <= 0.001 or hud == null:
			return
		_static = ColorRect.new()
		_static.set_anchors_preset(Control.PRESET_FULL_RECT)
		_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = STATIC_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_static.material = mat
		hud.add_child(_static)
		hud.move_child(_static, 1)
	_static.visible = a > 0.001
	(_static.material as ShaderMaterial).set_shader_parameter("amount", a)
	_static_hiss(a)


# The hiss that goes with it
var _hiss: AudioStreamPlayer
func _static_hiss(a: float) -> void:
	if _hiss == null:
		if a <= 0.001 or game.slender_static_sound == null:
			return
		_hiss = AudioStreamPlayer.new()
		var s: AudioStream = game.slender_static_sound.duplicate()
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_hiss.stream = s
		_hiss.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(_hiss)
	if a <= 0.001:
		_hiss.stop()
		return
	_hiss.volume_db = linear_to_db(pow(a, 1.3) * 1.2)
	if not _hiss.playing:
		_hiss.play()


# Tails Doll got you
var _ducked := {}   # bus -> its volume before
func still_scare(tex: Texture2D, sound: String, cut: float, hold: float, quiet: float) -> void:
	if hud == null:
		return
	_scaring = true
	_spectate_wait = maxf(_spectate_wait, hold + 1.4)
	var screen := _scare_layer()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var face := TextureRect.new()
	face.texture = tex
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(face)
	_duck_all(quiet)
	var snd: AudioStreamPlayer = null
	if ResourceLoader.exists(sound):
		snd = AudioStreamPlayer.new()
		snd.stream = load(sound)
		snd.bus = "Master"   # not ducked with everything else
		snd.volume_db = game.jumpscare_volume_db
		add_child(snd)
		snd.play()
	var t := screen.create_tween()
	t.tween_interval(cut)
	t.tween_callback(func():
		if is_instance_valid(snd):
			snd.queue_free())   # cut off dead
	t.tween_interval(maxf(hold - cut, 0.0))
	t.tween_callback(func():
		face.queue_free()   # straight to black
		_scaring = false
		if _game_over:
			_game_over_text(screen))
	t.tween_interval(0.6)
	t.tween_callback(func():
		_unduck(0.8)
		if not _game_over:
			back.create_tween().tween_property(back, "modulate:a", 0.0, 0.8).finished.connect(back.queue_free))


# A jumpscare that moves
func anim_scare(frames: Array, fps: float, sound: String, quiet: float) -> void:
	if hud == null or frames.is_empty():
		return
	_scaring = true
	var length := frames.size() / fps
	_spectate_wait = maxf(_spectate_wait, length + 1.4)
	var screen := _scare_layer()
	var view := hud.size
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var face := TextureRect.new()
	face.texture = frames[0]
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = view * 1.12   # a little past the edges, room to shake
	face.position = -view * 0.06
	face.pivot_offset = view * 0.56
	screen.add_child(face)
	_duck_all(quiet)
	var snd: AudioStreamPlayer = null
	if ResourceLoader.exists(sound):
		snd = AudioStreamPlayer.new()
		snd.stream = load(sound)
		snd.bus = "Master"
		snd.volume_db = game.jumpscare_volume_db
		add_child(snd)
		snd.play()
	var state := {"f": 0.0, "hold": 0.0}
	var t := screen.create_tween()
	t.tween_method(func(time: float):
		if not is_instance_valid(face):
			return
		# Stutter: now and then a frame sticks, or jerks back a frame or two
		if state.hold > 0.0:
			state.hold -= 1.0 / 60.0
		else:
			state.f = time * fps
			if randf() < 0.04:
				state.hold = randf_range(0.06, 0.18)
			elif randf() < 0.05:
				state.f = maxf(state.f - randf_range(1.0, 3.0), 0.0)
		face.texture = frames[clampi(int(state.f), 0, frames.size() - 1)]
		# Shaking, and lurching closer in jolts once it's on you
		var into := clampf((time - 0.5) / 0.8, 0.0, 1.0)
		var jolt: float = view.x * (0.006 + game.jumpscare_shake * 1.2 * into)
		face.position = -view * 0.06 + _wild(time, view) * into + Vector2(randf_range(-jolt, jolt), randf_range(-jolt, jolt))
		face.rotation = randf_range(-0.02, 0.02) * into
		var lurch: float = 1.0 + 0.18 * into + 0.03 * into * sin(time * game.jumpscare_shake_speed) + (0.06 if randf() < 0.08 * into else 0.0)
		face.scale = Vector2.ONE * lurch, 0.0, length, length)
	t.tween_callback(func():
		face.queue_free()   # straight to black
		if is_instance_valid(snd):
			snd.queue_free()
		_scaring = false
		if _game_over:
			_game_over_text(screen))
	t.tween_interval(0.6)
	t.tween_callback(func():
		_unduck(0.8)
		if not _game_over:
			back.create_tween().tween_property(back, "modulate:a", 0.0, 0.8).finished.connect(back.queue_free))


# The 2011X jumpscare's thrash
const WILD_SPOTS := [Vector2(0.0, 0.0), Vector2(-0.021, 0.089), Vector2(0.019, 0.122)]

func _wild(time: float, view: Vector2) -> Vector2:
	var w: float = game.jumpscare_wild
	if w <= 0.0:
		return Vector2.ZERO
	var ph := fmod(time * 15.0, 3.0)
	var i := int(ph)
	var a: Vector2 = WILD_SPOTS[i]
	var b: Vector2 = WILD_SPOTS[(i + 1) % 3]
	var at := a.lerp(b, ph - i)
	return Vector2(at.x * view.x, at.y * view.y) * w


func _duck_all(quiet: float) -> void:
	for bus in ["SFX", "Music"]:
		var i := AudioServer.get_bus_index(bus)
		if i == -1 or _ducked.has(bus):
			continue
		_ducked[bus] = AudioServer.get_bus_volume_db(i)
		AudioServer.set_bus_volume_db(i, _ducked[bus] + linear_to_db(maxf(quiet, 0.0001)))


func _unduck(over: float) -> void:
	for bus in _ducked.keys():
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var to: float = _ducked[bus]
		var from := AudioServer.get_bus_volume_db(i)
		get_tree().create_tween().tween_method(func(v: float): AudioServer.set_bus_volume_db(i, v), from, to, over)
	_ducked.clear()


func _exit_tree() -> void:

	for bus in _ducked.keys():
		var i := AudioServer.get_bus_index(bus)
		if i != -1:
			AudioServer.set_bus_volume_db(i, _ducked[bus])
	_ducked.clear()


# The Bracken got you
func neck_snap(sound: AudioStream, black_after: float, tex: Texture2D, crack_at: float) -> void:
	if hud == null:
		return
	_scaring = true
	var screen := _scare_layer()
	var view := hud.size
	var side := 1.0 if randf() < 0.5 else -1.0
	# It, right up close, dim in the dark
	var face := TextureRect.new()
	if tex:
		face.texture = tex
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := view.y * 1.6 * tex.get_width() / float(tex.get_height())
		face.size = Vector2(w, view.y * 1.6)
		face.modulate = Color(0.55, 0.55, 0.55, 0.0)
		screen.add_child(face)
	var rest := Vector2((view.x - face.size.x) * 0.5, -view.y * 0.12)
	face.position = rest + Vector2(0, view.y * 0.25)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dark)
	var t := screen.create_tween()
	# It looms in, and grabs your head
	t.tween_property(face, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(face, "position", rest, minf(crack_at, 0.3)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_method(func(f: float):
		_fall = Transform3D(Basis.from_euler(Vector3(0.05 * f, -side * 0.12 * f, 0.0)), Vector3.ZERO), 0.0, 1.0, crack_at)
	# Crack: wrenched round, hard
	t.tween_method(func(f: float):
		_fall = Transform3D(Basis.from_euler(Vector3(0.05 - 0.3 * f, side * (-0.12 + 1.5 * f), side * 0.55 * f)), Vector3.ZERO)
		face.position = rest + Vector2(-side * view.x * 1.1 * f, view.y * 0.1 * f), 0.0, 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(dark, "color:a", 0.35, 0.16)
	# Your head lolls, everything sinks and goes dark
	var loll := maxf(black_after - crack_at - 0.16, 0.2)
	t.tween_method(func(f: float):
		_fall = Transform3D(Basis.from_euler(Vector3(-0.25 - 0.55 * f, side * (1.38 + 0.15 * f), side * (0.55 + 0.35 * f))), Vector3(0, -0.9 * f * f, 0)), 0.0, 1.0, loll).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(dark, "color:a", 0.8, loll).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		face.queue_free()
		dark.color = Color.BLACK
		_scaring = false
		if _game_over:
			_game_over_text(screen))
	t.tween_interval(1.5)
	t.tween_callback(func():
		if not _game_over:
			dark.create_tween().tween_property(dark, "modulate:a", 0.0, 0.8).finished.connect(dark.queue_free))
	if sound:
		var snd := AudioStreamPlayer.new()
		snd.stream = sound
		snd.volume_db = game.jumpscare_volume_db
		snd.bus = "Master"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)


# Slender Man got you
const DEATH_STATIC_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float bright = 0.6;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 3.0);
	float f = floor(TIME * 30.0);
	float n = h(px + f * vec2(7.13, 3.31));
	float row = h(vec2(f * 1.7, floor(FRAGCOORD.y / 5.0)));   // (the streaks across it)
	n = mix(n, row, 0.35);
	COLOR = vec4(vec3(n * bright + bright * 0.25), amount * (0.6 + 0.4 * n));
}
"""

var _fall := Transform3D.IDENTITY   # your view dropping to the floor
var own_death := -1.0   # >= 0: the hunter has its own death scene over the screen

func slender_death(g) -> void:
	if hud == null:
		return
	set_static(0.0)
	if _hiss:
		_hiss.stop()
	_scaring = true
	var fall: float = g.slender_death_fall
	var thick: float = g.slender_death_thick
	var black: float = g.slender_death_black
	var flick: float = g.slender_death_flicker
	_spectate_wait = maxf(_spectate_wait, fall + thick + black + flick + 1.2)
	var screen := _scare_layer()
	var view := hud.size
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dark)
	# His face, big, faint, in the static
	var face := TextureRect.new()
	var tex: Texture2D = g.slender_face
	if tex == null and g.slender_texture:
		var top := AtlasTexture.new()
		top.atlas = g.slender_texture
		var tw: int = g.slender_texture.get_width()
		var th: int = g.slender_texture.get_height()
		top.region = Rect2(0, 0, tw, minf(th, tw * 1.2))
		tex = top
	face.texture = tex
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.modulate = Color(1, 1, 1, 0.0)
	screen.add_child(face)
	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DEATH_STATIC_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	noise.material = mat
	screen.add_child(noise)
	var set_noise := func(a: float, b: float): mat.set_shader_parameter("amount", a); mat.set_shader_parameter("bright", b)
	set_noise.call(0.0, 0.6)
	# You drop: the view tips down and to the side and sinks to the floor
	var t := screen.create_tween()
	t.tween_method(func(f: float):
		_fall = Transform3D(Basis.from_euler(Vector3(lerpf(0.0, -1.05, f * f), 0.0, lerpf(0.0, 0.45, f))), Vector3(0, -1.15 * f * f, 0))
		set_noise.call(lerpf(0.15, 0.6, f), 0.55), 0.0, 1.0, fall)
	t.tween_callback(func(): set_noise.call(0.85, 0.6))
	t.tween_interval(thick)
	t.tween_callback(func():
		set_noise.call(0.0, 0.6)
		dark.color = Color.BLACK)
	t.tween_interval(black)
	# Him, in and out of the static
	var left := flick
	while left > 0.0:
		var d := randf_range(0.06, 0.13)
		var k := randf()
		if k < 0.25:
			t.tween_callback(func(): set_noise.call(0.0, 0.6); face.modulate.a = 0.0)
		elif k < 0.6:
			t.tween_callback(func(): set_noise.call(0.6, 0.45); face.modulate.a = 0.6)
		else:
			t.tween_callback(func(): set_noise.call(0.55, 1.0); face.modulate.a = 0.9)
		t.tween_interval(d)
		left -= d
	t.tween_callback(func():
		set_noise.call(0.0, 0.6)
		face.queue_free()
		noise.queue_free()
		_scaring = false
		if _game_over:
			_game_over_text(screen))
	t.tween_interval(0.8)
	t.tween_callback(func():
		if not _game_over:
			dark.create_tween().tween_property(dark, "modulate:a", 0.0, 0.8).finished.connect(dark.queue_free))
	if g.slender_death_sound:
		var snd := AudioStreamPlayer.new()
		snd.stream = g.slender_death_sound
		snd.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)


var died_at := 0.0

# Caught by a hunter
func die() -> void:
	dead = true
	escaped = true
	died_at = game.time
	collision_layer = 0   # out of the way of your own flung body
	velocity = Vector3.ZERO
	revs = 0
	spin_speed = 0.0
	if prompt:
		prompt.text = ""
	if hud:
		var dark := ColorRect.new()
		dark.color = Color(caught_color, 0.0)
		dark.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(dark)
		hud.move_child(dark, 1)
		_dark = dark
		_spectate_wait = game.spectate_after
		var t := dark.create_tween()
		if own_death >= 0.0:

			t.tween_interval(maxf(own_death, 0.01))
			t.tween_property(dark, "color", Color(0.0, 0.0, 0.0, 0.96), 0.05)
		else:
			t.tween_property(dark, "color", Color(caught_color, 0.5), 0.1)
			if game.ragdolls and game.ragdoll_third_person:
				# Clear again while you watch yourself go flying, then dark
				t.tween_property(dark, "color", Color(caught_color, 0.0), 0.4)
				t.tween_interval(maxf(game.spectate_after - 2.4, 0.5))
			t.tween_property(dark, "color", Color(0.0, 0.0, 0.0, 0.96), caught_fade * 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if message:
		show_message("", 0.0)
