extends Sprite3D
## A teammate in the Salvage mini game, drawn old-school DOOM style: a flat sprite
## that always turns to face the camera, walking behind you along the path you
## took (down the hole too). It uses the character's own sprite sheet and its
## "run" / "stance" frames from the 2D game, so swapping in other art later (like
## Sonic Advance 3 sheets) only means pointing at a different sheet.
## Created by salvage.gd: your 2nd/3rd picks following you (follow()), and the
## other players in co-op or online, placed where they are (drive()).

@export var height := 1.15         ## metres tall on screen, a bit shorter than you
@export var follow_speed := 7.5    ## catch-up speed along your path
@export var gap_step := 0.25       ## spacing of the breadcrumbs it follows
@export var step_every := 0.32     ## seconds between its footsteps while it walks

var gap := 1.6              # how far behind you it walks (metres of path)
var run_frames: Array = [0]
var run_fps := 8.0
var stance_frames: Array = [0]
var stance_fps := 8.0
var anims := {}             # animation name -> [frames, fps, loops], from the character's AnimationPlayer
var state := ""             # what the player it shows is doing ("" = just run / stand)
var _last_state := ""
var path: Array[Vector3] = []   # breadcrumbs from the player, oldest first
var anim_time := 0.0
var moving := false
var last_pos := Vector3.ZERO
var steps: Array = []        # this character's own footstep sounds (from the 2D game)
var step_player: AudioStreamPlayer3D
var step_time := 0.0
var step_i := 0
const ECHO_BUS := "SalvageEcho"


## Load the character's sheet and frames. Returns false if the name isn't known.
func setup(character: String) -> bool:
	var scene := Content.character_scene(character)
	if scene == null:
		return false
	var inst: Node = scene.instantiate()
	var spr := inst.get_node_or_null("Sprite2D") as Sprite2D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if spr == null or spr.texture == null:
		inst.free()
		return false
	texture = spr.texture
	hframes = spr.hframes
	vframes = spr.vframes
	if ap:
		for a_name in ["run", "Dash", "jump", "ball", "revup", "Crouch", "stance"]:
			var f := _frames(ap, a_name)
			if not f.is_empty():
				var a := ap.get_animation(a_name)
				anims[a_name] = [f[0], f[1], a.loop_mode != Animation.LOOP_NONE]
		var r := _frames(ap, "run")
		if not r.is_empty():
			run_frames = r[0]; run_fps = r[1]
		var s := _frames(ap, "stance")
		if not s.is_empty():
			stance_frames = s[0]; stance_fps = s[1]
	steps = step_sounds(inst)
	inst.free()
	if not steps.is_empty():
		step_player = AudioStreamPlayer3D.new()
		step_player.bus = echo_bus()
		step_player.volume_db = -6.0
		step_player.unit_size = 3.0
		step_player.max_distance = 30.0
		add_child(step_player)
	frame = stance_frames[0]
	# Size: one sheet cell becomes height metres tall
	var cell_h := float(texture.get_height()) / vframes
	pixel_size = height / cell_h
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # turns to face you, stays upright (DOOM)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	offset = Vector2(0, cell_h * 0.5)   # feet on the floor
	return true


## A character's footstep sounds, as their run animation plays them on their "Step"
## player (Metal Sonic has no step track, so just his Step sound)
static func step_sounds(inst: Node) -> Array:
	var out := []
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		for anim_name in ap.get_animation_list():
			var a := ap.get_animation(anim_name)
			for t in a.get_track_count():
				if str(a.track_get_path(t)).ends_with("Step:stream"):
					for k in a.track_get_key_count(t):
						var v = a.track_get_key_value(t, k)
						if v is AudioStream and not out.has(v):
							out.append(v)
	if out.is_empty():
		var step := inst.get_node_or_null("Step")
		if step and step.get("stream") is AudioStream:
			out.append(step.stream)
	return out


## A bus with a little reverb, so footsteps ring through the empty corridors
static func echo_bus() -> String:
	if AudioServer.get_bus_index(ECHO_BUS) == -1:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, ECHO_BUS)
		AudioServer.set_bus_send(i, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.75
		rv.damping = 0.6
		rv.wet = 0.3
		rv.dry = 0.9
		AudioServer.add_bus_effect(i, rv)
	return ECHO_BUS


## The frames of a "Sprite2D:frame" track, and how many per second it plays
func _frames(ap: AnimationPlayer, anim_name: String) -> Array:
	if not ap.has_animation(anim_name):
		return []
	var a := ap.get_animation(anim_name)
	for t in a.get_track_count():
		if str(a.track_get_path(t)) == "Sprite2D:frame":
			var frames := []
			for k in a.track_get_key_count(t):
				frames.append(int(a.track_get_key_value(t, k)))
			var n := maxi(frames.size(), 1)
			return [frames, n / maxf(a.length, 0.05)]
	return []


## Called by salvage.gd every physics frame with the player's feet position
func follow(player_feet: Vector3, cam: Camera3D, light: float, delta: float) -> void:
	if path.is_empty() or path.back().distance_to(player_feet) >= gap_step:
		path.append(player_feet)
	# Walk to the breadcrumb that's `gap` metres of path behind the player
	var need := gap
	var target := path[0]
	for i in range(path.size() - 1, 0, -1):
		need -= path[i].distance_to(path[i - 1])
		if need <= 0.0:
			target = path[i - 1]
			# forget breadcrumbs it has already passed
			if i - 1 > 0:
				path = path.slice(i - 1)
			break
	var before := global_position
	global_position = global_position.move_toward(target, follow_speed * delta)
	_animate(global_position - before, cam, light, delta)


## Another player (the co-op partner, or someone online): glide to where they are,
## playing what they're doing (anim: their anim_state(), or "" to just run / stand)
func drive(target: Vector3, cam: Camera3D, light: float, delta: float, anim := "") -> void:
	state = anim
	var before := global_position
	if global_position.distance_to(target) > 6.0:
		global_position = target   # (teleported, or the first update)
	else:
		global_position = global_position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	_animate(global_position - before, cam, light, delta)


func _animate(step: Vector3, cam: Camera3D, light: float, delta: float) -> void:
	moving = Vector2(step.x, step.z).length() > 0.004
	# Face the way it's walking, as seen from the camera (the sheets face right)
	if moving and cam:
		var side := step.dot(cam.global_transform.basis.x)
		if absf(side) > 0.001:
			flip_h = side < 0.0
	anim_time += delta
	if state != _last_state:
		anim_time = 0.0   # start the new animation from its first frame
		_last_state = state
	if moving and step_player and (state == "" or state in ["run", "Dash"]):
		step_time += delta
		if step_time >= step_every:
			step_time = 0.0
			step_player.stream = steps[step_i % steps.size()]
			step_player.pitch_scale = randf_range(0.94, 1.06)
			step_player.play()
			step_i += 1
	if state != "" and anims.has(state):
		var a: Array = anims[state]
		var fr: Array = a[0]
		var i := int(anim_time * a[1])
		frame = fr[i % fr.size()] if a[2] else fr[mini(i, fr.size() - 1)]   # one-shots hold their last frame
	else:
		var frames := run_frames if moving else stance_frames
		var fps := run_fps if moving else stance_fps
		frame = frames[int(anim_time * fps) % frames.size()]
	modulate = Color(light, light, light)
