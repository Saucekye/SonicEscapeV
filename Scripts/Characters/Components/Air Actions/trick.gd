extends Components_Action

func action() -> void:
	if not (player.inp_just_pressed("trick") and not (player.is_on_wall_only() and (not player.raycast.is_colliding()) and player.rot == 0) and not player.flying):
		return
	
	# Prevent player from doing action while on wall
	if player.wall_cast.is_colliding() or player.wall_cast_2.is_colliding():
		return
	if player.finished_in_air:
		return   # after the finisher, no more tricks till you land
	
	# Down + trick, mid-chain
	if player.is_player and player.inp_pressed("ui_down") and GlobalCanvasLayer.tricks >= FINISH_AFTER:
		player.finished_in_air = true
		_finish()
		return

	# Cycle through trick animations in order; gain meter and count tricks
	player.dashed = true
	player.falling = true
	if player.is_player == true:
		if not player.insta_used:
			player.insta_shield()
		player.my_meter += Test.trick_meter(2)
		GlobalCanvasLayer.tricks += 1
		Test.tricks_done += 1   # run total, scored on the results screen
		_points_popup(Test.TRICK_SCORE)
		player.boost_sprite.visible = false
		
	var tricks = ["trick1", "trick2", "trick3", "trick4"]
	var last_index = tricks.find(player.last_trick)
	var next_index = (last_index + 1) % tricks.size()  # Always moves to the next in sequence
	var new_trick = tricks[next_index]
	player.last_trick = new_trick
	player.sparkemit()
	player.sfx.pitch_scale = 1
	player.sfx.stream = load("res://Sounds/SonicSFX/sparklesfx.MP3")
	player.sfx.play()
	player.ap.play(new_trick)
	await get_tree().create_timer(0.3).timeout
	# Only re-enable dash/fall if trick button was released during the animation
	if not player.inp_pressed("trick"):
		player.dashed = false


const FINISH_AFTER := 3           ## tricks it takes before you can finish
const FINISH_METER_EACH := 4      ## meter for every trick in the chain
const FINISH_BOOST := 900.0       ## the burst forward, plus a bit more for every trick
const FINISH_BOOST_EACH := 30.0
const FINISH_BOOST_MAX := 1700.0

func _finish() -> void:
	var tricks: int = GlobalCanvasLayer.tricks
	player.rate_chain(tricks, true)      # Miku's rating, one better than landing would get
	GlobalCanvasLayer.tricks = 0
	player.my_meter += Test.trick_meter(tricks * FINISH_METER_EACH)
	var dir := -1.0 if player.sprite.flip_h else 1.0
	var speed := minf(FINISH_BOOST + tricks * FINISH_BOOST_EACH, FINISH_BOOST_MAX)
	player.motion.x = dir * maxf(absf(player.motion.x), speed)
	player.motion.y = minf(player.motion.y, -150.0)   # a little lift
	player.dashed = true
	player.falling = true
	player.sparkemit()
	player.sparkemit()
	player.sfx.pitch_scale = 1.3
	player.sfx.stream = load("res://Sounds/SonicSFX/Trick.wav")
	player.sfx.play()
	player.ap.play("trick4")
	_spin_sprite()
	_confetti(tricks)
	if player.has_meta("trick_counter") and is_instance_valid(player.get_meta("trick_counter")):
		player.get_meta("trick_counter").finish()
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(FINISH_SHAKE_TIME, FINISH_SHAKE)
	else:
		GlobalSignals.camerashake.emit()
	await get_tree().create_timer(0.3).timeout
	player.dashed = false


const FINISH_SHAKE := 7.0          ## how hard the screen shakes
const FINISH_SHAKE_TIME := 0.4
const CONFETTI_AMOUNT := 120        ## confetti for a big chain
const CONFETTI_LEAST := 18          ## confetti for the shortest chain you can finish
const CONFETTI_FULL_AT := 15        ## tricks for all of it
const CONFETTI_PIECES := ["res://Sprites/Effects/Confetti/confetti_0.png", "res://Sprites/Effects/Confetti/confetti_1.png", "res://Sprites/Effects/Confetti/confetti_2.png", "res://Sprites/Effects/Confetti/confetti_3.png", "res://Sprites/Effects/Confetti/confetti_4.png", "res://Sprites/Effects/Confetti/confetti_5.png"]   ## Sonic Rush's confetti
const CONFETTI_SCALE := 3.0        ## how big the pieces are

## The finisher's spin
func _spin_sprite() -> void:
	player.finish_spin = 0.0
	player.finish_spinning = true


## Confetti bursting up from the bottom of the screen, like the Rush games
func _confetti(tricks: int) -> void:
	var k := clampf(float(tricks - FINISH_AFTER) / float(CONFETTI_FULL_AT - FINISH_AFTER), 0.0, 1.0)
	var total := lerpf(CONFETTI_LEAST, CONFETTI_AMOUNT, k)
	var layer := CanvasLayer.new()
	layer.layer = 60
	get_tree().current_scene.add_child(layer)
	var size := get_viewport().get_visible_rect().size
	for path in CONFETTI_PIECES:
		var p := CPUParticles2D.new()
		p.texture = load(path)
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.one_shot = true
		p.explosiveness = 0.85
		p.amount = maxi(int(total / CONFETTI_PIECES.size()), 1)
		p.lifetime = 2.2
		p.position = Vector2(size.x * 0.5, size.y + 10)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(size.x * 0.5, 4)
		p.direction = Vector2(0, -1)
		p.spread = 25.0
		p.initial_velocity_min = size.y * 0.9
		p.initial_velocity_max = size.y * 1.4
		p.gravity = Vector2(0, size.y * 1.1)
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.scale_amount_min = CONFETTI_SCALE * 0.8
		p.scale_amount_max = CONFETTI_SCALE * 1.2
		p.damping_min = 20.0
		p.damping_max = 60.0
		layer.add_child(p)
		p.emitting = true
	get_tree().create_timer(2.6).timeout.connect(layer.queue_free)


const TRICK_COUNTER := preload("res://Scripts/Effects/trick_counter.gd")

# The chain's running total over your head, like Sonic Rush Adventure
func _points_popup(points: int) -> void:
	TRICK_COUNTER.for_player(player).add(points)
