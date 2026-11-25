extends RefCounted
# Counts a saved Miku

const OC_SCENE := "res://Scenes/Obstacles/Ocs/ocs.tscn"


# The scene to spawn where a Miku appears
static func rescue_scene(miku_scene: PackedScene, r: RandomNumberGenerator = null) -> PackedScene:
	if Test.playtest_look:
		return load(OC_SCENE) if Test.playtest_rescue_is_oc else miku_scene   # the Sonic Escape panel's Play
	if (r.randf() if r else randf()) < Content.data().oc_chance:   # how often an OC appears instead of a Miku
		return load(OC_SCENE)
	return miku_scene


# Is this body someone you can rescue?
static func is_rescue(body: Node) -> bool:
	if body == null or not (body is CharacterBody2D):
		return false
	if body.is_in_group("Miku"):
		return true
	var sc = body.get_script()
	return sc != null and str(sc.resource_path).ends_with("ocs.gd")

const WHITE := Color(1, 1, 1)
const SHOW_TIME := 1.2   # seconds the points stay on screen
const POPUP_SIZE := 26   # how big the points are


# Count this Miku as saved and show the pop-up
static func save(miku: Node2D) -> bool:
	if miku == null or not is_instance_valid(miku) or miku.has_meta("saved") or miku.has_meta("lost"):
		return false
	miku.set_meta("saved", true)
	Test.mikus_saved += 1
	popup(miku, "+%d" % Test.MIKU_SCORE)
	return true


# Pop a short line of text above her
static func popup(miku: Node2D, word: String) -> void:
	var parent := miku.get_tree().current_scene
	if parent == null:
		return
	var box := Node2D.new()
	box.z_index = 120
	box.z_as_relative = false
	parent.add_child(box)
	# Follows her for a moment, then floats on its own
	box.global_position = _anchor(miku)
	box.set_meta("follow", miku)

	box.add_child(_label(word, WHITE, POPUP_SIZE))

	# Just appears, stays a moment, then disappears
	var t := box.create_tween()
	t.tween_interval(SHOW_TIME)
	t.tween_callback(box.queue_free)

	# Stay above her while the pop-up is up
	var follow := func() -> void:
		var m = box.get_meta("follow")
		if is_instance_valid(m):
			box.global_position = _anchor(m)
	box.get_tree().process_frame.connect(follow)
	box.tree_exiting.connect(func(): box.get_tree().process_frame.disconnect(follow))

	# A little hop of joy when she's not being carried
	if "is_being_held" in miku and not miku.is_being_held and miku.has_node("AnimationPlayer"):
		var ap: AnimationPlayer = miku.get_node("AnimationPlayer")
		if ap.has_animation("wave"):
			ap.play("wave")


static func _anchor(miku: Node2D) -> Vector2:
	return miku.global_position + Vector2(0, -140)


static func _label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(size / 4, 6))
	l.size = Vector2(600, size * 1.4)
	l.position = Vector2(-300, -size * 0.7)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l
