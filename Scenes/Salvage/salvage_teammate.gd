extends Sprite3D
# Doom-style billboard sprite for teammates, using the character's 2D sheet

@export var height := 1.15         ## metres tall on screen, a bit shorter than you
var min_light := 0.0                # never darker than this
@export var follow_speed := 7.5    ## catch-up speed along your path
@export var gap_step := 0.25       ## spacing of the breadcrumbs it follows
@export var step_every := 0.32     ## seconds between its footsteps while it walks
@export var step_volume_db := -13.0 ## teammates' footsteps
var silent_steps := false   # someone following you

var gap := 1.6              # how far behind you it walks
const FOLLOW_EASE := 10.0   # how quickly it closes in on its spot behind you
var _pace := 0.0            # its speed, smoothed
var run_frames: Array = [0]
var run_fps := 8.0
var stance_frames: Array = [0]
var stance_fps := 8.0
var anims := {}             # animation name -> [frames, fps, loops], from the character's AnimationPlayer
var state := ""             # what the player it shows is doing
var _last_state := ""
var path: Array[Vector3] = []   # breadcrumbs from the player, oldest first
var anim_time := 0.0
var moving := false
var last_pos := Vector3.ZERO
var steps: Array = []        # this character's own footstep sounds
var step_player: AudioStreamPlayer3D
var step_time := 0.0
var step_i := 0
var beats := {}              # run animation -> when its feet land
var _beat_t := 0.0           # how far through the run animation, for the steps
const ECHO_BUS := "SalvageEcho"


# Load the character's sheet and frames
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
		for a_name in ["run", "Dash", "jump", "ball", "revup", "Crouch", "stance", "hurt", "trick1", "trick2", "trick3", "trick4"]:
			var f := _frames(ap, a_name)
			if not f.is_empty():
				var a := ap.get_animation(a_name)
				anims[a_name] = [f[0], f[1], a.loop_mode != Animation.LOOP_NONE, f[2]]
		var r := _frames(ap, "run")
		if not r.is_empty():
			run_frames = r[0]; run_fps = r[1]
		var s := _frames(ap, "stance")
		if not s.is_empty():
			stance_frames = s[0]; stance_fps = s[1]
	steps = step_sounds(inst)
	beats = step_beats(inst)
	inst.free()
	if not steps.is_empty():
		step_player = AudioStreamPlayer3D.new()
		step_player.bus = echo_bus()
		step_player.volume_db = step_volume_db
		step_player.unit_size = 3.0
		step_player.max_distance = 30.0
		add_child(step_player)
	frame = stance_frames[0]
	# Size: one sheet cell becomes height metres tall
	var cell_h := float(texture.get_height()) / vframes
	pixel_size = height / cell_h
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y   # turns to face you, stays upright
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	offset = Vector2(0, cell_h * 0.5)   # feet on the floor
	return true


# Become another character
func reskin(character: String) -> void:
	if step_player:
		step_player.queue_free()
		step_player = null
	anims.clear()
	setup(character)


# Not a character but a picture strip, like Miku's sheet
func setup_strip(tex: Texture2D, across: int, wave: Array, wave_fps: float) -> void:
	texture = tex
	hframes = across
	vframes = 1
	run_frames = [0]
	stance_frames = [0]
	anims["wave"] = [wave, wave_fps, true]
	frame = 0
	var cell_h := float(texture.get_height())
	pixel_size = height / cell_h
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	offset = Vector2(0, cell_h * 0.5)


# A character's footstep sounds
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


# When the feet land in the run animations, as the 2D game plays its "Step" sounds
static func step_beats(inst: Node) -> Dictionary:
	var out := {}
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return out
	for anim_name in ["run", "Dash"]:
		if not ap.has_animation(anim_name):
			continue
		var a := ap.get_animation(anim_name)
		var times := []
		var sounds := {}
		for t in a.get_track_count():
			var path := str(a.track_get_path(t))
			if path.ends_with("Step:playing") or path.ends_with("Step:stream"):
				for k in a.track_get_key_count(t):
					var at := a.track_get_key_time(t, k)
					if not times.has(at):
						times.append(at)
					var v = a.track_get_key_value(t, k)
					if v is AudioStream:
						sounds[at] = v
		if times.is_empty() or a.length <= 0.0:
			continue
		times.sort()
		var beats := []
		for at in times:
			beats.append([at / a.length, sounds.get(at)])
		out[anim_name] = [a.length, beats]
	return out


# Did a step land between two points of a loop?
static func beat_between(beats: Array, from: float, to: float) -> Variant:
	for b in beats:
		var f: float = b[0]
		if (from < to and f > from and f <= to) or (to < from and (f > from or f <= to)):
			return b
	return null


# A bus with a little reverb
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


# The frames of a "Sprite2D:frame" track, and how many per second it plays
func _frames(ap: AnimationPlayer, anim_name: String) -> Array:
	if not ap.has_animation(anim_name):
		return []
	var a := ap.get_animation(anim_name)
	for t in a.get_track_count():
		if str(a.track_get_path(t)) == "Sprite2D:frame":
			var frames := []
			var times := []
			for k in a.track_get_key_count(t):
				frames.append(int(a.track_get_key_value(t, k)))
				times.append(a.track_get_key_time(t, k))
			var n := maxi(frames.size(), 1)
			return [frames, n / maxf(a.length, 0.05), times]
	return []


# Called by salvage.gd every physics frame with the player's feet position
func follow(player_feet: Vector3, cam: Camera3D, light: float, delta: float) -> void:
	if path.is_empty() or path.back().distance_to(player_feet) >= gap_step:
		path.append(player_feet)
	# The exact point `gap` metres of path behind the player, between breadcrumbs
	var need := gap
	var target := path[0]
	var ahead := player_feet
	for i in range(path.size() - 1, -1, -1):
		var seg := ahead.distance_to(path[i])
		if seg >= need:
			target = ahead.move_toward(path[i], need)
			if i > 0:
				path = path.slice(i - 1)   # forget breadcrumbs it has already passed
			break
		need -= seg
		ahead = path[i]
	var before := global_position
	var catch_up := 1.0 - exp(-FOLLOW_EASE * delta)
	global_position = global_position.lerp(target, catch_up)
	if global_position.distance_to(before) > follow_speed * delta:
		global_position = before.move_toward(target, follow_speed * delta)
	silent_steps = true
	_animate(global_position - before, cam, light, delta)


# Put somewhere, walking there
func drive(target: Vector3, cam: Camera3D, light: float, delta: float, anim := "", exact := false) -> void:
	state = anim
	var before := global_position
	if exact or global_position.distance_to(target) > 6.0:
		global_position = target
	else:
		global_position = global_position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	_animate(global_position - before, cam, light, delta)


func _animate(step: Vector3, cam: Camera3D, light: float, delta: float) -> void:
	_pace = lerpf(_pace, Vector2(step.x, step.z).length() / maxf(delta, 0.0001), clampf(delta * 8.0, 0.0, 1.0))
	moving = _pace > (0.35 if moving else 0.6)
	# Face the way it's walking, as seen from the camera
	if moving and cam:
		var side := step.dot(cam.global_transform.basis.x)
		if absf(side) > 0.25 * delta:
			flip_h = side < 0.0
	anim_time += delta
	if state != _last_state:
		anim_time = 0.0   # start the new animation from its first frame
		_beat_t = 0.0
		_last_state = state
	if moving and step_player and not silent_steps and (state == "" or state in ["run", "Dash"]):
		var anim := "Dash" if state == "Dash" else "run"
		if beats.has(anim):
			# On the frames where its feet land, like the 2D game
			var b: Array = beats[anim]
			var length: float = b[0]
			var from := fmod(_beat_t, length) / length
			_beat_t = anim_time
			var hit = beat_between(b[1], from, fmod(_beat_t, length) / length)
			if hit != null:
				step_player.stream = hit[1] if hit[1] != null else steps[step_i % steps.size()]
				step_player.pitch_scale = randf_range(0.96, 1.04)
				step_player.play()
				step_i += 1
		else:
			step_time += delta
			if step_time >= step_every:
				step_time = 0.0
				step_player.stream = steps[step_i % steps.size()]
				step_player.pitch_scale = randf_range(0.94, 1.06)
				step_player.play()
				step_i += 1
	else:
		_beat_t = anim_time
	if state != "" and anims.has(state):
		var a: Array = anims[state]
		var fr: Array = a[0]
		if a[2]:
			frame = fr[int(anim_time * a[1]) % fr.size()]
		else:
			# One-shots go by their keys' own times, and hold their last frame
			var times: Array = a[3]
			var i := 0
			while i + 1 < times.size() and times[i + 1] <= anim_time:
				i += 1
			frame = fr[i]
	else:
		var frames := run_frames if moving else stance_frames
		var fps := run_fps if moving else stance_fps
		frame = frames[int(anim_time * fps) % frames.size()]
	var l := maxf(light, min_light)
	modulate = Color(l, l, l)
