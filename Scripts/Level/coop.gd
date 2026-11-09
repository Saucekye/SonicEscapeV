extends Node
## Local co-op: Player 1 plays the first character picked, Player 2 the second.
##  - Each player has their own controls (Test.setup_coop_actions): with two or
##    more controllers, P1 = keyboard + first controller and P2 = second
##    controller; with one controller, P1 = keyboard and P2 = the controller.
##  - On normal floors the screen splits: Player 1 on top, Player 2 below.
##  - Each player has their own rings and meter (Player.my_rings / my_meter) and
##    their own HUD icon, ring count and meter (Player 2's is built here: under
##    the split, or beside Player 1's when the screen is shared).
##  - In boss and rest areas, "1P" and "2P" show above the characters' heads.
##  - Boss arenas and rest areas (every 4th floor) aren't split: their cameras
##    already show the whole area. If Player 2 gets far away there, they're
##    brought back next to Player 1.
##  - Characters can't be switched in co-op.
## A third character, if picked, follows Player 1 as usual.
## Turned on in Pause > Settings > Co-op. Created by player_controller.gd.

const DIVIDER := 4.0               # px between the two halves
const LOOK_AHEAD := 112.0          # world units, like the main camera
const LOOK_SMOOTH := 1.0

var controller: Node               # player_controller.gd
var p1: Player
var p2: Player
var split := false

var _layer: CanvasLayer
var _container: SubViewportContainer
var _sub: SubViewport
var _cam2: Camera2D
var _cam2_off := Vector2.ZERO
var _shake := 0.0
var _far_time := 0.0


## Returns true if co-op can run (Player 2 needs a controller)
func setup(player_controller: Node) -> bool:
	controller = player_controller
	var chars: Array = controller.characters
	if chars.size() < 2 or Test.mobile:   # (touch screens have one set of controls)
		return false
	var pads: Array = Test.setup_coop_actions()
	if pads[1] < 0:
		return false   # no controller for Player 2: stay single player
	p1 = chars[0]
	p2 = chars[1]
	p1.input_prefix = "p1_"
	p1.joy_device = pads[0]
	p2.input_prefix = "p2_"
	p2.joy_device = pads[1]
	# Player 2 is a real player, not a follower
	p2.is_player = true
	p2.player_path = NodePath()
	p2.add_to_group("coop_player")
	# Both players: one going down only ends the game when the other is down too (player_base.gd)
	p1.add_to_group("coop_players")
	p2.add_to_group("coop_players")
	p2.z_index = 10
	p2.global_position = p1.global_position + Vector2(-60, 0)
	split = Test.level % 4 != 0
	return true


func _ready() -> void:
	if split:
		_build_split()
	else:
		_build_tags()
	_build_hud.call_deferred()   # after the HUD scene is ready
	GlobalSignals.connect("camerashake", func(): _shake = 0.4)


func _build_split() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6          # over the world and its haze, under the HUD (10)
	add_child(_layer)
	_container = SubViewportContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.stretch = false
	_layer.add_child(_container)
	_sub = SubViewport.new()
	_sub.world_2d = get_viewport().world_2d       # the same level, seen from Player 2
	_sub.transparent_bg = false
	_sub.gui_disable_input = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_container.add_child(_sub)
	_cam2 = Camera2D.new()
	_sub.add_child(_cam2)
	_cam2.make_current()
	_cam2.global_position = p2.global_position
	# The stage background is a CanvasLayer of the main view, so Player 2's view
	# gets its own copy
	var bg_node := get_tree().current_scene.find_child("Background", true, false)
	if bg_node and bg_node.has_method("make_copy"):
		var bg = bg_node.make_copy()
		if bg:
			_sub.add_child(bg)
	# ...and its own city layers (buildings behind, street pieces in front)
	var city = preload("res://Scripts/Level/city_depth.gd")
	if city.applies_to(Test.current_background):
		var cd = city.new()
		cd.setup(Test.current_background)
		_sub.add_child(cd)
	# A dark line between the halves
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = Color(0, 0, 0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(line)
	_layout()


func _stretch() -> float:
	var w := get_window()
	if w == null or w.content_scale_size.x <= 0:
		return 1.0
	return max(0.01, min(float(w.size.x) / w.content_scale_size.x, float(w.size.y) / w.content_scale_size.y) * w.content_scale_factor)


func _layout() -> void:
	# Player 2's half is rendered at the screen's real pixel size, so its pixels
	# are as crisp as the top half's
	var canvas := get_viewport().get_visible_rect().size
	var s := _stretch()
	var half := Vector2(canvas.x, canvas.y * 0.5)
	var px := Vector2i(roundi(half.x * s), roundi(half.y * s))
	if _sub.size != px:
		_sub.size = px
	_container.size = Vector2(px)
	_container.scale = Vector2(1.0 / s, 1.0 / s)
	_container.position = Vector2(0, half.y)
	var line := _layer.get_node("Divider") as ColorRect
	line.position = Vector2(0, half.y - DIVIDER * 0.5)
	line.size = Vector2(canvas.x, DIVIDER)


func _process(delta: float) -> void:
	if p1 == null or not is_instance_valid(p1) or not is_instance_valid(p2):
		return
	_follow_downed()
	if split:
		_update_split(delta)
	else:
		_keep_together(delta)
		_update_tags()
	_update_hud()


## A player who is down rides along with the other one (hidden, out of play), so
## their half of the screen keeps following the action until the next floor
var _down_label: Label
func _follow_downed() -> void:
	for pair in [[p1, p2, "1P"], [p2, p1, "2P"]]:
		var who: Node2D = pair[0]
		var other: Node2D = pair[1]
		if who.has_meta("downed") and not other.has_meta("downed"):
			who.global_position = other.global_position
			if _down_label == null:
				var layer := CanvasLayer.new()
				layer.layer = 20
				add_child(layer)
				_down_label = Label.new()
				_down_label.add_theme_font_size_override("font_size", 30)
				_down_label.add_theme_color_override("font_outline_color", Color.BLACK)
				_down_label.add_theme_constant_override("outline_size", 10)
				_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_down_label.size = Vector2(1600, 50)
				_down_label.position = Vector2(0, 820)
				layer.add_child(_down_label)
			_down_label.text = "%s IS DOWN - back in on the next floor" % pair[2]


# --------------------------------------------------
# PLAYER 2'S HUD: their own icon, rings and meter
# --------------------------------------------------
# Copies of the HUD's icon panel (with its meter bar), character portrait and
# ring counter, without their scripts. Each frame they mirror Player 1's HUD
# (so the slide-in and fades match), moved to Player 2's spot: the top-left of
# the bottom half when split, the bottom-left of the screen otherwise.

const HUD_PARTS := ["Sprite2D", "Sprite2Dicon", "Label"]
const SHARED_HUD_GAP := 200.0   # canvas px between Player 1's and Player 2's icons on a shared screen
var _hud_layer: CanvasLayer
var _hud_pairs := []   # [original, copy]
var _hud_bg: Sprite2D
var _hud_icon: Sprite2D
var _hud_rings: Label
var _hud_meter: TextureProgressBar

func _build_hud() -> void:
	var hud := get_tree().current_scene.get_node_or_null("CanvasLayer") as CanvasLayer
	if hud == null or not hud.has_node("Sprite2D"):
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "P2Hud"
	_hud_layer.layer = hud.layer
	add_child(_hud_layer)
	for part in HUD_PARTS:
		var orig := hud.get_node_or_null(part) as CanvasItem
		if orig == null:
			continue
		var copy := orig.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS) as CanvasItem
		_hud_layer.add_child(copy)
		_hud_pairs.append([orig, copy])
	_hud_bg = _hud_layer.get_node_or_null("Sprite2D")
	_hud_icon = _hud_layer.get_node_or_null("Sprite2Dicon")
	_hud_rings = _hud_layer.get_node_or_null("Label")
	if _hud_bg:
		# Player 2 only needs the panel and its meter bar (the timer, buttons and
		# music widget hang off the same node and stay Player 1's)
		for child in _hud_bg.get_children():
			if child.name != "TextureProgressBar":
				child.free()
		_hud_meter = _hud_bg.get_node_or_null("TextureProgressBar")
		if p2.get("icon_background"):
			_hud_bg.texture = p2.icon_background
	if _hud_icon and p2.get("icon_character"):
		_hud_icon.texture = p2.icon_character
	# Sharing the screen: Player 2's icon sits to the right of Player 1's, so the
	# timer (and best time under it) moves further right to make room
	if not split:
		var p1_panel := hud.get_node_or_null("Sprite2D") as Node2D
		for label in ["Timer", "BestTime"]:
			var c := hud.get_node_or_null("Sprite2D/" + label) as Control
			if c and p1_panel:
				c.position.x += SHARED_HUD_GAP / max(0.01, p1_panel.scale.x)


func _update_hud() -> void:
	if _hud_layer == null:
		return
	var canvas := get_viewport().get_visible_rect().size
	# Split: the top-left of Player 2's half. Shared screen: right next to Player 1's icon.
	var shift := Vector2(0, canvas.y * 0.5) if split else Vector2(SHARED_HUD_GAP, 0)
	for pair in _hud_pairs:
		var orig: CanvasItem = pair[0]
		var copy: CanvasItem = pair[1]
		if not is_instance_valid(orig):
			continue
		copy.visible = orig.visible
		copy.modulate = orig.modulate
		if orig is Node2D:
			(copy as Node2D).position = (orig as Node2D).position + shift
		elif orig is Control:
			(copy as Control).position = (orig as Control).position + shift
	if _hud_bg:
		var obg := _hud_pairs[0][0] as Sprite2D
		_hud_bg.frame = obg.frame
	if _hud_rings:
		_hud_rings.text = str(Test.p2_rings).pad_zeros(3)
		var ap := _hud_rings.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			var want := "Low" if Test.p2_rings <= 0 else "RESET"
			if ap.current_animation != want and ap.has_animation(want):
				ap.play(want)
	if _hud_meter:
		_hud_meter.value = Test.p2_meter


# --------------------------------------------------
# 1P / 2P ABOVE THEIR HEADS (boss and rest areas, where the screen isn't split)
# --------------------------------------------------
# 1P in blue, 2P in red, sitting just above the top of each character's
# current animation frame (so it follows jumps, crouches and tall poses).

const TAG_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.18, 0.18)]
const TAG_GAP := 6.0   # world units between the sprite's top and the tag
var _tags := []
static var _tops := {}  # sprite sheet + frame -> top solid row

func _build_tags() -> void:
	for i in 2:
		var tag := Label.new()
		tag.text = "%dP" % (i + 1)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		tag.add_theme_font_size_override("font_size", 40)
		tag.add_theme_color_override("font_color", TAG_COLORS[i])
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		tag.add_theme_constant_override("outline_size", 12)
		tag.size = Vector2(120, 56)
		tag.z_index = 110
		tag.z_as_relative = false
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		_tags.append(tag)


func _update_tags() -> void:
	for i in _tags.size():
		var who: Node2D = p1 if i == 0 else p2
		var tag: Label = _tags[i]
		tag.visible = who.visible
		var top := _sprite_top(who)
		tag.global_position = Vector2(who.global_position.x - tag.size.x * 0.5, top - TAG_GAP - tag.size.y)


## World y of the top of the character's visible pixels in its current frame
func _sprite_top(who: Node2D) -> float:
	var sp := who.get_node_or_null("Sprite2D") as Sprite2D
	if sp == null or sp.texture == null:
		return who.global_position.y - 120.0
	var key := "%s|%d|%d|%d" % [sp.texture.get_rid(), sp.hframes, sp.vframes, sp.frame]
	var row = _tops.get(key)
	if row == null:
		row = 0
		var img := sp.texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var fw := img.get_width() / sp.hframes
			var fh := img.get_height() / sp.vframes
			var used := img.get_region(Rect2i((sp.frame % sp.hframes) * fw, (sp.frame / sp.hframes) * fh, fw, fh)).get_used_rect()
			row = used.position.y if used.size.y > 0 else 0
		_tops[key] = row
	var r := sp.get_rect()
	return (sp.global_transform * Vector2(0, r.position.y + float(row))).y


func _update_split(delta: float) -> void:
	_layout()
	var main_cam: Camera2D = controller.camera_instance
	if main_cam == null:
		return
	# Top half: centre Player 1 in the top half instead of the whole screen
	var canvas := get_viewport().get_visible_rect().size
	if main_cam.zoom.y > 0.0:
		main_cam.default_offset = Vector2(0, canvas.y * 0.25 / main_cam.zoom.y)
	# Bottom half: Player 2's camera, same zoom and the same look-ahead as the main one
	_cam2.zoom = main_cam.zoom * _stretch()
	var vel: Vector2 = p2.get_velocity()
	var want := Vector2.ZERO
	if vel.length() >= 300.0:
		want.x = signf(vel.x) * LOOK_AHEAD
	want.y = -50.0 if p2.is_on_floor() else 56.0
	_cam2_off = _cam2_off.lerp(want, LOOK_SMOOTH * delta)
	var shake := Vector2.ZERO
	if _shake > 0.0:
		_shake -= delta
		shake = Vector2(randf_range(-3, 3), randf_range(-3, 3)) / max(0.01, _cam2.zoom.x)
	_cam2.global_position = p2.global_position + _cam2_off + shake


func _keep_together(delta: float) -> void:
	# Boss and rest areas share one screen: bring Player 2 back if they wander off
	if p2.global_position.distance_to(p1.global_position) > 1500.0:
		_far_time += delta
		if _far_time > 1.0:
			p2.global_position = p1.global_position + Vector2(-60, -60)
			p2.velocity = Vector2.ZERO
			_far_time = 0.0
	else:
		_far_time = 0.0
