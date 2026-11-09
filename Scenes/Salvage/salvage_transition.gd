extends CanvasLayer
## The way into the Salvage mini game: the screen fades to black, the elevator
## animation fades in (Sonic in the purple elevator, its light flickering) and
## "SALVAGE" types itself out in red above it, one letter at a time. Then it fades
## back to black and the facility fades in. (No sounds for now.)
## Used by the rest tree (tree.gd) offline and by Net._go_salvage() online.

const SCENE := "res://Scenes/Salvage/salvage.tscn"

@export var sheet: Texture2D = preload("res://Sprites/Salvage/elevator_transition.png")   ## the animation's frames, side by side
@export var sheet_frames := 6
@export var frame_times: Array[float] = [0.1, 2.5, 0.1, 0.1, 0.1, 0.02]   ## seconds each frame shows
@export var title: Texture2D = preload("res://Sprites/Salvage/salvage_title.png")
@export var title_at := Vector2(222, 31)      ## where the title sits within a frame (pixels)
@export var letter_ends: Array[int] = [13, 26, 37, 48, 60, 74, 86]   ## where each letter of the title ends (pixels)
@export var type_delay := 0.5     ## after the elevator fades in
@export var type_every := 0.14    ## seconds per letter
@export var fade_time := 0.6
@export var hold_after := 0.6     ## after the animation, before fading out

var black: ColorRect
var elevator: Sprite2D
var title_sprite: Sprite2D
var anim_time := -1.0        # < 0 while the animation isn't playing


## Start the transition (does nothing if one is already running)
static func go(tree: SceneTree) -> void:
	if tree.root.has_node("SalvageTransition"):
		return
	Test.salvage_done_level = Test.level   # once per rest area (tree.gd greys out Salvage after)
	var t = load("res://Scenes/Salvage/salvage_transition.tscn").instantiate()
	t.name = "SalvageTransition"
	tree.root.add_child(t)


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true   # freeze the rest area as it fades
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	# The elevator animation, centred and as tall as the screen allows
	var screen := get_viewport().get_visible_rect().size
	var frame_size := Vector2(sheet.get_width() / float(sheet_frames), sheet.get_height())
	var k := screen.y * 0.94 / frame_size.y
	elevator = Sprite2D.new()
	elevator.texture = sheet
	elevator.hframes = sheet_frames
	elevator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elevator.scale = Vector2.ONE * k
	elevator.position = screen * 0.5
	elevator.modulate.a = 0.0
	add_child(elevator)
	# The title, revealed letter by letter
	title_sprite = Sprite2D.new()
	title_sprite.texture = title
	title_sprite.centered = false
	title_sprite.region_enabled = true
	title_sprite.region_rect = Rect2(0, 0, 0, title.get_height())
	title_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_sprite.scale = Vector2.ONE * k
	title_sprite.position = elevator.position + (title_at - frame_size * 0.5) * k
	add_child(title_sprite)
	_run()


func _run() -> void:
	# 1. Fade to black
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, fade_time)
	await t.finished
	# 2. The elevator fades in, and SALVAGE types itself out
	anim_time = 0.0
	t = create_tween()
	t.tween_property(elevator, "modulate:a", 1.0, 0.5)
	await t.finished
	await _wait(type_delay)
	for i in letter_ends.size():
		title_sprite.region_rect.size.x = letter_ends[i]
		await _wait(type_every)
	var total := 0.0
	for ft in frame_times:
		total += ft
	await _wait(maxf(total - anim_time, 0.0) + hold_after)
	# 3. Fade out to black, then into the facility
	t = create_tween()
	t.tween_property(elevator, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(title_sprite, "modulate:a", 0.0, 0.5)
	await t.finished
	anim_time = -1.0
	get_tree().paused = false
	Pause.current_scene = "Salvage"
	get_tree().change_scene_to_file(SCENE)
	await _wait(0.25)
	t = create_tween()
	t.tween_property(black, "color:a", 0.0, 0.8)
	await t.finished
	queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _process(delta: float) -> void:
	if anim_time >= 0.0:
		anim_time += delta
		# The animation plays once, then rests on its last frame
		var t := anim_time
		var f := 0
		while f < mini(sheet_frames, frame_times.size()) - 1 and t >= frame_times[f]:
			t -= frame_times[f]
			f += 1
		elevator.frame = f
