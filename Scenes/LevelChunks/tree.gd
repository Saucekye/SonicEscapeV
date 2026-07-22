extends Area2D

var player_inside := false
var musicplay = false
var use_alt := false  # true = show the alternate text set on Label

func _ready():
	$Arrow.visible = false
	$AudioStreamPlayer.play()
	$CanvasLayer/TextSprite.visible = false
	$CanvasLayer/TextSprite2.visible = false
	
	$CanvasLayer/Label.visible = false
	
	$CanvasLayer/TextSprite.modulate.a = 0
	$CanvasLayer/TextSprite2.modulate.a = 0
	$CanvasLayer/Label.modulate.a = 0
		
	randomize()
	if randf() < 0.25:
		use_alt = true
		$Node2D.visible = false
		$Node2D4.visible = false
		$Sprite2D.visible = false
		$AnimatedSprite2D.visible = true
	else:
		use_alt = false
		$Node2D.visible = true
		$Node2D4.visible = true
		$Sprite2D.visible = true
		$AnimatedSprite2D.visible = false


func _process(delta):
	if player_inside and Input.is_action_just_pressed("ui_up"):
		toggle_text()
		if use_alt:
			$CanvasLayer/PageSfx.stream = load("res://Sounds/SFX/rewrite-laughing-lol.mp3")
		else:
			$CanvasLayer/PageSfx.stream = load("res://Sounds/SFX/page-flip-01a.mp3")
			$CanvasLayer/PageSfx.play()
		
		# Only change text when opening
		if $CanvasLayer/Label.visible:
			update_text()
			
		if musicplay == false:
			$Timer.start()
		
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
		if use_alt:
			$CanvasLayer/PageSfx.play()
			
		
func update_text():
	if use_alt:
		match Test.level:
			0:
				$CanvasLayer/Label.text = "LET'S PLAY A GAME
YOU CAN CHOOSE YOUR FAVORITE THING
THIS CLICHE NEVER DIES
YOU CAN'T RUN AND YOU CAN'T HIDE!"
			4:
				$CanvasLayer/Label.text = "LET YOUR SPIRIT
LEAVE YOUR BODY
I AM GOD
AND YOU'RE NOBODY!"
			8:
				$CanvasLayer/Label.text = "BE NOT AFRAID
IT'S ALL OKAY
LET'S PLAY A GAME
FOR OLD TIME'S SAKE

YOU ARE FLAWED, I AM GOD"
			12:
				$CanvasLayer/Label.text = "YOUR WORLD'S A MIRROR OF YOURSELF,
AND NEVER THE OTHER WAY AROUND!
IN YOUR HAND LAYS ALL OF THEIR CRIES.
FREE WILL ALWAYS HAS A PRICE!"
			16:
				$CanvasLayer/Label.text = "Are you still there? That's a silly question. I know you are! It's hard to let go of things, isn't it? You stubborn head. You see... When you're soaked underwater, all the way down to the bottom, with all this pressure on you, they say it's an excruciating pain when you make contact with the air again. It doesn't hurt to invite the water in. Might even be a relief for your flesh. And, in the end... that's what lasts from it. But fear not! You won't have to worry about this anymore, friend. You're deep down the lake.."
			20:
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
				$CanvasLayer/Label.text = """Controls

Move: Arrow Keys
Jump: Space/Z | Air Dash: Shift/X | Air Tricks: A 
Character Swap: V / Tap Player Icon

Move List:
Ball Curl: (Ground/Air) Down + Moving
Uncurl: (Ground) Up | Air Dash | Air Trick
Spin Dash: (Ground) Down + Idle + Jump
Super Peel Out: (Ground) Up + Idle + Jump (Hold)

Kick: (Air) Jump + Jump
Drop Dash: (Air) Jump (Hold)
Stomp: (Air) Down + Air Dash
Cyclone: (Air) Air Dash+ Forward
Flip: (Air) Air Dash + Up"""
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
emptied by devotion?"""
			8:
				$CanvasLayer/Label.text = """When should you give up on somebody? On something? On a dream?
On yourself?

When is it okay to finally call it quits and tell yourself
it wasn't worth it, it never was?

Well, I think if you're looking at things that way, what's the point of doing anything?

Because a lot of us, we like to relish in the mistakes
that we've made in the past, instead of recognizing that if we had not
made them, we would have never learned.

But with people it's different,
because there's a lot more time that gets sunk into relationships"""
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

All that's left to be pondered is how much longer until everything else falls apart."""
			20:
				$CanvasLayer/Label.text = """But then came him—
before I even knew it, my heart had decided.
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
found herself."""
			_:
				$CanvasLayer/Label.text = "Current Floor: " + str(Test.level)


func _on_timer_timeout() -> void:
	if Test.level > 0:
		if musicplay == false and use_alt == false:
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
	
	var tween = create_tween()
	tween.set_parallel(true)

	# If currently invisible → fade in
	if sprite.modulate.a == 0:
		sprite.visible = true
		label.visible = true
		
		tween.tween_property(sprite, "modulate:a", 0.66, 0.3)
		tween.tween_property(label, "modulate:a", 1.0, 0.3)
	else:
		# Fade out
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(label, "modulate:a", 0.0, 0.3)
		
		# After fade finishes, hide them
		tween.finished.connect(func():
			sprite.visible = false
			label.visible = false
		)
