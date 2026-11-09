extends CharacterBody3D
## One player in the Salvage mini game: a short first-person body (eye level about
## 1 m, the same height as the characters' sprites), its own low-res PS1 view and
## HUD, its own controls and its own rings. salvage.gd makes one per local player:
## one normally, two in local co-op (split screen, 1P top / 2P bottom).

@export_group("Movement")
@export var walk_speed := 4.2
@export var sprint_speed := 6.6
@export var crouch_speed := 1.8            ## only used under a shelf (otherwise crouching holds you still)
@export var jump_speed := 5.2
@export var gravity := 18.0
@export var max_fall_speed := 12.0         ## top falling speed (m/s): it makes the long drop down the hole last
@export_group("Spindash")
@export var spindash_speed := 9.0          ## launch speed (m/s), plus the next value per rev
@export var spindash_speed_per_rev := 2.0
@export var spindash_max_revs := 5
@export var spindash_slowdown := 4.5       ## how fast the roll slows down (m/s each second)
@export_range(-40.0, 6.0) var spindash_volume_db := -16.0   ## how loud the rev and release sounds are
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var rev_sound := "res://Sounds/SonicSFX/rev.MP3"
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var dash_sound := "res://Sounds/SonicSFX/spindash.MP3"
@export_group("Body and camera")
@export var eye_height := 1.0              ## you're short: about the same height as your teammates
@export var crouch_eye_height := 0.55
@export var spindash_eye_height := 0.45
@export var body_height := 1.1
@export var crouch_body_height := 0.6      ## low enough to crawl under a shelf
@export var fov := 80.0                    ## side to side, in a full-screen view (alone or online)
@export var split_fov := 44.0              ## top to bottom, in co-op's short, wide split-screen halves
@export var reach := 2.4                   ## how far away you can salvage an item or press a button
@export_group("Controls")
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6

var index := 0              # 0 = 1P, 1 = 2P (local co-op)
var actions := "sv_"        # this player's input actions (sv_ = 1P / single, sv2_ = 2P)
var pad := 0                # controller for this player's sticks (-1 = none)
var use_mouse := true
var character := ""         # who you are (shown to the others as a sprite)
var head: Node3D
var cam: Camera3D
var view: SubViewport
var hud: Control
var hud_rings: Label
var hud_meter: TextureProgressBar
var hud_items: HBoxContainer      # what you are carrying, under the meter
const ITEM_ICON_SIZE := 40.0       # size of each picture in that row (pixels)
var prompt: Label
var message: Label
var carried: Array = []
var looking_at: Node3D = null
var escaped := false
var bob := 0.0
var game: Node3D            # salvage.gd
var steps: Array = []       # your character's own footstep sounds
var step_player: AudioStreamPlayer
var step_i := 0
var crouching := false
var small := false          # body shrunk (crouched or rolling)
var hidden := false         # crouched behind or under cover ("salvage_cover" group); for enemies later
var body_shape: CollisionShape3D
var hud_hidden: Label
var _msg_tween: Tween
var revs := 0               # spindash charge: how many times jump was pressed while crouched
var spin_speed := 0.0       # > 0 while rolling from a spindash
var eye := eye_height
var sfx: AudioStreamPlayer

## This player's rings: co-op 2P has their own (Test.p2_rings)
var rings: int:
	get: return Test.p2_rings if index == 1 else Test.rings
	set(v):
		if index == 1:
			Test.p2_rings = v
		else:
			Test.rings = v


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
	game.add_child(view)
	cam = Camera3D.new()
	cam.fov = _base_fov()
	cam.near = 0.05
	cam.far = 60
	# Full screen: the fov is side to side. A co-op half is short and wide, so there it's
	# top to bottom; going by its width only left a thin strip to see through.
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if _split() else Camera3D.KEEP_WIDTH
	cam.cull_mask = cull_mask               # don't draw your own sprite in your own view
	view.add_child(cam)
	cam.current = true
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = spindash_volume_db
	add_child(sfx)


func physics(delta: float) -> void:
	if escaped:
		cam.global_transform = head.global_transform
		return
	# Look: right stick (mouse is handled in look_mouse)
	var look := Vector2(_joy(JOY_AXIS_RIGHT_X), _joy(JOY_AXIS_RIGHT_Y))
	if look.length() > 0.2:
		rotate_y(-look.x * stick_sensitivity * delta)
		head.rotation.x = clamp(head.rotation.x - look.y * stick_sensitivity * delta, -1.45, 1.45)
	# Move: keys / left stick
	var input := Input.get_vector(actions + "left", actions + "right", actions + "forward", actions + "back")
	var stick := Vector2(_joy(JOY_AXIS_LEFT_X), _joy(JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		input = stick
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	dir.y = 0
	dir = dir.limit_length(1.0)
	var speed := sprint_speed if Input.is_action_pressed(actions + "sprint") else walk_speed
	var crouch_held := Input.is_action_pressed(actions + "crouch")
	var jump_pressed := Input.is_action_just_pressed(actions + "jump")
	if spin_speed > 0.0:
		# Rolling from a spindash: straight ahead where you look, slowing down
		var fwd := -transform.basis.z
		velocity.x = fwd.x * spin_speed
		velocity.z = fwd.z * spin_speed
		spin_speed -= spindash_slowdown * delta
		if is_on_floor() and jump_pressed:
			velocity.y = jump_speed   # jump out of the roll, keeping the speed
		if spin_speed <= walk_speed or get_slide_collision_count() > 0 and _hit_wall():
			spin_speed = 0.0
	else:
		# Under a shelf you stay crouched until there's room to stand
		var forced := small and _blocked_above()
		crouching = (crouch_held and is_on_floor()) or forced
		if crouching:
			speed = crouch_speed
			# Crouching holds you still, except under something (a shelf you rolled
			# under), where you can shuffle about and crawl back out
			if not forced and not _blocked_above():
				dir = Vector3.ZERO
			if crouch_held and jump_pressed and is_on_floor():
				# Rev the spindash: each press adds a rev, the sound climbing in pitch
				revs = mini(revs + 1, spindash_max_revs)
				_sound(rev_sound, clampf(revs / 2.0, 1.0, 2.0))
			if revs > 0 and crouch_held:
				dir = Vector3.ZERO   # held in place while revving
		if revs > 0 and not crouch_held:
			# Let go of crouch: release!
			spin_speed = spindash_speed + spindash_speed_per_rev * revs
			revs = 0
			_sound(dash_sound, 1.5)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if is_on_floor() and jump_pressed and not crouching:
			velocity.y = jump_speed
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
	_set_small(crouching or spin_speed > 0.0)
	move_and_slide()
	hidden = crouching and (_under_cover() or _near_cover())
	if hud_hidden:
		hud_hidden.visible = hidden
	# Eye height and field of view: low when crouched or rolling, wider at speed
	var want_eye := spindash_eye_height if spin_speed > 0.0 else (crouch_eye_height if crouching else eye_height)
	eye = move_toward(eye, want_eye, delta * 4.0)
	var kick := (14.0 if not _split() else 8.0) if spin_speed > 0.0 else 0.0
	cam.fov = lerpf(cam.fov, _base_fov() + kick, clampf(delta * 8.0, 0.0, 1.0))
	if spin_speed <= 0.0 and is_on_floor() and dir.length() > 0.1:
		var before := floori(bob / PI)
		bob += delta * speed * 2.4
		if floori(bob / PI) != before and not crouching:
			_footstep()   # one step each time the head bob dips (crouching is silent)
	head.position.y = eye + sin(bob) * 0.03
	if revs > 0:
		head.position.y += randf_range(-0.01, 0.01)   # shaking while it revs
	cam.global_transform = head.global_transform
	if global_position.y < -20.0:
		global_position = Vector3(0, 0.5, 0)
	_update_interact()


## Shrink the body to crawl under things (crouched or rolling), or stand back up
func _set_small(on: bool) -> void:
	if on == small or body_shape == null:
		return
	if not on and _blocked_above():
		crouching = true   # no room to stand (a roll ended under a shelf): stay down
		return
	small = on
	var h := crouch_body_height if on else body_height
	(body_shape.shape as CapsuleShape3D).height = maxf(h, 0.6)
	body_shape.position.y = maxf(h, 0.6) * 0.5


## Would standing up hit something?
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


## Something to hide under: cover right above your head
func _under_cover() -> bool:
	var from := global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 1.6, 0), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider.is_in_group("salvage_cover")


## Something to hide behind: cover within arm's reach, at crouching height
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


## Rolled into a wall head-on (sliding along one keeps the roll going)
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


func _footstep() -> void:
	if step_player == null:
		return
	step_player.stream = steps[step_i % steps.size()]
	step_player.pitch_scale = randf_range(0.94, 1.06)
	step_player.play()
	step_i += 1


## In co-op's split screen (each view much wider than it is tall)?
func _split() -> bool:
	return view != null and view.size.x > view.size.y * 2.5


func _base_fov() -> float:
	return split_fov if _split() else fov


## What your character is doing, for the sprite the other players see
## (the animation names every character has)
func anim_state() -> String:
	if spin_speed > 0.0:
		return "ball"
	if revs > 0:
		return "revup"
	if crouching:
		return "Crouch"
	if not is_on_floor():
		return "jump"
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > walk_speed + 0.5:
		return "Dash"
	if flat > 0.3:
		return "run"
	return "stance"


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.3


func look_mouse(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x - relative.y * mouse_sensitivity, -1.45, 1.45)


func _joy(axis: JoyAxis) -> float:
	return Input.get_joy_axis(pad, axis) if pad >= 0 else 0.0


func _update_interact() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	var hit := space.intersect_ray(q)
	looking_at = hit.collider if hit and (hit.collider.has_meta("item") or hit.collider.has_meta("button")) else null
	if looking_at and looking_at.has_meta("button"):
		# The exit elevator's ESCAPE button
		var key := "[E] " if use_mouse else "[X] "
		prompt.text = "" if game.departing else key + "Press ESCAPE"
		prompt.modulate = Color(1, 0.5, 0.45)
		if not game.departing and Input.is_action_just_pressed(actions + "interact"):
			game.press_escape(self)
	elif looking_at:
		var kind: Array = looking_at.get_meta("item")
		var cost: int = kind[1]
		var key := "[E] " if use_mouse else "[X] "
		if rings >= cost:
			prompt.text = "%s%s  -  %d rings" % [key, kind[0], cost]
			prompt.modulate = Color(1, 1, 1)
		else:
			prompt.text = "%s  -  needs %d rings" % [kind[0], cost]
			prompt.modulate = Color(1, 0.45, 0.4)
		if Input.is_action_just_pressed(actions + "interact"):
			game.try_salvage(self, looking_at)
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
		hud_meter.value = Test.p2_meter if index == 1 else Test.meter


func carried_value() -> int:
	var v := 0
	for k in carried:
		v += k[2]
	return v


# ── HUD, inside this player's half of the screen ─────────────────────────────
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
	var cross := _label(24, HORIZONTAL_ALIGNMENT_CENTER)
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


## The game's own character icon panel (portrait, ring counter and meter), copied
## from the level HUD (Scenes/Level/UIGAME.tscn) like co-op's 2P panel (coop.gd)
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
		# Only the panel and its meter bar (the timer and buttons hang off it too)
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
		steps = preload("res://Scenes/Salvage/salvage_teammate.gd").step_sounds(c)
		c.free()
	if not steps.is_empty():
		step_player = AudioStreamPlayer.new()
		step_player.bus = preload("res://Scenes/Salvage/salvage_teammate.gd").echo_bus()
		step_player.volume_db = -8.0
		add_child(step_player)
	# Top-left, exactly where it sits in the levels (measured from the level HUD)
	# Above the 3D view (the meter bar sits one layer under the panel, which put it
	# behind the view)
	for n in [bg, icon, hud_rings]:
		if n:
			n.z_index = 3
	if bg:
		bg.position = Vector2(99.7, 69.7)
		bg.scale = Vector2(3, 3)
	if icon:
		icon.position = Vector2(80, 45)
		icon.scale = Vector2(0.0682, 0.0728)
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


## An item you just picked up: its picture joins the row under your meter, with a pop
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


## Copies don't need the level HUD's scripts (they read 1P's rings and the level)
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


## Fade out the message now, if it's still this one
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
