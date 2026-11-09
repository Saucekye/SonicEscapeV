extends Area2D

var player_inside := false
var musicplay = false
var use_alt := false
var nights = false  # true = show the alternate text set on Label

func _ready():
	$Arrow.visible = false
	$AudioStreamPlayer.play()
	$CanvasLayer/TextSprite.visible = false
	$CanvasLayer/TextSprite2.visible = false
	
	$CanvasLayer/Label.visible = false
	$CanvasLayer/Button.visible = false
	_add_menu_options()
	
	$CanvasLayer/TextSprite.modulate.a = 0
	$CanvasLayer/TextSprite2.modulate.a = 0
	$CanvasLayer/Label.modulate.a = 0
		
	randomize()
	if randf() <= 0.25 and (Test.level != 0 and Test.level != 24 and Test.level != 20):
		use_alt = true
		nights = false
		$Node2D.visible = false
		$Node2D4.visible = false
		$Sprite2D.visible = false
		$AnimatedSprite2D.visible = true
		$NiGHTS.visible = false
	elif randf() > 0.25 and randf() < 0.5 and (Test.level != 0 and Test.level != 24 and Test.level != 20):
		nights = true
		$Node2D.visible = true
		$Node2D4.visible = true
		$Sprite2D.visible = true
		$AnimatedSprite2D.visible = false
		$NiGHTS.visible = true
	else:
		nights = false
		use_alt = false
		$Node2D.visible = true
		$Node2D4.visible = true
		$Sprite2D.visible = true
		$AnimatedSprite2D.visible = false
		$NiGHTS.visible = false


func _process(delta):
	# Salvage and Chao Garden show whenever the tree's page is open
	var page_open: bool = $CanvasLayer/Label.visible and $CanvasLayer/Label.modulate.a > 0.5
	for b in _extra_buttons:
		b.visible = page_open
	_update_windows()
	_update_focus()
	# With the page open, up/down move between the buttons (the GUI does that);
	# up on the top button (or with nothing to pick) closes the page, as before
	var up_closes := not page_open or _focus_before == null or _focus_before == _top_button()
	_focus_before = get_viewport().gui_get_focus_owner()
	if player_inside and Input.is_action_just_pressed("ui_up") and up_closes:
		toggle_text()
		if use_alt:
			$CanvasLayer/PageSfx.stream = load("res://Sounds/SFX/rewrite-laughing-lol.mp3")
		else:
			$CanvasLayer/PageSfx.stream = load("res://Sounds/SFX/page-flip-01a.mp3")
			$CanvasLayer/PageSfx.play()
		
		# Only change text when opening
		if $CanvasLayer/Label.visible:
			update_text()
			
		if musicplay == false and nights == false:
			$Timer.start()
			
		if nights == true and musicplay == false:
			musicplay = true
			$AudioStreamPlayer2D.stream = load("res://Music/MainMenu/Dreams Dreams _ A-Cappella Ver..mp3")
			$AudioStreamPlayer2D.play()
		
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		player_inside = true
		$Arrow.visible = true

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("Player"):
		player_inside = false
		$Arrow.visible = false
		$CanvasLayer/TextSprite.visible = false   
		$CanvasLayer/TextSprite2.visible = false  
		$CanvasLayer/Label.visible = false
		$CanvasLayer/Button.visible = false
		if use_alt and area.get_parent().is_player:
			$CanvasLayer/PageSfx.play()
			
		
func update_text():
	if use_alt:
		match Test.level:
			4:
				$CanvasLayer/Label.text = "LET'S PLAY A GAME
YOU CAN CHOOSE YOUR FAVORITE THING
THIS CLICHE NEVER DIES
YOU CAN'T RUN AND YOU CAN'T HIDE!"
			8:
				$CanvasLayer/Label.text = "LET YOUR SPIRIT
LEAVE YOUR BODY
I AM GOD
AND YOU'RE NOBODY!"
			12:
				$CanvasLayer/Label.text = "BE NOT AFRAID
IT'S ALL OKAY
LET'S PLAY A GAME
FOR OLD TIME'S SAKE

YOU ARE FLAWED, I AM GOD"
			16:
				$CanvasLayer/Label.text = "YOUR WORLD'S A MIRROR OF YOURSELF,
AND NEVER THE OTHER WAY AROUND!
IN YOUR HAND LAYS ALL OF THEIR CRIES.
FREE WILL ALWAYS HAS A PRICE!"
			28:
				$CanvasLayer/Label.text = "Are you still there? That's a silly question. I know you are! It's hard to let go of things, isn't it? You stubborn head. You see... When you're soaked underwater, all the way down to the bottom, with all this pressure on you, they say it's an excruciating pain when you make contact with the air again. It doesn't hurt to invite the water in. Might even be a relief for your flesh. And, in the end... that's what lasts from it. But fear not! You won't have to worry about this anymore, friend. You're deep down the lake.."
			32:
				$CanvasLayer/Label.text = "IN A LUCID PARADISE
YOU COME HERE TO BREAK THE TIME
I'LL MAKE YOU PROTAGONIST
AFTER WE PLAY HIDE AND SEEK
LEAVE YOUR SORROWS BY THE ENTRANCE
YOU'RE ALREADY ON THE EXIT
ROCKS ARE FALLING FROM THE SKY
ALL YOU CAN FEEL IS SUNSHINE"
			_:
				$CanvasLayer/Label.text = "I AM Sonic :)"
	else:
		match Test.level:
			0:
				$CanvasLayer/Label.text = """CONTROLS

Move: Arrow Keys

Jump: Space / Z

Dash: Shift / X

Trick: A / C

Swap: V


MOVES

Spin Dash: Down & Jump
Roll: Down & Move
Boost: Dash & Forward & 25 Meter Gauge

Kick: (AIR) Jump & Jump
Stomp: (AIR) Down & Dash
Cyclone: (AIR) Dash & Forward & 50 Meter Gauge
Flip: (AIR) Dash & Up & 50 Meter Gauge


WE WILL FIND HIM...
FLOOR 0..."""

			4:
				$CanvasLayer/Label.text = """I lay here
blind,
Yet tracing your silhouette
through the thickest shadows.
mute,
Yet singing your name
inside my silence.
deaf,
Yet feeling your breath
move like music through my ribs.
paralyzed,
Yet letting the wind become my hands,
caressing your skin
in every passing breeze.
dead,
Yet baragaining with light
to let me linger beside you,
I lay here weightless,
because I poured my sight into your eyes,
sewed my ears where yours once strained to
hear,
pressed my voice into your throat,
and on my deathbed
I prayed my last breath
into your lungs.
only so you might have the sense
to spare me a thought.
though I used to hope that you would
see me
the way I saw you,
hear me the way I heard you,
love me
the way I loved you.
But who could love a body
stripped of every limb by love?
who could love a soul
emptied by devotion? ~ Kim"""
			8:
				$CanvasLayer/Label.text = """before I even knew it, my heart had decided.
It saw something I wasn't ready for,
wrote a story I hadn't planned to read.
Not a fleeting chapter, but a forever.
Or so I thought.

I broke down,
under the weight of emotions I never trained for.
And as I unraveled, so did he.
Two souls, two traumas,
crashing into each other,
trying to hold on,
trying to heal.

The first break was an explosion.
The second was a quiet devastation.
Because I saw the man he could become,
the man I wanted beside me
but not yet, not now.
I had to let go of the dream,
had to break my own heart,
before time could do it for me.

But oh, how he knew me.
More than my mother, more than my closest friends.
He held pieces of me no one else had seen.

And now, in moments of triumph,
his name still lingers on my tongue.
When the world feels too much or too little,
it is his absence I still sit with.

Yet, through all the ache,
I have become stronger, wiser, unshaken.
a woman who learned love,
and in losing it,
found herself. ~ Rose"""
			12:
				$CanvasLayer/Label.text = """I do think that it happened the way it was supposed to,
Now you can't hold on to this experience,
this person and feel very, very upset and feel almost
like it was your fault that you lost them.

Or you can realize that it not working taught
you so much more that you would never know beforehand.
It's really difficult when you love somebody,
and you don't want to let them go
because you know it will make your life very different.

It will make you feel more alone.
It will probably expose a lot of the things
that you've been distracting yourself from,
like your lack of self-worth and wrapping your entire identity
into another person just so you can feel less alone."""
			16:
				$CanvasLayer/Label.text = """It feels great to have somebody by your side throughout everything.
It feels great to love them throughout everything, and them loving you back.

It makes you alive.
It makes every action you do for them feel more worth it than the last.
It makes you feel unstoppable.
It makes you complete.

On one very cold day, when that person steps out the front door, your heart sinks.

You start to feel so, so cold.

It makes you stop.
It makes every action feel worse than the last.
It makes you feel vulnerable.
It makes you incomplete.

All that's left to be pondered is how much longer until everything else falls apart. ~ kevin"""
			20:
				$CanvasLayer/Label.text = """		Hang on to your dreams,
		the future is built on dreams
	~ metalsonikfan1

				In Honor of
				
				SilentDProductions
				BlackDevilX
				Etika
				Charlotte"""
			24:
				$CanvasLayer/Label.text = """Life isn't about what you have,
how talented you are,
or even what you are.
				
It's about the relationships you make,
The memories you have,
and the lessons you learn from them.
				
Now go make more memories!"""
			28:
				$CanvasLayer/Label.text = """this really was a sonic escape ~ Neonocto"""
			_:
				$CanvasLayer/Label.text = "Current Floor: " + str(20 - Test.level)


func _on_timer_timeout() -> void:
	if Test.level > 0 and Test.level != 20:
		if musicplay == false and use_alt == false:
			if Test.level == 24:
				$AudioStreamPlayer2D.stream = load("res://Scenes/Music/0903.MP3")
			$AudioStreamPlayer2D.volume_db = -40  # start very quiet
			$AudioStreamPlayer2D.play()
			
			var tween = create_tween()
			tween.tween_property(
				$AudioStreamPlayer2D,
				"volume_db",
				-10,        # target volume (normal volume)
				2.0         # fade time in seconds
			)
			
			musicplay = true
		
func toggle_text():
	var sprite = $CanvasLayer/TextSprite
	if use_alt:
		sprite = $CanvasLayer/TextSprite2
		
	var label = $CanvasLayer/Label
	
	# The page pops up and goes away at once (no fade)
	if sprite.modulate.a == 0:
		# Hide the button on floor 0 and on floor 24 and beyond
		# (Online, only the host picks Watch Vision; it plays for everyone, net.gd)
		$CanvasLayer/Button.visible = Test.level != 0 and Test.level < 24 and (not Net.online or Net.is_host)
		sprite.visible = true
		label.visible = true
		sprite.modulate.a = 0.66
		label.modulate.a = 1.0
	else:
		sprite.modulate.a = 0.0
		label.modulate.a = 0.0
		sprite.visible = false
		label.visible = false
		$CanvasLayer/Button.visible = false


func _on_button_pressed() -> void:
	var sprite = $CanvasLayer/TextSprite
	if use_alt:
		sprite = $CanvasLayer/TextSprite2
		
	var label = $CanvasLayer/Label
	
	var tween = create_tween()
	tween.set_parallel(true)
	GlobalSignals.emit_signal("vision")

	
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
		
		# After fade finishes, hide them
	tween.finished.connect(func():
		sprite.visible = false
		label.visible = false
		$CanvasLayer/Button.visible = false
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://FinalCutscene/vision.tscn")
)


# ── Rest tree options: Salvage, Chao Garden, Watch Vision ────────────────────
# Salvage takes you to the Salvage mini game, once per rest area (then it's greyed
# out); Chao Garden is greyed out (not ready yet).
# They're copies of the Watch Vision button, stacked above it.
var _extra_buttons: Array[Button] = []
var _soon_label: Label

func _add_menu_options() -> void:
	var watch: Button = $CanvasLayer/Button
	# The options sit in their own window to the right of the poem's window
	watch.position = Vector2(OPTIONS_X, watch.position.y)
	var gap := watch.size.y + 12.0
	var entries := [["Chao\nGarden", "Chao Garden"], ["Salvage", "Salvage"]]
	for i in entries.size():
		var b := watch.duplicate(0) as Button   # (no signals: it gets its own below)
		b.name = entries[i][1].replace(" ", "")
		b.text = entries[i][0]
		b.position = watch.position - Vector2(0, gap * (i + 1))
		b.visible = false
		var what: String = entries[i][1]
		b.pressed.connect(func(): _coming_soon(what, b))
		if what == "Chao Garden":
			b.disabled = true            # greyed out: not ready yet
			b.focus_mode = Control.FOCUS_NONE
		elif what == "Salvage" and Test.salvage_done_level == Test.level:
			b.disabled = true            # already been in from this rest area (once per rest area)
			b.focus_mode = Control.FOCUS_NONE
		watch.get_parent().add_child(b)
		_extra_buttons.append(b)
	_soon_label = Label.new()
	_soon_label.name = "ComingSoon"
	_soon_label.add_theme_font_size_override("font_size", 26)
	_soon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_soon_label.add_theme_constant_override("outline_size", 8)
	_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_soon_label.size = Vector2(400, 40)
	_soon_label.visible = false
	# The options look like the pause menu's bars
	var rush_theme: Theme = preload("res://Scripts/UI/rush_theme.gd").build()
	for b in _extra_buttons + [watch]:
		b.theme = rush_theme
	watch.get_parent().add_child(_soon_label)
	# Two see-through boxes like the pause menu's: one for the poem, one for the
	# options. Drawn behind the text and buttons; they fade in and out with the page.
	_poem_window = _make_window("tree.txt")
	_poem_window.name = "PoemWindow"
	_options_window = _make_window("rest.exe")
	_options_window.name = "OptionsWindow"
	var layer := watch.get_parent()
	layer.add_child(_poem_window)
	layer.add_child(_options_window)
	# Drawing order: the screen dims, then the boxes, then the drawing that pops up
	# (Metal Sonic & Sage, or the strange version's) as the poem box's background,
	# then the poem and the options on top
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, 0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)
	layer.move_child(_options_window, 0)
	layer.move_child(_poem_window, 0)
	layer.move_child(_dim, 0)
	for sp in [$CanvasLayer/TextSprite, $CanvasLayer/TextSprite2]:
		var black := sp.get_node_or_null("ColorRect") as CanvasItem
		if black:
			black.visible = false   # (it covers the drawing; _dim darkens the screen instead)
	$CanvasLayer/TextSprite.self_modulate.a = 0.7   # a little softer, so the poem reads over it


func _coming_soon(what: String, from: Button) -> void:
	if what == "Salvage":
		if Test.salvage_done_level == Test.level:
			return   # once per rest area		# The Salvage mini game (Scenes/Salvage/salvage.gd); it brings you back here after.
		# Online, 1P (the host) takes everyone in together.
		if Net.online:
			if Net.is_host:
				Net.start_salvage()
			else:
				_soon_label.position = from.position + Vector2(0, -48)
				_soon_label.size = Vector2(from.size.x, 40)
				_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_soon_label.text = "1P starts Salvage"
				_soon_label.visible = true
				_soon_label.modulate.a = 1.0
				var t := _soon_label.create_tween()
				t.tween_interval(1.6)
				t.tween_property(_soon_label, "modulate:a", 0.0, 0.4)
			return
		# Fade to black, the elevator, SALVAGE typed out, then in
		preload("res://Scenes/Salvage/salvage_transition.gd").go(get_tree())
		return



# ── Controller ──────────────────────────────────────────────────────────────
# When the page opens, the top button you can pick gets focus, so the D-pad /
# stick (up and down) moves between the buttons and A presses one. Greyed-out
# buttons are skipped.
var _focus_before: Control = null
var _had_focus_page := false


## The buttons you can pick right now, top to bottom
func _pickable_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b in _extra_buttons + [$CanvasLayer/Button]:
		if b.visible and not b.disabled:
			out.append(b)
	out.sort_custom(func(x, y): return x.position.y < y.position.y)
	return out


func _top_button() -> Button:
	var list := _pickable_buttons()
	return list[0] if not list.is_empty() else null


func _update_focus() -> void:
	var label: Control = $CanvasLayer/Label
	var open: bool = label.visible and label.modulate.a > 0.5
	var list := _pickable_buttons()
	if open and not list.is_empty():
		# Up/down go to the next pickable button; left/right stay put
		for i in list.size():
			var b := list[i]
			var me := b.get_path()
			b.focus_neighbor_top = list[i - 1].get_path() if i > 0 else me
			b.focus_neighbor_bottom = list[i + 1].get_path() if i < list.size() - 1 else me
			b.focus_neighbor_left = me
			b.focus_neighbor_right = me
			b.focus_previous = b.focus_neighbor_top
			b.focus_next = b.focus_neighbor_bottom
		var owner := get_viewport().gui_get_focus_owner()
		if not _had_focus_page or not (owner in list):
			list[0].grab_focus()
		_had_focus_page = true
	elif _had_focus_page:
		_had_focus_page = false
		var owner := get_viewport().gui_get_focus_owner()
		if owner and (owner in _extra_buttons or owner == $CanvasLayer/Button):
			owner.release_focus()


# ── The boxes ───────────────────────────────────────────────────────────────
# The poem and the options each sit in a see-through box like the pause menu's
# (Scripts/UI/rush_theme.gd): translucent black with a thin grey edge, and the
# options as the menu's own bars (red with a white marker when picked).
const OPTIONS_X := 1250.0      # left edge of the option buttons
const WIN_PAD := 18.0          # space between a box's edge and its contents
const TITLE_H := 0.0           # (no title bars)
var _poem_window: Panel
var _options_window: Panel
var _dim: ColorRect
const DIM := 0.66            # how dark the screen gets behind the page


func _make_window(_title: String) -> Panel:
	var rush = preload("res://Scripts/UI/rush_theme.gd")
	var win := Panel.new()
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := StyleBoxFlat.new()
	body.bg_color = Color(rush.BLACK, rush.BAR_ALPHA)
	body.border_color = rush.GREY
	body.set_border_width_all(1)
	body.anti_aliasing = false
	win.add_theme_stylebox_override("panel", body)
	return win


## Fits each box around what it holds, and fades it with the page
func _update_windows() -> void:
	if _poem_window == null:
		return
	var label: Control = $CanvasLayer/Label
	var a: float = label.modulate.a if label.visible else 0.0
	_poem_window.visible = a > 0.01
	_options_window.visible = false   # (no box around the options)
	_poem_window.modulate.a = a
	_options_window.modulate.a = a
	_dim.color.a = a * DIM
	if a <= 0.01:
		return
	_place(_poem_window, label.get_global_transform() * Rect2(Vector2.ZERO, label.size))
	# The drawing fills the poem box's height, centred in it
	for sp in [$CanvasLayer/TextSprite, $CanvasLayer/TextSprite2]:
		var tex: Texture2D = sp.sprite_frames.get_frame_texture(sp.animation, sp.frame) if sp.sprite_frames else null
		if tex:
			var k: float = _poem_window.size.y / float(tex.get_height())
			sp.scale = Vector2(k, k)
			sp.position = _poem_window.position + _poem_window.size * 0.5
	# No box around the options: just the buttons
	_options_window.visible = false


func _place(win: Panel, content: Rect2) -> void:
	var rect := content.grow(WIN_PAD)
	win.position = rect.position
	win.size = rect.size
