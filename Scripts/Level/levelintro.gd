extends CanvasLayer

signal start

@onready var animation_player = $Node2D/AnimationPlayer
@onready var particles = $ParticleSystem
@onready var flash_overlay = $FlashOverlay
@onready var title_label = $TitleContainer/TitleLabel
@onready var subtitle_label = $TitleContainer/SubtitleLabel
@onready var glow_effect = $GlowEffect
@onready var audio_player = $AudioStreamPlayer
@onready var tween: Tween

var flash_colors = [Color.CYAN, Color.MAGENTA, Color.YELLOW, Color.WHITE]
var current_flash = 0

func _ready() -> void:
	$Node2D/Label.text = "FLOOR " + str(Test.level) 
	if Test.music == false:
		Test.music = true
	# Set initial states for optional elements
	if title_label:
		title_label.modulate.a = 0.0
	if subtitle_label:
		subtitle_label.modulate.a = 0.0
	if flash_overlay:
		flash_overlay.modulate.a = 0.0
	if glow_effect:
		glow_effect.modulate.a = 0.0
	
	# Start your original animation AND flashy effects
	animation_player.play("start")
	start_flashy_intro()

func start_flashy_intro():
	# Start particle effects immediately
	if particles:
		particles.emitting = true
	
	# Play epic sound effect
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Start glow pulsing effect
	pulse_glow_effect()
	
	# Wait a moment then start title animation and flashes
	await get_tree().create_timer(0.5).timeout
	animate_title_entrance()

func animate_title_entrance():
	if not title_label:
		return
		
	var title_tween = create_tween()
	title_tween.set_parallel(true)
	
	# Title slides in from top with bounce
	var original_y = title_label.position.y
	title_label.position.y -= 100
	title_tween.tween_property(title_label, "position:y", original_y, 0.8)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
	title_tween.set_ease(Tween.EASE_OUT)
	title_tween.set_trans(Tween.TRANS_BOUNCE)
	
	# Subtitle fades in with delay
	if subtitle_label:
		await get_tree().create_timer(0.4).timeout
		var subtitle_tween = create_tween()
		subtitle_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)
	
	# Start screen flashes
	await get_tree().create_timer(0.6).timeout
	start_flash_sequence()

func pulse_glow_effect():
	if not glow_effect:
		return
		
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow_effect, "modulate:a", 0.8, 1.0)
	glow_tween.tween_property(glow_effect, "modulate:a", 0.2, 1.0)
	glow_tween.set_ease(Tween.EASE_IN_OUT)

func start_flash_sequence():
	for i in range(3):
		create_screen_flash()
		await get_tree().create_timer(0.3).timeout
	
	# Don't auto-finish - wait for AnimationPlayer to complete

func create_screen_flash():
	if not flash_overlay:
		return
		
	var flash_color = flash_colors[current_flash % flash_colors.size()]
	current_flash += 1
	
	flash_overlay.color = flash_color
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.7, 0.1)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.2)

func shake_screen():
	var shake_tween = create_tween()
	var original_pos = Vector2(0,0)
	
	for i in range(10):
		var shake_offset = Vector2(
			randf_range(-5, 5),
			randf_range(-5, 5)
		)
		shake_tween.tween_property(self, "position", original_pos + shake_offset, 0.05)
	
	shake_tween.tween_property(self, "position", original_pos, 0.1)

func finish_intro():
	# Add screen shake for impact
	shake_screen()
	
	# Final flash
	create_screen_flash()
	
	await get_tree().create_timer(0.5).timeout
	
	# Fade out dramatically
	var outro_tween = create_tween()
	outro_tween.set_parallel(true)
	outro_tween.tween_property(self, "modulate:a", 0.0, 1.0)
	outro_tween.tween_property(title_label, "scale", Vector2(1.5, 1.5), 1.0)
	outro_tween.set_ease(Tween.EASE_IN)
	
	await outro_tween.finished
	
	# Emit signal and cleanup
	emit_signal("start")
	queue_free()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	# Keep your original animation support
	if anim_name == "start":
		finish_intro()

# Optional: Skip intro on input
func _input(event):
	if event.is_pressed():
		finish_intro()
