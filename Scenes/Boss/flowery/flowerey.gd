extends Node2D

signal health_changed(current: int, maximum: int)
# Same signal the other bosses use to drive the boss HP bar
signal update_health_bar(boss_health: int, boss_max_health: int)
signal phase_changed(new_phase: int)
signal defeated
signal end # emitted on death; the chunk's level script listens to this
signal lunge_done
# Halfway transition internals (the transition waits for both before showing the heart)
signal voices_finished
signal wipe_finished
# Lilypad chain: how many jumps in a row the heart has made (0 = not jumping). Use it to speed attacks up.
signal lilypad_chain_changed(count: int)

enum State { INACTIVE, INTRO, IDLE, ATTACKING, TRANSITION, DYING }


# ---------------- TUNING ----------------
# Inspector layout (every group is a dropdown):
#   General                    health, bar, music, chase, flow
#   Phase 1                    every attack so far (Jarona, Jarona 2, Jarona 3)
#   Middle Point (Transition)  parry + exit, voices, screen wipe and the heart section
#   Phase 2                    empty for now, no attacks yet
#   Debug                      testing helpers

# =====================================================================
@export_group("General")
# =====================================================================
@export_subgroup("Health")
# true: health is computed like the other bosses, clamp(Test.level * 2, 15, 50).
# false: the max_health value below is used as is.
@export var scale_health_with_level: bool = true
@export var max_health: int = 30
# Fraction of his real HP the bar shows (the top part). 0.5 = the bar is empty when he reaches 50%.
@export_range(0.1, 1.0, 0.05) var visible_health_fraction: float = 0.5

@export_subgroup("Phases")
@export var phase_thresholds: Array[float] = [0.5]
# One entry per phase: element 0 = Phase 1, element 1 = Phase 2
@export var idle_times: Array[float] = [3.0, 1.8]
@export var hits_to_interrupt_idle: int = 3

@export_subgroup("Fight Flow")
# true: the fight starts as soon as the scene loads.
# false: it waits until begin_fight() is called (e.g. from the level intro's "start" signal).
@export var auto_start: bool = true
# Where Flowery waits while idling and returns to between lunges.
# Add a Marker2D named "IdlePoint" under this node and move it where you want him.
# If there is none, he uses the position his sprite has when the fight starts.
@export var home_return_time: float = 0.4

@export_subgroup("Music")
# Song + synced lyrics (FloweryLyrics node). Started with the fight, faded out on death.
@export var lyrics: FloweryLyrics
# true: the song keeps playing through the whole middle point (the transition).
# false: it fades out when the transition starts.
@export var keep_music_during_transition: bool = true
# true: the lyrics text is drawn over the black screen of the transition.
# Only the text label moves (into its own CanvasLayer above the black); the song is not touched.
@export var show_lyrics_over_black: bool = true

@export_subgroup("Chase")
# The player is constantly pushed to the left while the fight is active
@export var chase_push_speed: float = 100.0
@export var chase_phase_bonus: float = 0.5 # extra push per phase (0.5 = +50% in phase 2)

@export_subgroup("Trail")
# A constant trail behind him, pushed to the left so it looks like he is always moving to the right.
@export var trail_enabled: bool = true
@export var trail_interval: float = 0.04 # seconds between one copy and the next
@export var trail_life: float = 0.4 # how long each copy lasts
@export var trail_drift: float = 160.0 # px each copy is pushed to the left during its life
@export var trail_color: Color = Color(1.0, 1.0, 1.0, 0.4) # tint + starting opacity of the copies (with rainbow on, only its opacity is used)
@export var trail_rainbow: bool = true # each copy gets the next colour of the rainbow
@export var trail_rainbow_speed: float = 1.0 # full rainbow cycles per second
@export_range(0.0, 1.0, 0.05) var trail_rainbow_saturation: float = 0.7 # lower = paler colours


# =====================================================================
@export_group("Phase 1")
# =====================================================================
@export_subgroup("Attack: Jarona (homing lunge)")
@export var jarona1Count: int = 4
@export var jarona1StartSpeed: float = 600.0
@export var jarona1SpeedIncrease: float = 100.0
@export var jarona1SpeedDecrease: float = 150.0
@export var jarona1MinSpeed: float = 300.0
@export var jarona1MaxSpeed: float = 1600.0
@export var jarona1MaxLungeTime: float = 2.0 # safety: lunge ends after this long even without a hit
@export var jarona1RecoilDistance: float = 140.0
@export var jarona1RecoilTime: float = 0.3
@export var jarona_voice_lines: Array[AudioStream] = []


@export_subgroup("Attack: Jarona 2 (lunge + hitboxes)")
# Homing lunge + summoned hitboxes, spawned after each punch. Uses the Jarona lunge settings above.
@export var jarona2HitboxScene: PackedScene # an Area2D scene; if empty, a placeholder circle (with no animation) is built in code
@export var jarona2HitboxAnim: StringName = &"" # played when the hitbox spawns; empty = autoplay, else the first non-RESET animation
@export var jarona2HitboxLaunchAnim: StringName = &"" # optional: played when it launches forward
@export var jarona2HitboxRadius: float = 28.0 # placeholder only
@export var jarona2HitboxSpread: float = 90.0 # distance of each hitbox from his centre, perpendicular to the lunge
@export var jarona2BackDistance: float = 120.0 # how far past the idle point they drift
@export var jarona2BackTime: float = 0.35 # drift back + settle on the player's altitude, then launch immediately
@export var jarona2LockOffsetMin: float = 0.0 # px above/below the player's altitude (0 = exact)
@export var jarona2LockOffsetMax: float = 90.0
@export var jarona2ForwardSpeed: float = 700.0
@export var jarona2ForwardDistance: float = 1800.0
@export var jarona2FlipToDirection: bool = false # flip the hitbox to face its travel direction (assumes the art faces right)

@export_subgroup("Attack: Jarona 3 (walls)")
# Walls of three hitboxes: ground + ceiling always hurt, the middle one breaks when the player stomps/attacks it.
# Positions below use the arena's coordinates (the same numbers the editor shows for nodes in the arena scene).
@export var jarona3Count: int = 3 # how many walls per attack
@export var jarona3Spacing: float = 500.0 # distance in px between one wall and the next
@export var jarona3Speed: float = 500.0
@export var jarona3SpaceNode: NodePath # node whose coordinates the four numbers below use. Empty = Flowery's parent (the arena)
@export var jarona3StartX: float = 2000.0 # x where each wall appears
@export var jarona3EndX: float = 500.0 # x where it is removed
@export var jarona3GroundY: float = 700.0 # y of the floor: the bottom of the ground block sits here
@export var jarona3CeilingY: float = 70.0 # y of the ceiling: the top of the ceiling block sits here
@export var jarona3WindupTime: float = 0.5 # Flowery's windup before the first wall
@export var jarona3TelegraphTime: float = 0.4 # each wall shows up faded and harmless this long before it launches
@export var jarona3HitboxWidth: float = 60.0 # thickness of the ground/ceiling blocks (the safe block uses its texture's width when it has one)
@export var jarona3MiddleSizeMin: float = 60.0 # height of the middle block (random between min and max)
@export var jarona3MiddleSizeMax: float = 160.0
@export var jarona3MiddleHeightMin: float = 150.0 # centre of the middle block, px above the ground (random between min and max)
@export var jarona3MiddleHeightMax: float = 400.0

@export_subgroup("Attack: Jarona 3 (wall art)")
# Leave empty to keep the placeholder rectangles (red = hurts, blue = safe/breakable).
# The collision box always matches the block size.
enum WallArt { STRETCH, TILE } # STRETCH: art is scaled to fill the block. TILE: art repeats at its own size.
@export var jarona3HurtTexture: Texture2D # ground + ceiling blocks (width = jarona3HitboxWidth)
@export var jarona3SafeTexture: Texture2D # middle block: keeps the texture's own width, only its height changes
@export var jarona3SafeTint: Color = Color(0.4, 0.7, 1.0) # tint applied to the safe texture (white = no tint); also the colour of the break particles
@export var jarona3ArtMode: WallArt = WallArt.STRETCH
@export var jarona3FlipToDirection: bool = false # mirror the wall to face its travel direction (assumes the art faces right)


# =====================================================================
@export_group("Middle Point (Transition)")
# =====================================================================
@export_subgroup("1. Parry, Exit & Voices")
# At transition_health_ratio of his HP his health locks there, he gets parried and leaves the screen.
@export var halfway_transition: bool = true
@export_range(0.0, 1.0, 0.01) var transition_health_ratio: float = 0.5
@export var parried_anim: StringName = &"Deflected" # the "parried" animation (the one the recoil already uses)
@export var parried_hold_time: float = 0.5 # how long he stays on screen playing it before leaving
@export var exit_direction: Vector2 = Vector2.RIGHT # direction he flies off in (to the right, off screen)
@export var exit_margin: float = 300.0 # extra distance past the screen edge
@export var exit_time: float = 0.9
@export var transition_voice_1: AudioStream # played first...
@export var transition_voice_2: AudioStream # ...and this one right after it
# true: the real player nodes are paused during the transition (the heart is controlled instead),
# so they can't walk off or get hurt behind the black screen.
@export var freeze_players_during_transition: bool = true

@export_subgroup("1b. Surge (drags the player up)")
# After he leaves to the right he surges up from below the screen, right under the player, and carries
# the player (every player character) off the top of the screen. The screen wipe starts after this.
@export var surge_enabled: bool = true
@export var surge_texture: Texture2D # his look while he rises (empty = his normal sprite)
@export var surge_scale: Vector2 = Vector2.ONE
@export var surge_z_index: int = 10 # drawn above the players
@export var surge_time: float = 1.1
@export var surge_start_margin: float = 40.0 # extra distance below the screen where he starts
@export var surge_exit_margin: float = 150.0 # how far above the top edge the player ends up
@export var surge_sound: AudioStream

@export_subgroup("2. Screen Wipe")
# The rectangles that cover the screen, then it stays black.
@export var transition_layer: int = 90 # CanvasLayer index of the black overlay (the lyrics use this + 1, the heart this + 2)
@export var wipe_start_delay: float = 0.0 # seconds after the surge ends (or after he leaves, if the surge is off)
@export var wipe_rect_count: int = 5
@export var wipe_stagger: float = 0.3 # delay between one rectangle and the next
@export var wipe_grow_time: float = 0.9 # time each rectangle takes to grow past the screen
@export var wipe_max_tilt_deg: float = 6.0 # each rectangle is randomly rotated up to this many degrees either way
@export var wipe_line_width: float = 18.0
# Outline colour of each rectangle in order (the outer ones come first). Repeats if there are fewer colours than rectangles.
@export var wipe_outline_colors: Array[Color] = [Color(0.6, 0.6, 0.6), Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]

@export_subgroup("3. Heart: Look & Spawn")
# The heart the player controls during the transition. There is no box: the screen edges are its limits.
@export var heart_texture: Texture2D # put the heart image here (it is never rotated or flipped, so draw it facing right)
@export var heart_scale: Vector2 = Vector2.ONE
@export var heart_fade_time: float = 0.8
@export var heart_edge_margin: float = 0.0 # extra px kept between the heart and the screen edges
@export_range(0.1, 1.0, 0.05) var heart_hitbox_scale: float = 0.8 # hurtbox size relative to the heart's size

@export_subgroup("3. Heart: Movement")
# Free movement in all four directions, no gravity
@export var heart_speed: float = 260.0

@export_subgroup("3. Heart: Charge & Dash")
# Hold the charge button, release to dash right. A tap = weak dash, a longer hold = stronger dash.
@export_range(0.0, 1.0, 0.05) var heart_charge_burst: float = 0.5 # charge shoots up to this fast, then fills slowly
@export var heart_charge_time: float = 0.6 # seconds to fill from the burst point to full
@export var heart_charge_move_factor: float = 0.2 # walk speed multiplier at full charge
@export var heart_charge_color: Color = Color(1.0, 1.0, 0.3) # the heart tints towards this while charging
@export_range(0.0, 1.0, 0.05) var heart_weak_dash_threshold: float = 0.3 # below this charge the dash is a weak hop
@export var heart_weak_dash_speed: float = 350.0
@export var heart_dash_speed_min: float = 700.0 # strong dash at the threshold
@export var heart_dash_speed_max: float = 1500.0 # strong dash at full charge
@export var heart_dash_hold_time: float = 0.15 # full speed this long, then it decelerates
@export var heart_dash_decel: float = 4500.0
@export var heart_dash_steer: float = 0.5 # moving while dashing (fraction of walk speed)
@export var heart_dash_cooldown_max: float = 0.5 # after a weak dash
@export var heart_dash_cooldown_min: float = 0.17 # after a full dash

@export_subgroup("3. Heart: Dash Attack")
# The dash is an attack: it breaks BLUE attacks (like a regular character's jump/stomp does) and
# flies through them. Everything else still hurts, even during the dash.
@export var heart_weak_dash_attacks: bool = false # true: the weak hop breaks blue attacks too
@export var heart_dash_invulnerable: bool = false # true: the dash is also immune to non-blue attacks

@export_subgroup("3. Heart: Damage")
# When the heart is hurt, every player character is hurt too
@export var heart_iframes_time: float = 1.0

@export_subgroup("3. Heart: Sounds")
@export var heart_charge_sound: AudioStream # optional: loops while charging, pitch rises with charge
@export var heart_dash_light_sound: AudioStream
@export var heart_dash_heavy_sound: AudioStream

@export_subgroup("3. Heart: Hint")
# Hint shown on screen (behind the heart) until the first dash
@export var dash_hint_text: String = "press and hold Z"
@export var dash_hint_font: Font # optional
@export var dash_hint_font_size: int = 28
@export var dash_hint_color: Color = Color(1, 1, 1, 0.55)
@export_range(0.0, 1.0, 0.05) var dash_hint_screen_y: float = 0.4 # vertical position, as a fraction of the screen height

@export_subgroup("3. Heart: Controls")
# The heart is never rotated or flipped.
@export var heart_action_left: StringName = &"ui_left"
@export var heart_action_right: StringName = &"ui_right"
@export var heart_action_up: StringName = &"ui_up"
@export var heart_action_down: StringName = &"ui_down"
@export var heart_action_charge: StringName = &"ui_accept" # Z: hold to charge, release to dash

@export_subgroup("3. Heart: Lilypads")
# Touching a lilypad BOUNCES the heart forward: it is invincible, rises, grows and keeps its dash
# trail. Landing on another lilypad bounces it again. Aiming the dash onto the pads is up to the player.
@export var lilypad_enabled: bool = true
@export var lilypad_texture: Texture2D # put the lilypad image here
@export var lilypad_color: Color = Color(0.4, 0.7, 1.0) # blue tint on every lilypad (white = no tint, the texture's own colours)
@export var lilypad_scale: Vector2 = Vector2.ONE
@export var lilypad_size_multiplier: float = 2.0 # on top of lilypad_scale (2.0 = double size; the hitbox grows with it)
@export var lilypad_lock_heart: bool = true # the heart can't walk until it lands on the first lilypad
@export var lilypad_first_distance: float = 240.0 # how far in front of the heart the first lilypad stops
@export var lilypad_slide_time: float = 0.8
@export var lilypad_bounce_distance: float = 300.0 # how far forward (right) a bounce carries the heart; pads placed this far apart line up
# true: while jumping the heart stays at the same x on the screen and EVERYTHING ELSE (pads, cacti, every node in
# the group "heart_hazard", the trail) scrolls left by the distance of the jump instead. The movement between
# the heart and the attacks is exactly the same as before, it just looks like the screen is moving, not the heart.
@export var lilypad_hold_screen_x: bool = true
@export var lilypad_next_pad_range: float = 900.0 # a pad up to this far (x) beyond the pad you bounce off counts as "the next pad": the jump is calculated to land dead centre on it
@export var lilypad_hop_speed: float = 750.0 # px/s of a jump at "100%" speed (see Lilypad Speed-up for the first jump and the gains)
@export var lilypad_hop_time_min: float = 0.15 # a jump never lasts less than this...
@export var lilypad_hop_time_max: float = 1.5 # ...or more than this
@export var lilypad_jump_height: float = 110.0 # how high (px) the heart rises on screen at the top of the jump
@export var lilypad_jump_scale: float = 0.5 # extra size at the top of the jump (0.5 = 50% bigger)
@export var lilypad_shadow_color: Color = Color(0.45, 0.28, 0.12, 0.9) # shadow left on the ground under the jumping heart
@export var lilypad_land_squash: Vector2 = Vector2(1.2, 0.7) # the pad squashes by this when landed on
@export var lilypad_land_cooldown: float = 0.15 # pause before the next charge after the last landing
@export var lilypad_jump_sound: AudioStream
@export var lilypad_land_sound: AudioStream
@export_subgroup("3. Heart: Lilypad Attack")
# Starts after the heart has bounced on the first lilypad: the heart is pushed back to the left, then
# this attack repeats: ONE lilypad followed by rows of full-height cacti (the Jarona 3 wall art:
# "Hurt texture" + "Art mode" in Phase 1 > Jarona 3 (wall art)). Bounce on the pad to jump over them.
@export var lilypad_attack_enabled: bool = true
@export var lilypad_attack_count: int = 10 # how many times the pattern repeats
# The pads are placed so the heart can chain from one to the next: each pad sits after the previous pattern's
# cacti, close enough in x to be landed on, and never higher/lower than the heart can strafe in time.
@export var lilypad_attack_landing_margin: float = 120.0 # px between the last cactus row and the NEXT pad's left edge (this sets the time between patterns)
@export_range(0.1, 1.0, 0.05) var lilypad_attack_reach_safety: float = 0.8 # only this fraction of the strafe distance is ever asked of the player
@export var lilypad_attack_start_delay: float = 0.8 # pause after the push-back, before the first pattern
@export var lilypad_attack_speed: float = 320.0 # px/s everything moves left
@export var lilypad_attack_use_chain_speed: bool = false # true: speed is multiplied by get_chain_speed_multiplier()
@export var lilypad_attack_cactus_rows: int = 3
@export var lilypad_attack_cactus_width: float = 60.0
@export var lilypad_attack_cactus_extra_height: float = 50.0 # added to the screen height (half above, half below)
@export var lilypad_attack_cactus_gap: float = 20.0 # space between one cactus row and the next
@export var lilypad_attack_pad_gap: float = 80.0 # space between the pad's right edge and the first cactus row
@export_range(0.0, 1.0, 0.05) var lilypad_attack_pad_y_min: float = 0.2 # the pad appears at a random height between these two (fractions of the screen)
@export_range(0.0, 1.0, 0.05) var lilypad_attack_pad_y_max: float = 0.8
@export_range(0.0, 1.0, 0.05) var lilypad_pushback_x: float = 0.2 # where the heart is pushed to (fraction of the screen width)
@export var lilypad_pushback_time: float = 0.5

@export_subgroup("3. Heart: Lilypad Speed-up")
# Each consecutive jump raises get_chain_speed_multiplier(); it resets once the heart stops jumping.
# Nothing uses it yet: future attacks should multiply their speed by it.
# Jump speed: the first jump is slow (it does NOT keep the dash's speed), every consecutive jump is faster.
# The landing spot never changes (exactly on the next pad), so a faster jump just lasts less time: the
# heart rises and falls faster instead of overshooting.
@export_range(0.05, 1.0, 0.05) var lilypad_first_jump_speed: float = 0.4 # first jump, as a fraction of lilypad_hop_speed
@export var lilypad_jump_speed_gain: float = 0.3 # added to that fraction for every consecutive jump
@export var lilypad_jump_speed_max: float = 2.0 # cap, as a fraction of lilypad_hop_speed
# Free (up/down/left/right) movement also speeds up with every consecutive jump.
@export var lilypad_strafe_gain: float = 0.2 # walk speed +20% per consecutive jump
@export var lilypad_strafe_max: float = 2.0 # cap, as a multiple of heart_speed
# Steering up/down while in the air, at the heart's normal strafe speed (the chain bonus included).
@export var lilypad_air_strafe: bool = true
# The jump is never shorter than the time the heart needs to strafe (at its real strafe speed) up or down
# to the next pad, plus this much for reaction time, so a pad can always be reached.
@export var lilypad_reaction_time: float = 0.25
@export var lilypad_chain_speed_step: float = 0.15 # added per consecutive jump
@export var lilypad_chain_speed_max: float = 2.0
@export var lilypad_chain_grace: float = 0.8 # seconds standing still before the chain resets


# =====================================================================
@export_group("Phase 2")
# =====================================================================
# No attacks yet. When Phase 2 gets its own attacks, put each one in a subgroup here
# (@export_subgroup("Attack: ...")) and add it to the second list in attack_pools.


# =====================================================================
@export_group("Debug")
# =====================================================================
# Bug testing: anything other than "None" makes him use only that attack, in any phase.
@export_enum("None", "attack_Jarona", "attack_Jarona2", "attack_Jarona3") var debug_force_attack: String = "None"
# Testing shortcut: jump the "intro" animation straight to its last frame instead of playing it.
@export var skip_intro: bool = false
@export var debug_hurt_with_h: bool = false # testing: press H to hurt the heart
@export var debug_spawn_test_hazards: bool = false # testing: blue and red blocks fly in from the right
@export var debug_extra_lilypads: int = 0 # testing: this many extra lilypads in a row after the first one

# Everything below is not exported.
@export_group("")


# ---------------- STATE ----------------
var state: State = State.INACTIVE
var health: int
var phase: int = 0
var hits_while_idle: int = 0
var active_player: CharacterBody2D

var _attack_token: int = 0
var _active_tween: Tween
var _lunging: bool = false
var _lunge_hit_player: bool = false
var _deflected: bool = false
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_speed: float = 0.0
var _lunge_time_left: float = 0.0
var _last_voice_line: AudioStream
var _last_attack: StringName = &""
var _fight_requested: bool = false
var _home_position: Vector2

# Halfway transition
var _transition_started: bool = false
var _voices_done: bool = false
var _wipe_done: bool = false
var _wipe_layer: CanvasLayer
var _heart_layer: CanvasLayer
var _heart: Node2D
var _heart_active: bool = false
var _heart_iframes: float = 0.0
var _charge: float = 0.0 # 0..1
var _charging: bool = false
var _dashing: bool = false
var _dash_strong: bool = false
var _dash_speed: float = 0.0
var _dash_time: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_cooldown_len: float = 0.0
var _squash: Vector2 = Vector2.ONE
var _afterimage_timer: float = 0.0
var _test_hazard_timer: float = 0.0
var _charge_sfx: AudioStreamPlayer
var _dash_hint: Label
var _dash_hint_done: bool = false
var _frozen_players: Array = [] # [[node, previous process_mode], ...]

# Lilypads
var _lilypads: Array = []
var _heart_locked: bool = false
var _hopping: bool = false
var _hop_t: float = 0.0
var _hop_dur: float = 0.4
var _hop_from: Vector2 = Vector2.ZERO
var _hop_target: Vector2 = Vector2.ZERO
var _hop_scale: float = 1.0
var _hop_lift: float = 0.0
var _hop_disp: float = 0.0 # how far the jump has carried the heart forward so far (the world is shifted by this)
var _hop_air_speed: float = 0.0
var _attack_pad_spacing: float = 0.0 # distance between consecutive pads of the attack (keeps them in "next pad" range)
var _last_pad_y: float = -1.0
var _hop_steer: float = 0.0 # how far the player has steered the landing spot up/down during this jump
var _heart_forced: bool = false # controls off while the heart is being pushed back
var _lily_attack_started: bool = false
var _trail_timer: float = 0.0
var _trail_paused: bool = false
var _trail_hue: float = 0.0
var _hop_shadow: Polygon2D
var lilypad_chain: int = 0
var _chain_idle: float = 0.0
var _lyrics_layer: CanvasLayer
var _lyrics_old_parent: Node
var _lyrics_old_index: int = 0
var _lyrics_old_position: Vector2 = Vector2.ZERO

# One list per phase. Phase 2 has no attacks yet: add them to the second list when they exist.
var attack_pools: Array = [
	[&"attack_Jarona", &"attack_Jarona2", &"attack_Jarona3"],
	[],
]

# ---------------- NODES (names match the scene tree) ----------------
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var hit_box: Area2D = $Sprite2D/HitBox
@onready var attack_box: Area2D = $Sprite2D/AttackBox
@onready var timer: Timer = $Timer
@onready var voice_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var hit_sfx: Array[AudioStreamPlayer] = [$hitsfx, $hitsfx2]
@onready var idle_point: Marker2D = get_node_or_null("IdlePoint")


# One rectangle of the screen wipe: black fill + coloured outline, centred on its own origin.
# Growing "half_size" redraws it.
class TransitionRect extends Node2D:
	var half_size: Vector2 = Vector2.ZERO:
		set(value):
			half_size = value
			queue_redraw()
	var line_width: float = 18.0
	var line_color: Color = Color.WHITE

	func _draw() -> void:
		var r := Rect2(-half_size, half_size * 2.0)
		draw_rect(r, Color.BLACK, true)
		draw_rect(r, line_color, false, line_width)


# An attack for the heart, in screen coordinates. Blue ones are broken by a dash, the rest always hurt.
# Any node can be a heart attack: add it to the group "heart_hazard", give it
#   get_hazard_rect() -> Rect2   (screen coordinates)
# and, optionally, a "blue" property and an on_heart_dash_break() method (it should remove itself;
# without that method the node is simply freed).
class HeartHazard extends Node2D:
	var size: Vector2 = Vector2(40.0, 40.0)
	var blue: bool = false
	var velocity: Vector2 = Vector2(-300.0, 0.0)
	var texture: Texture2D # optional art (stretched to the size, or tiled)
	var tile: bool = false

	func _ready() -> void:
		add_to_group("heart_hazard")

	func _process(delta: float) -> void:
		position += velocity * delta
		if position.x < -size.x:
			queue_free()

	func get_hazard_rect() -> Rect2:
		return Rect2(global_position - size * 0.5, size)

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, Rect2(-size * 0.5, size), tile)
			return
		var col := Color(0.3, 0.7, 1.0) if blue else Color(1.0, 0.3, 0.4)
		draw_rect(Rect2(-size * 0.5, size), col, true)


# A lilypad, in screen coordinates (centred on its origin). It can drift with "velocity".
class HeartLilypad extends Node2D:
	var size: Vector2 = Vector2(140.0, 60.0)
	var texture: Texture2D
	var velocity: Vector2 = Vector2.ZERO

	func _process(delta: float) -> void:
		position += velocity * delta
		if position.x < -size.x:
			queue_free()

	func get_pad_rect() -> Rect2:
		return Rect2(position - size * 0.5, size)

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
			return
		var pts := PackedVector2Array()
		for i in 24:
			pts.append(Vector2(cos(TAU * i / 24.0) * size.x * 0.5, sin(TAU * i / 24.0) * size.y * 0.5))
		draw_colored_polygon(pts, Color.WHITE) # tinted by lilypad_color


# ---------------- LIFECYCLE ----------------
func _ready() -> void:
	if scale_health_with_level:
		max_health = min(50, max(15, Test.level * 2))
	health = max_health
	timer.one_shot = true
	# Guarded so it also works when the scene already has these connected in the editor
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
		hit_box.area_entered.connect(_on_hit_box_area_entered)
	if not attack_box.area_entered.is_connected(_on_attack_box_area_entered):
		attack_box.area_entered.connect(_on_attack_box_area_entered)
	if not attack_box.body_entered.is_connected(_on_attack_box_body_entered):
		attack_box.body_entered.connect(_on_attack_box_body_entered)
	attack_box.monitoring = false
	_connect_end_to_level()
	if auto_start:
		begin_fight.call_deferred()


func _exit_tree() -> void:
	# Safety: never leave the game stuck in slow motion
	Engine.time_scale = 1.0


# The chunk's level script handles "end" in _on_node_2d_end. Connecting it from code means
# the level still ends if the editor connection was lost when the boss was swapped.
func _connect_end_to_level() -> void:
	var level := get_parent()
	if level == null or not level.has_method("_on_node_2d_end"):
		return
	var handler := Callable(level, "_on_node_2d_end")
	if not end.is_connected(handler):
		end.connect(handler)


# Call this to start the fight. Safe to call more than once: only the first call counts.
func begin_fight() -> void:
	if _fight_requested:
		return
	_fight_requested = true
	_start_fight()


func _start_fight() -> void:
	# Wait until the player exists
	_resync_player()
	while active_player == null:
		await get_tree().process_frame
		_resync_player()

	# Read after the chunk has been placed in the level, not in _ready
	_home_position = sprite.global_position
	sprite.global_position = _home()

	GlobalSignals.disable_boss_ui.emit(false) # show the boss HP bar, like the other bosses
	_emit_health()
	if lyrics:
		lyrics.start()
	_enter_idle()


func _process(delta: float) -> void:
	_resync_player()
	_update_trail(delta)


# ---------------- TRAIL ----------------
# Copies of his sprite that get pushed left and fade out, so he looks like he is always running right.
func _update_trail(delta: float) -> void:
	if not trail_enabled or _trail_paused:
		return
	if state == State.INACTIVE or state == State.DYING:
		return
	if not sprite.visible or sprite.texture == null:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval

	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.hframes = sprite.hframes
	g.vframes = sprite.vframes
	g.frame = sprite.frame
	g.region_enabled = sprite.region_enabled
	g.region_rect = sprite.region_rect
	g.centered = sprite.centered
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.flip_v = sprite.flip_v
	g.top_level = true # stays in the world instead of following him
	add_child(g)
	g.global_transform = sprite.global_transform
	g.z_as_relative = sprite.z_as_relative
	g.z_index = sprite.z_index - 1 # behind him
	g.modulate = trail_color
	if trail_rainbow:
		_trail_hue = fposmod(_trail_hue + trail_interval * trail_rainbow_speed, 1.0)
		g.modulate = Color.from_hsv(_trail_hue, trail_rainbow_saturation, 1.0, trail_color.a)
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "global_position:x", g.global_position.x - trail_drift, trail_life)
	tw.tween_property(g, "modulate:a", 0.0, trail_life)
	tw.chain().tween_callback(g.queue_free)


func _physics_process(delta: float) -> void:
	_push_player_left(delta)
	_home_in(delta)
	_move_heart(delta)


# ---------------- CHASE PUSH ----------------
func _push_player_left(delta: float) -> void:
	if state == State.INACTIVE or state == State.INTRO or state == State.TRANSITION or state == State.DYING:
		return
	if active_player == null or not is_instance_valid(active_player):
		return
	var push_speed := chase_push_speed * (1.0 + phase * chase_phase_bonus)
	# move_and_collide respects walls, so the player can be pinned against the edge
	for p in BossTargets.everyone(get_tree()):
		if p is CharacterBody2D:
			p.move_and_collide(Vector2.LEFT * push_speed * delta)


# ---------------- PLAYER TRACKING ----------------
func _resync_player() -> void:
	# With more than one player it takes turns going after each
	var p := BossTargets.pick(self)
	if p:
		active_player = p as CharacterBody2D


# ---------------- HOME POSITION ----------------
func _home() -> Vector2:
	if idle_point:
		return idle_point.global_position
	return _home_position


# Moves the sprite back to the idle point. Stored in _active_tween so _die() can kill it.
func _return_home() -> void:
	_active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(sprite, "global_position", _home(), home_return_time)
	await _active_tween.finished


# ---------------- HEALTH UI ----------------
# The bar only shows the top slice of his HP (visible_health_fraction), so it looks empty
# when he reaches the halfway point. The real "health" is never touched here.
func _emit_health() -> void:
	var shown_max := int(ceil(max_health * visible_health_fraction))
	var hidden := max_health - shown_max # the part of his HP the bar doesn't show
	var shown := clampi(health - hidden, 0, shown_max)
	health_changed.emit(shown, shown_max)
	update_health_bar.emit(shown, shown_max)


# ---------------- ATTACK LOOP ----------------
func _enter_idle() -> void:
	if state == State.DYING or state == State.TRANSITION:
		return
	state = State.IDLE
	hits_while_idle = 0
	_play_anim(&"Floweridle")
	timer.start(idle_times[min(phase, idle_times.size() - 1)])


func _on_timer_timeout() -> void:
	if state == State.IDLE:
		_pick_next_attack()


func _pick_next_attack() -> void:
	timer.stop()
	if debug_force_attack != "None" and has_method(debug_force_attack):
		_last_attack = StringName(debug_force_attack)
		call(_last_attack)
		return
	var pool: Array = attack_pools[min(phase, attack_pools.size() - 1)].duplicate()
	if pool.is_empty():
		# This phase has no attacks yet: just wait and check again
		_enter_idle()
		return
	if pool.size() > 1:
		pool.erase(_last_attack)
	_last_attack = pool.pick_random()
	call(_last_attack)


# ---------------- ATTACK HELPERS ----------------
func _begin_attack() -> int:
	timer.stop()
	state = State.ATTACKING
	_attack_token += 1
	return _attack_token


func _stale(token: int) -> bool:
	return token != _attack_token or state != State.ATTACKING


func _end_attack(token: int) -> void:
	if _stale(token):
		return
	_enter_idle()


# Plays an animation only if it exists, so a typo gives a warning instead of an error.
func _play_anim(anim_name: StringName) -> void:
	if anim.has_animation(anim_name):
		anim.play(anim_name)
	else:
		push_warning("Flowery: missing animation '%s'" % anim_name)


# Waits for the animation length with a timer instead of "animation_finished",
# so a missing or looping animation can never freeze the fight.
func _play_and_wait(anim_name: StringName) -> void:
	if not anim.has_animation(anim_name):
		push_warning("Flowery: missing animation '%s'" % anim_name)
		return
	anim.play(anim_name)
	await get_tree().create_timer(anim.current_animation_length).timeout


# ---------------- VOICE ----------------
func _play_voice(lines: Array[AudioStream]) -> void:
	if lines.is_empty():
		return
	var choices := lines.duplicate()
	if choices.size() > 1:
		choices.erase(_last_voice_line)
	_last_voice_line = choices.pick_random()
	voice_player.stream = _last_voice_line
	voice_player.play()


# ---------------- ATTACK: JARONA ----------------
func attack_Jarona() -> void:
	var t := _begin_attack()
	var speed := jarona1StartSpeed
	var telegraphAttack := 0.5

	for i in jarona1Count:
		_resync_player()
		if active_player == null:
			break

		_play_anim(&"jaronaWindup")
		await get_tree().create_timer(telegraphAttack).timeout
		if _stale(t): return

		_resync_player()
		if active_player == null:
			break

		_lunge_dir = (active_player.global_position - sprite.global_position).normalized()
		_lunge_speed = speed
		_lunge_time_left = jarona1MaxLungeTime
		_lunge_hit_player = false
		_deflected = false
		_lunging = true
		attack_box.set_deferred("monitoring", true)

		_play_voice(jarona_voice_lines) # random clip on every lunge
		_play_anim(&"Jarona")
		await lunge_done

		attack_box.set_deferred("monitoring", false)
		if _stale(t): return

		if _deflected:
			await _recoil()
			if _stale(t): return

		# Back to the idle point before the next lunge starts
		await _return_home()
		if _stale(t): return

		# Player got hurt: ease off. Parried or timed out: speed up.
		if _lunge_hit_player:
			speed = max(speed - jarona1SpeedDecrease, jarona1MinSpeed)
			telegraphAttack = min(telegraphAttack + 0.08, 0.5)
		else:
			speed = min(speed + jarona1SpeedIncrease, jarona1MaxSpeed)
			telegraphAttack = max(telegraphAttack - 0.08, 0.15)

		await get_tree().create_timer(0.15).timeout
		if _stale(t): return

	await _play_and_wait(&"Idle")
	if _stale(t): return
	_end_attack(t)


# ---------------- ATTACK: JARONA 2 (lunge + summoned hitboxes) ----------------
func attack_Jarona2() -> void:
	var t := _begin_attack()
	var speed := jarona1StartSpeed
	var telegraphAttack := 0.5

	for i in jarona1Count:
		_resync_player()
		if active_player == null:
			break

		_play_anim(&"jaronaWindup")
		await get_tree().create_timer(telegraphAttack).timeout
		if _stale(t): return

		_resync_player()
		if active_player == null:
			break

		_lunge_dir = (active_player.global_position - sprite.global_position).normalized()
		_lunge_speed = speed
		_lunge_time_left = jarona1MaxLungeTime
		_lunge_hit_player = false
		_deflected = false
		_lunging = true
		attack_box.set_deferred("monitoring", true)

		_play_voice(jarona_voice_lines)
		_play_anim(&"Jarona")
		await lunge_done

		attack_box.set_deferred("monitoring", false)
		if _stale(t): return

		# The punch is over: the hitboxes appear now and fly while he recovers
		_summon_hitboxes()

		if _deflected:
			await _recoil()
			if _stale(t): return

		await _return_home()
		if _stale(t): return

		if _lunge_hit_player:
			speed = max(speed - jarona1SpeedDecrease, jarona1MinSpeed)
			telegraphAttack = min(telegraphAttack + 0.08, 0.5)
		else:
			speed = min(speed + jarona1SpeedIncrease, jarona1MaxSpeed)
			telegraphAttack = max(telegraphAttack - 0.08, 0.15)

		await get_tree().create_timer(0.15).timeout
		if _stale(t): return

	await _play_and_wait(&"recoverJarona")
	if _stale(t): return

	_end_attack(t)


# ---------------- ATTACK: JARONA 3 (walls of hitboxes) ----------------
func attack_Jarona3() -> void:
	var t := _begin_attack()
	_resync_player()
	if active_player == null:
		_end_attack(t)
		return

	# Walls travel from StartX to EndX
	var dir := Vector2.RIGHT if jarona3EndX > jarona3StartX else Vector2.LEFT

	_play_anim(&"jaronaWindup")
	await get_tree().create_timer(jarona3WindupTime).timeout
	if _stale(t): return

	for i in jarona3Count:
		_spawn_wall(dir)
		if i < jarona3Count - 1:
			# Every wall moves at the same speed, so a time gap of spacing / speed gives a constant distance
			await get_tree().create_timer(jarona3Spacing / maxf(jarona3Speed, 1.0)).timeout
			if _stale(t): return

	await _play_and_wait(&"recoverJarona")
	if _stale(t): return
	_end_attack(t)


func _ground_y() -> float:
	return jarona3GroundY


func _ceiling_y() -> float:
	return jarona3CeilingY


# The node whose coordinate space the Jarona 3 numbers are in: the one set in the Inspector,
# otherwise Flowery's parent (the arena).
func _wall_host() -> Node:
	var n: Node = null
	if not jarona3SpaceNode.is_empty():
		n = get_node_or_null(jarona3SpaceNode)
	if n == null:
		n = get_parent()
	return n


# One wall = a ground block, a ceiling block and a breakable middle block, moving together.
func _spawn_wall(dir: Vector2) -> void:
	var spawn_x := jarona3StartX
	var ground_y := _ground_y()
	var ceiling_y := _ceiling_y()

	# Middle block: random size and height, kept between the ground and ceiling blocks
	var mid_size := randf_range(minf(jarona3MiddleSizeMin, jarona3MiddleSizeMax), maxf(jarona3MiddleSizeMin, jarona3MiddleSizeMax))
	var mid_height := randf_range(minf(jarona3MiddleHeightMin, jarona3MiddleHeightMax), maxf(jarona3MiddleHeightMin, jarona3MiddleHeightMax))
	# The middle block has to fit between the ceiling and the ground
	mid_size = minf(mid_size, maxf(ground_y - ceiling_y, 0.0))
	var mid_y := clampf(ground_y - mid_height, ceiling_y + mid_size * 0.5, ground_y - mid_size * 0.5)
	var mid_top := mid_y - mid_size * 0.5
	var mid_bottom := mid_y + mid_size * 0.5

	var wall := Node2D.new()
	# The wall lives in the arena (Flowery's parent), not under Flowery, so his own position can't
	# affect it. Every number here is in the arena's coordinates, like the editor shows them.
	_wall_host().add_child(wall)
	wall.position = Vector2(spawn_x, 0.0)
	wall.add_to_group("jarona_hitbox") # so _die() clears it
	wall.modulate.a = 0.35 # telegraph: faded and harmless until it launches
	if jarona3FlipToDirection:
		wall.scale.x = 1.0 if dir.x > 0.0 else -1.0

	# Shared by the three blocks: the wall hurts the player once at most
	var wave := {"hit": false}
	# Hurt blocks start at the ceiling and at the ground and end where the middle block begins,
	# so their size is calculated and nothing overlaps
	var ceiling_h := mid_top - ceiling_y
	if ceiling_h >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, ceiling_y + ceiling_h * 0.5, ceiling_h, false)
	var ground_h := ground_y - mid_bottom
	if ground_h >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, mid_bottom + ground_h * 0.5, ground_h, false)
	if mid_size >= 1.0:
		_add_wall_piece(wall, wave, spawn_x, mid_y, mid_size, true)

	var tw := wall.create_tween()
	tw.tween_interval(jarona3TelegraphTime)
	tw.tween_callback(_arm_wall.bind(wall))
	tw.tween_property(wall, "position:x",
		jarona3EndX,
		absf(jarona3EndX - spawn_x) / maxf(jarona3Speed, 1.0))
	tw.tween_callback(wall.queue_free)


func _add_wall_piece(wall: Node2D, wave: Dictionary, x: float, center_y: float, height: float, breakable: bool) -> void:
	var piece := Area2D.new()

	# The safe block keeps its texture's own thickness; only its height is randomised
	var width := jarona3HitboxWidth
	if breakable and jarona3SafeTexture:
		width = float(jarona3SafeTexture.get_width())

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	piece.add_child(shape)

	piece.add_child(_make_wall_visual(Vector2(width, height), breakable))

	# Same layers as his lunge hitbox so it detects the player the same way
	piece.collision_layer = attack_box.collision_layer
	piece.collision_mask = attack_box.collision_mask
	if breakable:
		# Also detect the player's attacks, the same ones that hurt Flowery's own hit box
		piece.collision_mask |= hit_box.collision_mask
	piece.monitoring = false # switched on when the wall launches
	piece.monitorable = false
	piece.area_entered.connect(_on_wall_area_entered.bind(piece, wave, breakable))
	piece.body_entered.connect(_on_wall_body_entered.bind(piece, wave, breakable))

	wall.add_child(piece)
	piece.position = Vector2(x - wall.position.x, center_y)


# Builds the look of one block: a texture, or the placeholder rectangle.
func _make_wall_visual(size: Vector2, breakable: bool) -> Node2D:
	var tex: Texture2D = jarona3SafeTexture if breakable else jarona3HurtTexture

	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		if breakable:
			s.modulate = jarona3SafeTint
		if jarona3ArtMode == WallArt.TILE:
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(Vector2.ZERO, size)
		else:
			s.scale = size / tex.get_size()
		return s

	# Placeholder: red = always hurts, blue = safe/breakable
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	poly.color = Color(0.3, 0.8, 1.0, 0.8) if breakable else Color(1.0, 0.3, 0.4, 0.8)
	return poly


func _arm_wall(wall: Node2D) -> void:
	if not is_instance_valid(wall):
		return
	wall.modulate.a = 1.0
	for piece in wall.get_children():
		if piece is Area2D:
			piece.set_deferred("monitoring", true)


func _on_wall_area_entered(area: Area2D, piece: Area2D, wave: Dictionary, breakable: bool) -> void:
	if piece.has_meta(&"broken"):
		return

	# Stomping or attacking the middle block breaks it (same groups that interrupt Flowery)
	if breakable and area.is_in_group("Playerattack"):
		_break_wall_piece(piece)
		if area.is_in_group("Player"):
			var p = area.get_parent()
			if "can_stomp" in p:
				p.can_stomp = true
			if "bounce" in p:
				p.bounce = 0
		return

	if wave["hit"] or not area.is_in_group("Player"):
		return
	wave["hit"] = true
	_hurt_player(area)


func _on_wall_body_entered(body: Node2D, piece: Area2D, wave: Dictionary, breakable: bool) -> void:
	if body != active_player or wave["hit"]:
		return
	if breakable:
		# Give a stomp one physics frame to break the block before the body counts as a hit
		await get_tree().physics_frame
		if not is_instance_valid(piece) or piece.has_meta(&"broken") or wave["hit"]:
			return
	wave["hit"] = true
	_hurt_player(body)


func _break_wall_piece(piece: Area2D) -> void:
	if piece.has_meta(&"broken"):
		return
	piece.set_meta(&"broken", true)
	piece.set_deferred("monitoring", false)
	_spawn_break_particles(piece)
	piece.queue_free()


# Small blue burst where the safe block was.
# The particles live in the arena (not in the piece), because the piece is freed right away.
func _spawn_break_particles(piece: Area2D) -> void:
	# Cover the block's area; the first child of each piece is its CollisionShape2D
	var size := Vector2(40.0, 40.0)
	var col := piece.get_child(0) as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		size = (col.shape as RectangleShape2D).size

	var p := CPUParticles2D.new()
	_wall_host().add_child(p)
	p.global_position = piece.global_position
	_setup_break_particles(p, size)


# Shared look of the blue break burst (used by the walls and by the heart's dash).
func _setup_break_particles(p: CPUParticles2D, size: Vector2) -> void:
	p.one_shot = true
	p.explosiveness = 1.0 # all particles at once = explosion
	p.amount = 18
	p.lifetime = 0.45
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size * 0.5
	p.direction = Vector2.ZERO
	p.spread = 180.0 # any direction
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.damping_min = 150.0 # slows them down so it reads as a pop
	p.damping_max = 250.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = jarona3SafeTint # same blue as the block

	# Fade out each particle over its own life
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad

	p.finished.connect(p.queue_free)
	p.emitting = true


# ---------------- LUNGE (shared by both Jarona attacks) ----------------
# Steers toward the player every physics frame while a lunge is active.
func _home_in(delta: float) -> void:
	if not _lunging:
		return
	if active_player == null or not is_instance_valid(active_player):
		_end_lunge()
		return

	var to_player := active_player.global_position - sprite.global_position
	var step := _lunge_speed * delta
	if to_player.length() <= step:
		sprite.global_position = active_player.global_position
	else:
		_lunge_dir = to_player.normalized() # also keeps the recoil direction correct
		sprite.global_position += _lunge_dir * step

	_lunge_time_left -= delta
	if _lunge_time_left <= 0.0:
		_end_lunge()


func _end_lunge() -> void:
	if _lunging:
		_lunging = false
		lunge_done.emit()


func _deflect() -> void:
	_deflected = true
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()


func _recoil() -> void:
	_play_anim(&"Deflected")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "global_position", sprite.global_position - _lunge_dir * jarona1RecoilDistance, jarona1RecoilTime)
	await tween.finished
	await get_tree().create_timer(0.25).timeout


# ---------------- PLAYER DAMAGE ----------------
# Finds whoever can be hurt: the node itself, or its nearest parent that has hurt()
func _hurt_player(node: Node) -> bool:
	var n := node
	while n != null and n != get_tree().root:
		if n.has_method("hurt"):
			n.hurt()
			return true
		n = n.get_parent()
	return false


func _on_attack_box_area_entered(area: Area2D) -> void:
	if state != State.ATTACKING or _lunge_hit_player:
		return
	if area.is_in_group("Player"):
		_lunge_hit_player = true
		_hurt_player(area)
		_end_lunge()


func _on_attack_box_body_entered(body: Node2D) -> void:
	if state != State.ATTACKING or _lunge_hit_player or body != active_player:
		return
	_lunge_hit_player = true
	_hurt_player(body)
	_end_lunge()


# ---------------- SUMMONED HITBOXES ----------------
func _summon_hitboxes() -> void:
	# At the end of a punch he is standing on the player, so use the lunge direction
	var forward: Vector2 = _lunge_dir if _lunge_dir.length() > 0.01 else Vector2.LEFT
	var back := -forward
	var side := forward.orthogonal()

	for s in [-1.0, 1.0]:
		var offset: Vector2 = side * s * jarona2HitboxSpread
		var hb := _make_hitbox()
		add_child(hb)
		hb.global_position = sprite.global_position + offset
		_play_hitbox_anim(hb, jarona2HitboxAnim)

		# One hitbox ends up above the player's altitude, the other below
		var lock_offset: float = s * randf_range(jarona2LockOffsetMin, jarona2LockOffsetMax)
		var back_x: float = (_home() + back * jarona2BackDistance + offset).x

		# Single tween: drift back AND settle on the player's altitude at the same time.
		# When it ends, the hitbox is behind Flowery at the player's height, so it launches immediately.
		var tw := hb.create_tween()
		tw.tween_method(_drift_back.bind(hb, hb.global_position, back_x, lock_offset), 0.0, 1.0, jarona2BackTime)
		tw.tween_callback(_send_hitbox_forward.bind(hb))


# t goes 0 -> 1. X heads to the spot behind Flowery, Y heads to the player's *current* altitude,
# so the height is always up to date and exactly locked on arrival (t = 1).
func _drift_back(t: float, hb: Area2D, start: Vector2, back_x: float, lock_offset: float) -> void:
	if not is_instance_valid(hb):
		return
	var e := sin(t * PI * 0.5) # sine ease-out
	var target_y := start.y
	if active_player and is_instance_valid(active_player):
		target_y = active_player.global_position.y + lock_offset
	hb.global_position = Vector2(
		lerpf(start.x, back_x, e),
		lerpf(start.y, target_y, e)
	)


# Altitude is locked by now: travel in a perfectly horizontal line, no homing
func _send_hitbox_forward(hb: Area2D) -> void:
	if not is_instance_valid(hb):
		return

	hb.set_deferred("monitoring", true) # only dangerous once launched

	var dir := Vector2.LEFT
	if active_player and is_instance_valid(active_player):
		if active_player.global_position.x > hb.global_position.x:
			dir = Vector2.RIGHT

	if jarona2FlipToDirection:
		hb.scale.x = absf(hb.scale.x) * (1.0 if dir.x > 0.0 else -1.0)
	_play_hitbox_anim(hb, jarona2HitboxLaunchAnim)

	var tw := hb.create_tween()
	tw.tween_property(hb, "global_position:x",
		hb.global_position.x + dir.x * jarona2ForwardDistance,
		jarona2ForwardDistance / jarona2ForwardSpeed)
	tw.tween_callback(hb.queue_free)


func _make_hitbox() -> Area2D:
	var hb: Area2D
	var is_placeholder := false
	if jarona2HitboxScene:
		hb = jarona2HitboxScene.instantiate() as Area2D
		if hb == null:
			push_warning("Flowery: jarona2HitboxScene's root must be an Area2D")
			hb = Area2D.new()
			is_placeholder = true
	else:
		push_warning("Flowery: jarona2HitboxScene is empty, using the placeholder (it has no animation)")
		hb = Area2D.new()
		is_placeholder = true

	if is_placeholder:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = jarona2HitboxRadius
		shape.shape = circle
		hb.add_child(shape)
		# Placeholder visual so you can see it; assign a scene for real art
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			pts.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * jarona2HitboxRadius)
		poly.polygon = pts
		poly.color = Color(1.0, 0.3, 0.4, 0.8)
		hb.add_child(poly)

	# Use the same layers as his lunge hitbox so it detects the player the same way
	hb.collision_layer = attack_box.collision_layer
	hb.collision_mask = attack_box.collision_mask
	hb.monitoring = false # switched on when it launches
	hb.monitorable = false
	hb.add_to_group("jarona_hitbox")
	hb.area_entered.connect(_on_summoned_hitbox_area_entered.bind(hb))
	hb.body_entered.connect(_on_summoned_hitbox_body_entered.bind(hb))
	return hb


# Plays an animation on whatever animation node the hitbox scene contains.
# An empty name uses the autoplay animation, otherwise the first one that isn't RESET.
func _play_hitbox_anim(hb: Node, anim_name: StringName) -> void:
	var players := hb.find_children("*", "AnimationPlayer", true, false)
	var sprites := hb.find_children("*", "AnimatedSprite2D", true, false)
	if players.is_empty() and sprites.is_empty():
		if anim_name != &"":
			push_warning("Flowery: hitbox has no AnimationPlayer or AnimatedSprite2D to play '%s'" % anim_name)
		return

	for node in players:
		var ap := node as AnimationPlayer
		var pick: StringName = anim_name
		if pick == &"" or not ap.has_animation(pick):
			if pick != &"":
				push_warning("Flowery: hitbox has no animation '%s'" % pick)
			pick = &""
			if ap.autoplay != "" and ap.has_animation(StringName(ap.autoplay)):
				pick = StringName(ap.autoplay)
			else:
				for n in ap.get_animation_list():
					if n != "RESET":
						pick = StringName(n)
						break
		if pick != &"":
			ap.play(pick)
			return

	for node in sprites:
		var spr := node as AnimatedSprite2D
		if spr.sprite_frames == null:
			continue
		var pick: StringName = anim_name
		if pick == &"" or not spr.sprite_frames.has_animation(pick):
			pick = &""
			var names := spr.sprite_frames.get_animation_names()
			if names.size() > 0:
				pick = StringName(names[0])
		if pick != &"":
			spr.play(pick)
			return


# Deliberately ignores the boss's state: it hurts the player even while he is idle or attacking
func _on_summoned_hitbox_area_entered(area: Area2D, hb: Area2D) -> void:
	if hb.has_meta(&"hit") or not area.is_in_group("Player"):
		return
	hb.set_meta(&"hit", true) # each hitbox hurts once
	_hurt_player(area)


func _on_summoned_hitbox_body_entered(body: Node2D, hb: Area2D) -> void:
	if hb.has_meta(&"hit") or body != active_player:
		return
	hb.set_meta(&"hit", true)
	_hurt_player(body)


func _clear_hitboxes() -> void:
	for hb in get_tree().get_nodes_in_group("jarona_hitbox"):
		hb.queue_free()


# ---------------- DAMAGE ----------------
# Mirrors the other bosses: thrown items ("item") and player attacks ("Playerattack")
# both hurt the boss, and a stomp (area also in "Player") makes the player bounce.
func _on_hit_box_area_entered(area: Area2D) -> void:
	if not (state in [State.IDLE, State.ATTACKING]):
		return

	if area.is_in_group("item"):
		take_damage(1)
		area.get_parent().queue_free()

	if area.is_in_group("Playerattack"):
		take_damage(1)
		if area.is_in_group("Player"):
			var p = area.get_parent()
			if "can_stomp" in p:
				p.can_stomp = true
			if "bounce" in p:
				p.bounce = 0


# The HP the fight locks at when the halfway transition triggers.
func _transition_hp() -> int:
	return int(ceil(max_health * transition_health_ratio))


func take_damage(amount: int = 1) -> void:
	if state == State.DYING or state == State.INTRO or state == State.INACTIVE or state == State.TRANSITION:
		return

	# Until the transition has happened, health can't drop below the halfway point
	var use_transition := halfway_transition and not _transition_started
	var min_health := _transition_hp() if use_transition else 0
	health = max(health - amount, min_health)
	_emit_health()
	hit_sfx.pick_random().play()
	_flash()

	if health <= 0:
		_die()
		return

	if use_transition and health <= min_health:
		_start_transition()
		return

	if _lunging:
		_deflect()

	_update_phase()

	if state == State.IDLE and hits_to_interrupt_idle > 0:
		hits_while_idle += 1
		if hits_while_idle >= hits_to_interrupt_idle:
			_pick_next_attack()


func _flash(duration: float = 0.1) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_amount", 1.0)
	await get_tree().create_timer(duration).timeout
	mat.set_shader_parameter("flash_amount", 0.0)


# ---------------- PHASES ----------------
func _update_phase() -> void:
	var ratio := health / float(max_health)
	var new_phase := 0
	for threshold in phase_thresholds:
		if ratio <= threshold:
			new_phase += 1
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_on_phase_started(phase)


func _on_phase_started(_new_phase: int) -> void:
	pass


# ---------------- HALFWAY TRANSITION ----------------
# Flow:
#   t = 0                 parried animation + voice line 1, then voice line 2 right after it
#   t = parried_hold_time he flies off screen to the right
#   then                  he surges up from below under the player and carries them off the top
#   wipe_start_delay later the rectangles start covering the screen (it ends fully black)
#   when voice 2 AND the wipe are both done: the heart fades in and the player controls it
# Right now the fight stays here (softlock) until the next part is added.
# NOTE: _update_phase() is NOT called here, so phase 2 hasn't started yet. When you add the
# next part, call _update_phase() once the transition is over.
func _start_transition() -> void:
	_transition_started = true
	state = State.TRANSITION
	_attack_token += 1 # cancels whatever attack was running
	timer.stop()
	attack_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitoring", false)
	_clear_hitboxes()
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()
	if freeze_players_during_transition:
		_freeze_players.call_deferred() # deferred: we may be inside a physics callback right now

	_keep_music_playing()

	voice_player.stop()
	_play_anim(parried_anim)

	_voices_done = false
	_wipe_done = false
	_play_transition_voices() # runs in parallel

	await get_tree().create_timer(parried_hold_time).timeout
	await _exit_screen()
	await _surge_grab()
	_delayed_wipe() # runs in parallel with the rest of the voices

	# Wait for whichever of the two is still running
	if not _voices_done:
		await voices_finished
	if not _wipe_done:
		await wipe_finished
	_spawn_heart()


# The phase 1 song (FloweryLyrics) keeps going through the whole middle point.
# Nothing here ever stops it, and the node is set to keep running even if one of its parents is
# paused or frozen (a paused parent also pauses any AudioStreamPlayer below it).
# With keep_music_during_transition off it fades out instead.
func _keep_music_playing() -> void:
	if lyrics == null:
		return
	if keep_music_during_transition:
		lyrics.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		lyrics.stop(0.8)


# The lyrics have to show over the black screen. The black screen is a CanvasLayer at
# transition_layer, so the lyrics' RichTextLabel (only the text, not the FloweryLyrics node or the
# song) is moved into its own CanvasLayer just above it. It keeps the exact same place on screen,
# and the lyrics script keeps writing to it as before. The heart is one layer higher still.
func _raise_lyrics_above_wipe() -> void:
	if lyrics == null or not keep_music_during_transition or not show_lyrics_over_black:
		return
	var label := lyrics.label
	if label == null or _lyrics_layer != null:
		return

	var screen_pos := label.get_global_transform_with_canvas().origin
	_lyrics_old_parent = label.get_parent()
	_lyrics_old_index = label.get_index()
	_lyrics_old_position = label.position

	_lyrics_layer = CanvasLayer.new()
	_lyrics_layer.layer = transition_layer + 1
	add_child(_lyrics_layer)
	label.reparent(_lyrics_layer, false)
	label.global_position = screen_pos # the new layer has no offset, so this is the same spot on screen


# Puts the lyrics label back where it was. Not called anywhere yet: use it when the transition
# ends and the black screen goes away.
func _restore_lyrics_layer() -> void:
	if _lyrics_layer == null:
		return
	var label := lyrics.label if lyrics else null
	if label and is_instance_valid(label) and is_instance_valid(_lyrics_old_parent):
		label.reparent(_lyrics_old_parent, false)
		_lyrics_old_parent.move_child(label, _lyrics_old_index)
		label.position = _lyrics_old_position
	_lyrics_layer.queue_free()
	_lyrics_layer = null


# Two voice lines, one after the other. Uses the stream length instead of "finished"
# so an empty slot can never freeze the transition.
func _play_transition_voices() -> void:
	for line in [transition_voice_1, transition_voice_2]:
		if line == null:
			continue
		voice_player.stream = line
		voice_player.play()
		await get_tree().create_timer(line.get_length()).timeout
	_voices_done = true
	voices_finished.emit()


func _delayed_wipe() -> void:
	await get_tree().create_timer(wipe_start_delay).timeout
	await _play_screen_wipe()


# He flies off in exit_direction until he is past the edge of the screen.
func _exit_screen() -> void:
	var vp := get_viewport()
	var view: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var dir := exit_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var target := sprite.global_position + dir * (view.size.length() + exit_margin)
	# Plain ease-in (no wind-up: a "back" ease would first push him the opposite way)
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(sprite, "global_position", target, exit_time)
	await _active_tween.finished


# He comes up from below the screen right under the player and drags every player character up
# and off the top of the screen. His look is surge_texture (or his normal sprite if it is empty).
func _surge_grab() -> void:
	if not surge_enabled:
		return
	var players: Array = []
	for p in BossTargets.everyone(get_tree()):
		if p is Node2D and is_instance_valid(p):
			players.append(p)
	if players.is_empty():
		return
	_trail_paused = true # the trail only makes sense while he moves sideways

	var lead: Node2D = active_player if players.has(active_player) else players[0]
	var vp := get_viewport()
	var view: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()

	var visual: Node2D
	var made_visual := false
	var half_h := 100.0
	if surge_texture:
		var s := Sprite2D.new()
		s.texture = surge_texture
		s.scale = surge_scale
		s.top_level = true
		s.z_as_relative = false
		s.z_index = surge_z_index
		add_child(s)
		visual = s
		made_visual = true
		sprite.visible = false
		half_h = surge_texture.get_height() * absf(surge_scale.y) * 0.5
	else:
		visual = sprite
		if sprite.texture:
			half_h = sprite.texture.get_height() / float(maxi(sprite.vframes, 1)) * absf(sprite.global_scale.y) * 0.5

	var lead_start := lead.global_position
	var starts: Array = []
	for p in players:
		starts.append(p.global_position)

	var start_y := view.end.y + half_h + surge_start_margin
	var end_y := view.position.y - surge_exit_margin + half_h # his top ends this far above the screen
	visual.global_position = Vector2(lead_start.x, start_y)
	_play_heart_sfx(surge_sound)

	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var step := func(t: float) -> void:
		var y := lerpf(start_y, end_y, t)
		visual.global_position.y = y
		# Once his top reaches the player they ride on it (the others keep their offset from the lead)
		var lifted := maxf(0.0, lead_start.y - (y - half_h))
		for i in players.size():
			if is_instance_valid(players[i]):
				players[i].global_position.y = starts[i].y - lifted
	tw.tween_method(step, 0.0, 1.0, surge_time)
	await tw.finished

	if made_visual:
		visual.queue_free()
		sprite.visible = true


# Nested, slightly rotated rectangles grow past the screen one after another, then a plain
# black rect stays. Everything is drawn on its own CanvasLayer, so the camera doesn't matter.
func _play_screen_wipe() -> void:
	_wipe_layer = CanvasLayer.new()
	_wipe_layer.layer = transition_layer
	add_child(_wipe_layer)
	_raise_lyrics_above_wipe()

	var vp_size := get_viewport().get_visible_rect().size
	var center := vp_size * 0.5
	# Big enough to cover the screen whatever the rotation
	var final_half := Vector2.ONE * vp_size.length() * 0.6

	for i in wipe_rect_count:
		var r := TransitionRect.new()
		r.position = center
		r.rotation = deg_to_rad(randf_range(-wipe_max_tilt_deg, wipe_max_tilt_deg))
		r.line_width = wipe_line_width
		if not wipe_outline_colors.is_empty():
			r.line_color = wipe_outline_colors[i % wipe_outline_colors.size()]
		_wipe_layer.add_child(r) # later rectangles are drawn on top, so they look nested
		var tw := r.create_tween()
		tw.tween_interval(i * wipe_stagger)
		tw.tween_property(r, "half_size", final_half, wipe_grow_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var total := maxi(wipe_rect_count - 1, 0) * wipe_stagger + wipe_grow_time
	await get_tree().create_timer(total).timeout

	# The screen stays black
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_layer.add_child(black)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)

	_wipe_done = true
	wipe_finished.emit()


# ---------------- TRANSITION: PLAYER HEART ----------------
func _spawn_heart() -> void:
	_heart_layer = CanvasLayer.new()
	_heart_layer.layer = transition_layer + 2 # above the black overlay and the lyrics
	add_child(_heart_layer)

	# The hint goes in first so it is drawn behind the heart
	_spawn_dash_hint()

	# The heart starts in the middle of the screen
	_heart = _make_heart()
	_heart_layer.add_child(_heart)
	_heart.position = _heart_limits().get_center()
	_heart.modulate.a = 0.0
	_spawn_lilypads()

	# Fades in; the player gets control once it is fully visible
	var tw := _heart.create_tween()
	tw.tween_property(_heart, "modulate:a", 1.0, heart_fade_time)
	tw.tween_callback(func(): _heart_active = true)


# The whole screen (the heart's CanvasLayer has no camera or offset, so these are screen pixels).
func _screen_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)


# Where the heart's centre is allowed to be: the screen, minus the heart's own size.
func _heart_limits() -> Rect2:
	var ex := _heart_extent()
	return _screen_rect().grow(-heart_edge_margin).grow_individual(-ex.x, -ex.y, -ex.x, -ex.y)


# Half the heart's size, used to keep it inside the screen.
func _heart_extent() -> Vector2:
	var base := Vector2(10.0, 10.0) # same radius as the placeholder circle
	if heart_texture:
		base = heart_texture.get_size() * 0.5
	return base * Vector2(absf(heart_scale.x), absf(heart_scale.y))


func _make_heart() -> Node2D:
	var n: Node2D
	if heart_texture:
		var s := Sprite2D.new()
		s.texture = heart_texture
		n = s
	else:
		push_warning("Flowery: heart_texture is empty, using a placeholder circle")
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			pts.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * 10.0)
		poly.polygon = pts
		poly.color = Color(1.0, 0.55, 0.1)
		n = poly
	# The heart is never rotated or flipped: it always faces right (as drawn in the texture)
	n.rotation = 0.0
	n.scale = Vector2(absf(heart_scale.x), absf(heart_scale.y))
	return n


# Orange heart controls, in screen space (the screen edges are the limits):
#   arrows        move freely in all four directions, no gravity (slower while charging)
#   charge        hold to charge, release to dash right (longer hold = stronger dash)
func _move_heart(delta: float) -> void:
	if not _heart_active or _heart == null or not is_instance_valid(_heart):
		return

	var ex := _heart_extent()
	var limits := _heart_limits()
	var pos := _heart.position

	# Blink while invincible
	if _heart_iframes > 0.0:
		_heart_iframes -= delta
		_heart.visible = int(_heart_iframes * 20.0) % 2 == 0
	else:
		_heart.visible = true

	if debug_hurt_with_h and Input.is_key_pressed(KEY_H):
		hurt_heart()

	if debug_spawn_test_hazards:
		_test_hazard_timer -= delta
		if _test_hazard_timer <= 0.0:
			_test_hazard_timer = 1.4
			_spawn_test_hazard()

	_update_heart_charge(delta)

	var dir := Input.get_vector(heart_action_left, heart_action_right, heart_action_up, heart_action_down)
	if _heart_locked:
		dir = Vector2.ZERO # locked in place until the first lilypad is reached

	if _hopping:
		pos = _update_hop(delta, pos, dir)
	elif _dashing:
		_dash_time += delta
		if _dash_time > heart_dash_hold_time:
			_dash_speed = maxf(_dash_speed - heart_dash_decel * delta, 0.0)
		# Dashes to the right; the arrows can still steer it a little
		pos += Vector2(_dash_speed, 0.0) * delta + dir * heart_speed * get_strafe_multiplier() * heart_dash_steer * delta

		if _dash_strong:
			_afterimage_timer -= delta
			if _afterimage_timer <= 0.0:
				_afterimage_timer = 0.03
				_spawn_heart_afterimage()

		# Ends when it has slowed to a stop or hits the edge of the screen
		if _dash_speed <= 40.0 or pos.x >= limits.end.x:
			_dashing = false
			_dash_cooldown = _dash_cooldown_len
	else:
		_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
		var move_speed := heart_speed * get_strafe_multiplier()
		if _charging:
			move_speed *= lerpf(1.0, heart_charge_move_factor, _charge)
		pos += dir * move_speed * delta
		_tick_chain_reset(delta)

	# Keep it inside the screen
	pos = pos.clamp(limits.position, limits.end)
	# While jumping the heart is drawn higher than its real (ground) position; the shadow stays on the ground
	_heart.position = pos + Vector2(0.0, -_hop_lift)
	_update_hop_shadow(pos)

	# Touching a lilypad (walking or dashing into it) bounces the heart
	if not _hopping and _heart_active:
		var touched := _pad_under(pos)
		if touched != null:
			_bounce_off(touched, pos)

	# Squash and stretch settles back to normal; a jump makes the heart bigger
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	_heart.scale = Vector2(absf(heart_scale.x), absf(heart_scale.y)) * _squash * _hop_scale

	if not _hopping: # invincible while jumping
		_check_heart_hazards(pos, ex)


func _update_heart_charge(delta: float) -> void:
	var held := Input.is_action_pressed(heart_action_charge)
	var can_charge := not _dashing and not _hopping and not _heart_forced and _dash_cooldown <= 0.0

	# Every fresh press starts from zero
	if can_charge and Input.is_action_just_pressed(heart_action_charge):
		_charge = 0.0
		_charging = true
		_start_charge_sound()

	if _charging and held:
		if _charge < heart_charge_burst:
			# Quick start: closes a third of the gap every 1/30 s
			_charge += (1.0 - _charge) * (1.0 - pow(0.67, delta * 30.0))
			_charge = minf(_charge, heart_charge_burst)
		else:
			_charge = move_toward(_charge, 1.0, delta * (1.0 - heart_charge_burst) / maxf(heart_charge_time, 0.01))
		if _charge_sfx:
			_charge_sfx.pitch_scale = lerpf(0.6, 2.0, _charge)
	elif _charging:
		# Released: any charge dashes, a bigger one dashes harder
		_charging = false
		_stop_charge_sound()
		_start_heart_dash(_charge)
		_charge = 0.0

	# Tint towards the charge colour; flicker once fully charged
	var tint := Color.WHITE.lerp(heart_charge_color, _charge)
	if _charging and _charge >= 1.0 and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		tint = Color.WHITE
	_heart.self_modulate = tint


func _start_heart_dash(charge: float) -> void:
	_dismiss_dash_hint()

	_dash_strong = charge >= heart_weak_dash_threshold
	if _dash_strong:
		var t := inverse_lerp(heart_weak_dash_threshold, 1.0, charge)
		_dash_speed = lerpf(heart_dash_speed_min, heart_dash_speed_max, t)
		_squash = Vector2(1.7, 0.55)
		_play_heart_sfx(heart_dash_heavy_sound if charge > 0.7 else heart_dash_light_sound)
	else:
		_dash_speed = heart_weak_dash_speed
		_squash = Vector2(1.25, 0.85)
		_play_heart_sfx(heart_dash_light_sound)
	_dash_cooldown_len = lerpf(heart_dash_cooldown_max, heart_dash_cooldown_min, charge)
	_dash_time = 0.0
	_dashing = true
	_afterimage_timer = 0.0


func _start_charge_sound() -> void:
	_stop_charge_sound()
	if heart_charge_sound == null:
		return
	_charge_sfx = AudioStreamPlayer.new()
	_charge_sfx.stream = heart_charge_sound
	_charge_sfx.volume_db = -12.0
	add_child(_charge_sfx)
	_charge_sfx.finished.connect(_charge_sfx.play) # loops even if the stream isn't set to loop
	_charge_sfx.play()


func _stop_charge_sound() -> void:
	if _charge_sfx and is_instance_valid(_charge_sfx):
		_charge_sfx.stop()
		_charge_sfx.queue_free()
	_charge_sfx = null


func _play_heart_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ---------------- TRANSITION: LILYPADS ----------------
# Creates a lilypad (also usable by future attacks). Pads live in the heart's layer, behind the heart.
func spawn_lilypad(pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> HeartLilypad:
	var pad := HeartLilypad.new()
	pad.texture = lilypad_texture
	pad.modulate = lilypad_color
	var base := Vector2(140.0, 60.0)
	if lilypad_texture:
		base = lilypad_texture.get_size()
	pad.size = base * Vector2(absf(lilypad_scale.x), absf(lilypad_scale.y)) * lilypad_size_multiplier
	pad.velocity = velocity
	pad.position = pos
	_heart_layer.add_child(pad)
	_heart_layer.move_child(pad, _heart.get_index()) # behind the heart
	_lilypads.append(pad)
	return pad


# Slides the first pad in right in front of the heart and (optionally) locks the heart until it lands.
func _spawn_lilypads() -> void:
	if not lilypad_enabled:
		return
	var rect := _screen_rect()
	var y := _heart.position.y
	var count := 1 + maxi(debug_extra_lilypads, 0)
	for i in count:
		var target_x := _heart.position.x + lilypad_first_distance + lilypad_bounce_distance * i # exactly where a bounce lands, so the pads line up
		var pad := spawn_lilypad(Vector2(rect.end.x + pad_half_width() + 40.0 * i, y))
		var tw := pad.create_tween()
		tw.tween_interval(0.1 * i)
		tw.tween_property(pad, "position:x", target_x, lilypad_slide_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_heart_locked = lilypad_lock_heart


func pad_half_width() -> float:
	var w := 140.0
	if lilypad_texture:
		w = lilypad_texture.get_size().x
	return w * absf(lilypad_scale.x) * lilypad_size_multiplier * 0.5


# A lilypad the heart is touching (the heart's hurtbox against the pad's rectangle).
func _pad_under(pos: Vector2) -> HeartLilypad:
	_lilypads = _lilypads.filter(func(p): return is_instance_valid(p))
	var half := _heart_extent() * heart_hitbox_scale
	var heart_rect := Rect2(pos - half, half * 2.0)
	for p in _lilypads:
		if p.get_pad_rect().intersects(heart_rect):
			return p
	return null


# The heart touched a pad: the pad dips and the heart bounces forward.
func _bounce_off(pad: HeartLilypad, from: Vector2) -> void:
	_bounce_pad(pad)
	_play_heart_sfx(lilypad_jump_sound)
	_heart_locked = false
	_dashing = false
	_hopping = true
	_set_chain(lilypad_chain + 1) # this jump counts: the speeds below depend on it

	_hop_from = from # the ground position (the drawn heart is higher while jumping)
	_hop_t = 0.0
	_hop_disp = 0.0
	_hop_steer = 0.0
	_hop_air_speed = heart_speed * get_strafe_multiplier() # real up/down speed for this jump
	var speed := maxf(lilypad_hop_speed * _jump_speed_factor(), 1.0)

	var next := _find_next_pad(pad, from)
	var dist: float
	if next != null:
		# Calculated landing: the heart ends up exactly on the centre of the next pad (x axis).
		# The pad may be drifting (velocity), so its position at landing time is used.
		# Shortest allowed jump: enough time to strafe to the pad's height, plus reaction time.
		var d0 := next.position.x - from.x
		var half_h := next.size.y * 0.5
		var dy_needed := maxf(absf(next.position.y - from.y) - half_h * 0.5, 0.0) # landing anywhere on the pad's body is enough
		var dur_min := dy_needed / maxf(_hop_air_speed, 1.0) + lilypad_reaction_time
		var vx := next.velocity.x
		var dur := maxf(clampf(absf(d0) / speed, lilypad_hop_time_min, lilypad_hop_time_max), dur_min)
		for i in 4: # the duration depends on the distance, which depends on the duration: a few passes settle it
			dist = d0 + vx * dur
			dur = maxf(clampf(absf(dist) / speed, lilypad_hop_time_min, lilypad_hop_time_max), dur_min)
		dist = d0 + vx * dur
		_hop_dur = dur
	else:
		# Nothing to land on: a fixed distance in front of the pad you bounced off
		dist = pad.position.x + lilypad_bounce_distance - from.x
		_hop_dur = clampf(absf(dist) / speed, lilypad_hop_time_min, lilypad_hop_time_max)

	var land_x := from.x + dist
	if not lilypad_hold_screen_x:
		land_x = minf(land_x, _heart_limits().end.x) # the heart really travels, so the screen edge stops it
	_hop_target = Vector2(land_x, from.y) # the player strafes to the pad's height
	_squash = Vector2(0.8, 1.3)
	_afterimage_timer = 0.0


# The closest pad ahead of the one that was bounced off, within lilypad_next_pad_range.
func _find_next_pad(current: HeartLilypad, from: Vector2) -> HeartLilypad:
	_lilypads = _lilypads.filter(func(p): return is_instance_valid(p))
	var best: HeartLilypad = null
	var best_dx := INF
	for p in _lilypads:
		if p == current:
			continue
		var dx: float = p.position.x - current.position.x
		if dx < 8.0 or dx > maxf(lilypad_next_pad_range, _attack_pad_spacing + 60.0) or p.position.x <= from.x + 8.0:
			continue
		if dx < best_dx:
			best_dx = dx
			best = p
	return best


# Moves everything that is not the heart sideways (dx < 0 = left): lilypads, every hazard, the trail.
# Anything that should react to the jumps only has to be in the group "heart_hazard".
func _shift_world(dx: float) -> void:
	if is_zero_approx(dx):
		return
	for h in get_tree().get_nodes_in_group("heart_hazard"):
		if is_instance_valid(h) and h is Node2D:
			h.global_position.x += dx
	for p in _lilypads:
		if is_instance_valid(p):
			p.position.x += dx
	for g in get_tree().get_nodes_in_group("heart_ghost"):
		if is_instance_valid(g) and g is Node2D:
			g.position.x += dx


# Jump speed as a fraction of lilypad_hop_speed: slow on the first jump, faster on each consecutive one.
func _jump_speed_factor() -> float:
	return minf(lilypad_first_jump_speed + lilypad_jump_speed_gain * maxf(float(lilypad_chain - 1), 0.0), lilypad_jump_speed_max)


# Walk speed multiplier: 1.0 normally, higher while the heart keeps jumping.
func get_strafe_multiplier() -> float:
	return minf(1.0 + lilypad_strafe_gain * lilypad_chain, lilypad_strafe_max)


# Moves the heart along the jump. Size follows a half sine (up, then back down); the dash trail stays on.
func _update_hop(delta: float, pos: Vector2, dir: Vector2) -> Vector2:
	_hop_t += delta / maxf(_hop_dur, 0.01)
	var t := clampf(_hop_t, 0.0, 1.0)
	pos = _hop_from.lerp(_hop_target, t)
	if lilypad_hold_screen_x:
		# The heart keeps its x; the world moves back by the distance it would have travelled
		var disp := (_hop_target.x - _hop_from.x) * t
		_shift_world(-(disp - _hop_disp))
		_hop_disp = disp
		pos.x = _hop_from.x
	if lilypad_air_strafe:
		# The heart's real strafe speed; the jump lasts long enough to reach the next pad at this speed
		_hop_steer += dir.y * _hop_air_speed * delta
		pos.y += _hop_steer # whatever the player steered by is kept, so the landing spot moves with it
	var arc := sin(PI * t)
	_hop_scale = 1.0 + lilypad_jump_scale * arc
	_hop_lift = lilypad_jump_height * arc

	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = 0.03
		_spawn_heart_afterimage()

	if _hop_t >= 1.0:
		_land_hop(pos)
	return pos


func _land_hop(pos: Vector2) -> void:
	_hopping = false
	_hop_scale = 1.0
	_hop_lift = 0.0
	_squash = Vector2(1.35, 0.7)
	_play_heart_sfx(lilypad_land_sound)

	# Landed on another pad: bounce again (unless it is stuck against the screen edge)
	var moved := _hop_from.distance_to(_hop_target) > 8.0
	var next := _pad_under(pos) if moved else null
	if next != null:
		_bounce_off(next, pos)
	else:
		_dash_cooldown = lilypad_land_cooldown
		_chain_idle = lilypad_chain_grace
		_on_first_bounce_done()


# ---------------- TRANSITION: LILYPAD ATTACK ----------------
# Called whenever a bounce chain ends; only the first one starts the attack.
func _on_first_bounce_done() -> void:
	if _lily_attack_started or not lilypad_attack_enabled:
		return
	_lily_attack_started = true
	_run_lilypad_attack() # runs on its own


func _run_lilypad_attack() -> void:
	# 1) push the heart back to the left (controls off meanwhile) and clear the intro pads
	_heart_forced = true
	_heart_locked = true
	_charging = false
	_charge = 0.0
	_stop_charge_sound()
	_clear_lilypads()
	var limits := _heart_limits()
	var target_x := clampf(_screen_rect().size.x * lilypad_pushback_x, limits.position.x, limits.end.x)
	var tw := _heart.create_tween()
	tw.tween_property(_heart, "position:x", target_x, lilypad_pushback_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree() or _heart == null or not is_instance_valid(_heart):
		return
	_heart_forced = false
	_heart_locked = false

	# 2) the pattern, repeated
	await get_tree().create_timer(lilypad_attack_start_delay).timeout
	var spacing := _pattern_spacing()
	_attack_pad_spacing = spacing
	_last_pad_y = -1.0
	for i in lilypad_attack_count:
		if not is_inside_tree() or _heart == null or not is_instance_valid(_heart):
			return
		_spawn_lilypad_pattern(spacing)
		if i < lilypad_attack_count - 1:
			# Everything moves at the same speed, so spacing / speed gives exactly that distance between pads
			var speed := lilypad_attack_speed
			if lilypad_attack_use_chain_speed:
				speed *= get_chain_speed_multiplier()
			await get_tree().create_timer(spacing / maxf(speed, 1.0)).timeout


# Distance from one pad's centre to the next pad's centre: half a pad, the gap, the cactus rows,
# the landing margin, then half of the next pad.
func _pattern_spacing() -> float:
	var rows := maxi(lilypad_attack_cactus_rows, 0)
	var cacti := rows * lilypad_attack_cactus_width + maxi(rows - 1, 0) * lilypad_attack_cactus_gap
	return pad_half_width() + lilypad_attack_pad_gap + cacti + lilypad_attack_landing_margin + pad_half_width()


# How far up or down the next pad may be from this one so the heart can strafe there in time.
# Uses the same numbers as the jump itself (jump speed and strafe speed for the chain it is likely to be at,
# the drifting of the pads, the reaction time) and keeps a safety margin.
func _max_pad_dy(spacing: float) -> float:
	var chain := lilypad_chain + 2 # chain count when the heart jumps off the previous pad (worst case: later = shorter jumps)
	var factor := minf(lilypad_first_jump_speed + lilypad_jump_speed_gain * float(maxi(chain - 1, 0)), lilypad_jump_speed_max)
	var jump_speed := maxf(lilypad_hop_speed * factor, 1.0)
	var strafe := heart_speed * minf(1.0 + lilypad_strafe_gain * float(chain), lilypad_strafe_max)
	var vx := -lilypad_attack_speed
	# The heart lands in the middle of a pad, so the next pad is "spacing" away when it jumps again
	var dur := clampf(spacing / jump_speed, lilypad_hop_time_min, lilypad_hop_time_max)
	for i in 4:
		var dist := spacing + vx * dur
		dur = clampf(absf(dist) / jump_speed, lilypad_hop_time_min, lilypad_hop_time_max)
	return maxf(strafe * (dur - lilypad_reaction_time) * lilypad_attack_reach_safety, 0.0)


# One lilypad followed by rows of cacti, all drifting left together.
func _spawn_lilypad_pattern(spacing: float) -> void:
	var rect := _screen_rect()
	var limits := _heart_limits()
	var speed := lilypad_attack_speed
	if lilypad_attack_use_chain_speed:
		speed *= get_chain_speed_multiplier()
	var vel := Vector2(-speed, 0.0)

	# Height: random inside the allowed band, but never further from the previous pad than the heart can strafe
	var y_low := lerpf(limits.position.y, limits.end.y, minf(lilypad_attack_pad_y_min, lilypad_attack_pad_y_max))
	var y_high := lerpf(limits.position.y, limits.end.y, maxf(lilypad_attack_pad_y_min, lilypad_attack_pad_y_max))
	if _last_pad_y >= 0.0:
		var dy := _max_pad_dy(spacing)
		y_low = maxf(y_low, _last_pad_y - dy)
		y_high = minf(y_high, _last_pad_y + dy)
		if y_low > y_high: # the band and the reach don't overlap: stay as close to the previous pad as the band allows
			y_low = clampf(_last_pad_y, lerpf(limits.position.y, limits.end.y, minf(lilypad_attack_pad_y_min, lilypad_attack_pad_y_max)), lerpf(limits.position.y, limits.end.y, maxf(lilypad_attack_pad_y_min, lilypad_attack_pad_y_max)))
			y_high = y_low
	var y := randf_range(y_low, y_high)
	_last_pad_y = y
	var pad_half := pad_half_width()
	var x := rect.end.x + pad_half + 20.0
	spawn_lilypad(Vector2(x, y), vel)

	# The cacti are the ones from the wall attack: same texture, full height of the screen
	var w := lilypad_attack_cactus_width
	var first_x := x + pad_half + lilypad_attack_pad_gap + w * 0.5
	for i in lilypad_attack_cactus_rows:
		var cactus := HeartHazard.new()
		cactus.blue = false
		cactus.size = Vector2(w, rect.size.y + lilypad_attack_cactus_extra_height)
		cactus.velocity = vel
		cactus.texture = jarona3HurtTexture
		cactus.tile = jarona3ArtMode == WallArt.TILE
		cactus.position = Vector2(first_x + (w + lilypad_attack_cactus_gap) * i, rect.size.y * 0.5)
		_heart_layer.add_child(cactus)
		_heart_layer.move_child(cactus, _heart.get_index()) # behind the heart


# Fades the pads that are on screen out (they stop bouncing the heart straight away).
func _clear_lilypads() -> void:
	for p in _lilypads:
		if is_instance_valid(p):
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "modulate:a", 0.0, 0.3)
			tw.tween_callback(p.queue_free)
	_lilypads.clear()


# The pad dips when the heart lands and springs back.
func _bounce_pad(pad: HeartLilypad) -> void:
	var tw := pad.create_tween()
	pad.scale = lilypad_land_squash
	tw.tween_property(pad, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A dark oval on the ground under the jumping heart; it shrinks as the heart rises.
func _update_hop_shadow(ground_pos: Vector2) -> void:
	if not _hopping:
		if _hop_shadow and is_instance_valid(_hop_shadow):
			_hop_shadow.visible = false
		return
	if _hop_shadow == null or not is_instance_valid(_hop_shadow):
		_hop_shadow = Polygon2D.new()
		var pts := PackedVector2Array()
		var ex := _heart_extent()
		for i in 16:
			pts.append(Vector2(cos(TAU * i / 16.0) * ex.x, sin(TAU * i / 16.0) * ex.y * 0.4))
		_hop_shadow.polygon = pts
		_hop_shadow.color = lilypad_shadow_color
		_heart_layer.add_child(_hop_shadow)
		_heart_layer.move_child(_hop_shadow, _heart.get_index()) # behind the heart
	_hop_shadow.visible = true
	_hop_shadow.position = ground_pos + Vector2(0.0, _heart_extent().y * 0.6)
	_hop_shadow.scale = Vector2.ONE * (1.0 - 0.4 * clampf(_hop_lift / maxf(lilypad_jump_height, 1.0), 0.0, 1.0))


# The chain resets once the heart has stopped jumping for a moment.
func _tick_chain_reset(delta: float) -> void:
	if lilypad_chain <= 0 or _hopping:
		return
	_chain_idle -= delta
	if _chain_idle <= 0.0:
		_set_chain(0)


func _set_chain(count: int) -> void:
	if count == lilypad_chain:
		return
	lilypad_chain = count
	lilypad_chain_changed.emit(count)


# 1.0 normally; grows with every consecutive jump until the heart stops jumping. For later attacks:
# multiply their speed (or divide their delays) by this.
func get_chain_speed_multiplier() -> float:
	return minf(1.0 + lilypad_chain_speed_step * lilypad_chain, lilypad_chain_speed_max)


# ---------------- TRANSITION: HEART vs ATTACKS ----------------
# Checks every node in the group "heart_hazard" against the heart (see the HeartHazard class).
#  - a dash (strong, or any dash if heart_weak_dash_attacks) breaks BLUE attacks and flies through them
#  - anything else that touches the heart hurts it (hurt_heart handles the invincibility)
func _check_heart_hazards(pos: Vector2, ex: Vector2) -> void:
	var half := ex * heart_hitbox_scale
	var heart_rect := Rect2(pos - half, half * 2.0)
	var attacking := _dashing and (_dash_strong or heart_weak_dash_attacks)

	for h in get_tree().get_nodes_in_group("heart_hazard"):
		if not is_instance_valid(h) or not h.has_method("get_hazard_rect"):
			continue
		var r: Rect2 = h.get_hazard_rect()
		if not r.intersects(heart_rect):
			continue
		if attacking and h.get("blue") == true:
			_break_hazard(h, r)
		elif not (_dashing and heart_dash_invulnerable):
			hurt_heart()


func _break_hazard(h: Node, r: Rect2) -> void:
	var p := CPUParticles2D.new()
	_heart_layer.add_child(p)
	p.position = r.get_center()
	_setup_break_particles(p, r.size)
	if h.has_method("on_heart_dash_break"):
		h.on_heart_dash_break()
	else:
		h.remove_from_group("heart_hazard")
		h.queue_free()


# Testing only (debug_spawn_test_hazards): blue and red blocks flying in from the right.
func _spawn_test_hazard() -> void:
	var rect := _screen_rect()
	var h := HeartHazard.new()
	h.blue = randi() % 2 == 0
	h.size = Vector2(40.0, randf_range(60.0, 140.0))
	h.position = Vector2(rect.end.x + h.size.x, rect.end.y - h.size.y * 0.5 - randf_range(0.0, 140.0))
	_heart_layer.add_child(h)
	_heart_layer.move_child(h, _heart.get_index()) # behind the heart


# ---------------- TRANSITION: DASH HINT ----------------
# Faded text on the screen that stays until the first dash.
func _spawn_dash_hint() -> void:
	if _dash_hint_done or dash_hint_text.is_empty():
		return
	var rect := _screen_rect()
	_dash_hint = Label.new()
	_dash_hint.text = dash_hint_text
	_dash_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dash_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dash_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_hint.add_theme_font_size_override("font_size", dash_hint_font_size)
	_dash_hint.add_theme_color_override("font_color", dash_hint_color)
	if dash_hint_font:
		_dash_hint.add_theme_font_override("font", dash_hint_font)
	_dash_hint.size = Vector2(rect.size.x, 60.0)
	_dash_hint.position = Vector2(0.0, rect.size.y * dash_hint_screen_y - 30.0)
	_dash_hint.modulate.a = 0.0
	_heart_layer.add_child(_dash_hint)
	_dash_hint.create_tween().tween_property(_dash_hint, "modulate:a", 1.0, heart_fade_time)


func _dismiss_dash_hint() -> void:
	if _dash_hint_done:
		return
	_dash_hint_done = true
	if _dash_hint and is_instance_valid(_dash_hint):
		var tw := _dash_hint.create_tween()
		tw.tween_property(_dash_hint, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_dash_hint.queue_free)


# Call this from anything that should hurt the heart (walls, bullets...).
# Every player character gets hurt, then the heart is invincible for a moment.
func hurt_heart() -> void:
	if not _heart_active or _heart_iframes > 0.0 or _hopping:
		return
	if _dashing and heart_dash_invulnerable:
		return
	_heart_iframes = heart_iframes_time
	for p in BossTargets.everyone(get_tree()):
		_hurt_player(p)


# A fading yellow copy left behind while dashing.
func _spawn_heart_afterimage() -> void:
	var ghost := _heart.duplicate() as Node2D
	_heart_layer.add_child(ghost)
	_heart_layer.move_child(ghost, _heart.get_index()) # behind the real heart
	ghost.add_to_group("heart_ghost") # the jumps scroll the trail left
	ghost.position = _heart.position
	ghost.modulate.a = 0.5
	ghost.self_modulate = heart_charge_color
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


# Pauses the real players so they can't walk off or get hurt behind the black screen.
func _freeze_players() -> void:
	for p in BossTargets.everyone(get_tree()):
		if p is Node and is_instance_valid(p):
			_frozen_players.append([p, p.process_mode])
			p.process_mode = Node.PROCESS_MODE_DISABLED


# Not called anywhere yet: use it when the transition ends and the players get control back.
func _unfreeze_players() -> void:
	for entry in _frozen_players:
		if is_instance_valid(entry[0]):
			entry[0].process_mode = entry[1]
	_frozen_players.clear()


# ---------------- DEATH ----------------
func _die() -> void:
	state = State.DYING
	_attack_token += 1
	GlobalCanvasLayer.tricks += 10 # same reward as the other bosses
	if lyrics:
		lyrics.stop(0.8)
	timer.stop()
	_clear_hitboxes()
	voice_player.stop()
	attack_box.set_deferred("monitoring", false)
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_end_lunge()
	_play_anim(&"death")

	# Same death overlay animation the other bosses play, if this scene has it
	var overlay_anim := get_node_or_null("TextureRect/AnimationPlayer") as AnimationPlayer
	if overlay_anim and overlay_anim.has_animation(&"end"):
		overlay_anim.play(&"end")

	Engine.time_scale = 0.25
	var fall := create_tween().set_parallel(true)
	fall.tween_property(sprite, "global_position:y", sprite.global_position.y + 1500, 1.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(sprite, "rotation", sprite.rotation + TAU * 2, 1.2)

	await get_tree().create_timer(0.35, true, false, true).timeout
	Engine.time_scale = 1.0
	await fall.finished

	if end.get_connections().is_empty():
		push_warning("Flowery: 'end' has no listeners, so the level script never learns the boss died")
	defeated.emit()
	end.emit()
	queue_free()
