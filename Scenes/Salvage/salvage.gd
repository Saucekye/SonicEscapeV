extends Node3D
# Salvage: first-person mini game reached from the rest tree

const WORLD_SHADER := preload("res://Shaders/ps1_world.gdshader")
const SCREEN_SHADER := preload("res://Shaders/ps1_screen.gdshader")
const FINISH_SHADER := preload("res://Shaders/ps1_finish.gdshader")
const GLOW_SHADER := preload("res://Shaders/ps1_glow.gdshader")
const PLAYER := preload("res://Scenes/Salvage/salvage_player.tscn")
const TEAMMATE := preload("res://Scenes/Salvage/salvage_teammate.tscn")
const START_AREA := preload("res://Scenes/Salvage/start_area.tscn")
const EXIT_ELEVATOR := preload("res://Scenes/Salvage/exit_elevator.tscn")
const MIRROR := preload("res://Scenes/Salvage/salvage_mirror.gd")
const BRACKEN := preload("res://Scenes/Salvage/bracken.gd")
const SLENDER := preload("res://Scenes/Salvage/slender.gd")
const FREDDY := preload("res://Scenes/Salvage/freddy.gd")
const TAILS_DOLL := preload("res://Scenes/Salvage/tails_doll.gd")
const ROOM := preload("res://Scenes/Salvage/room.gd")
const MX := preload("res://Scenes/Salvage/mx.gd")
const CLONE := preload("res://Scenes/Salvage/clone.gd")
const MIMIC := preload("res://Scenes/Salvage/mimic.gd")
const SPIDER := preload("res://Scenes/Salvage/spider.gd")
const SHADOW_SHADER := preload("res://Shaders/blob_shadow.gdshader")
const RAGDOLL_CARD := preload("res://Shaders/ragdoll_card.gdshader")
const VISION := preload("res://Scenes/Salvage/salvage_vision.gd")
const CEILING_LAYER := 1 << 11   # ceilings and roofs
const MAP := preload("res://Scenes/Salvage/salvage_map.gd")
const TOUCH := preload("res://Scenes/Salvage/salvage_touch.gd")
const MATERIALS_DIR := "res://Scenes/Salvage/Materials/"
const RETURN_SCENE := "res://Scenes/Level/test3.tscn"

const SIGN_BOARD := preload("res://Scenes/Salvage/Materials/board.tres")   # the posts
const UP_Y := 40.0                    # floor of the enormous room above
const CHUNK_CELL := 4.0               # the size the chunk scenes are made at
const HOLE := 1.1                     # half-size of the hole you drop through
const LOOKING_AT := 0.85             # how near the middle of your view a hunter has to be to count as looked at
const MAX_LAMPS := 48                 # what the shader can light
enum { LAMP_DEAD, LAMP_STUTTER, LAMP_ON }
const TAG_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.18, 0.18), Color(0.25, 0.9, 0.35), Color(1.0, 0.85, 0.15),
	Color(0.7, 0.35, 1.0), Color(1.0, 0.55, 0.1), Color(0.2, 0.9, 0.95), Color(1.0, 0.45, 0.75)]   # 1P to 8P

@export var start_facing_mirror := true     ## each visit starts with you looking at yourself in the elevator's mirror
@export_group("Layout")
@export var max_maze_size := Vector2i(14, 14)   ## corridor cells across and deep at its biggest
@export_range(2, 3) var start_paths := 3      ## like Lethal Company
@export var min_maze_size := Vector2i(10, 10)   ## its size on the early floors
@export var small_until_floor := 0              ## floors up to this get the smallest facility
@export var full_size_floor := 40               ## by this floor it's grown to its biggest
@export var cell_size := 6.0                ## metres per corridor cell
@export var wall_height := 3.2              ## corridor height
@export_range(0.0, 1.0) var extra_openings := 0.4    ## share of extra walls knocked out
@export_range(1, 5) var floor_levels := 3   ## how many floor heights the corridors are on
@export var level_step := 1.6               ## metres between floor heights
@export_range(0.0, 1.0) var stairs := 0.3   ## share of straight corridors that become staircases
@export_group("Lamps")
@export_range(0, 300) var lamp_count := 54   ## ceiling lamps at the biggest size
@export_range(0.0, 1.0) var dead_lamps := 0.45      ## share of them that are dead
@export_range(0.0, 1.0) var stuttering_lamps := 0.35 ## share that cut out in bursts
@export_group("Scary Lighting")
@export var lamp_color := Color(0.62, 0.78, 0.5)     ## the ceiling lamps' light
@export var lamp_reach := 3.8                         ## metres a lamp lights around it
@export var lamp_brightness := 0.8                    ## how bright a working lamp is
@export var flashlight_color := Color(0.78, 0.86, 0.95)   ## your flashlight
@export var flashlight_reach := 11.0                  ## metres it reaches before the dark swallows it
@export var flashlight_width := 0.83                  ## how narrow the beam is
@export var darkness := 0.035                         ## how fast lit things fade into black with distance
@export var hunter_flicker_distance := 12.0          ## looking at a hunter this close makes your flashlight stutter
@export var power_dip_every := Vector2(25.0, 50.0)   ## seconds between every lamp dipping at once
@export var power_dip_time := 1.6                     ## how long the lamps stay dipped
@export var hunter_glow := 0.9                        ## up close, a hunter shows clear as day even in the dark
@export var hunter_glow_distance := 20.0              ## from this far away it starts to stand out, brighter as it gets closer
@export_group("Dread")
## How the visit plays out, like a horror film
@export_range(0.0, 1.0) var dread_volume := 1.0       ## all of it
@export var dread_silent_for := 25.0                  ## seconds down in the maze before the hum starts
@export var dread_calm_time := 20.0                   ## then seconds of just the hum before anything happens
@export var dread_events_every := Vector2(18.0, 32.0)   ## seconds between things happening, when it starts
@export var dread_events_every_late := Vector2(9.0, 17.0)   ## ...and by the time the hunters are in
@export var dread_heartbeat_distance := 16.0          ## a hunter this close
@export var dread_quiet_distance := 9.0               ## one this close that you haven't seen
@export var dread_sting_cooldown := 25.0              ## seconds before seeing the same hunter hits as hard again
@export var dread_lights_out_time := 2.2              ## the lights cutting out
@export_range(0.0, 1.0) var dread_hum_volume := 0.16
@export_range(0.0, 1.0) var dread_layer_volume := 0.35
@export_range(0.0, 1.0) var dread_heartbeat_volume := 0.9
@export var dread_hum: AudioStream = preload("res://Sounds/Salvage/ambience_hum.wav")        ## the building
@export var dread_layer: AudioStream = preload("res://Sounds/Salvage/ambience_dread.wav")    ## the dread underneath
@export var dread_heartbeat: AudioStream = preload("res://Sounds/Salvage/heartbeat.wav")
@export var dread_stings: Array[AudioStream] = []   ## a sting when you see a hunter
@export var dread_knocks: Array[AudioStream] = [preload("res://Sounds/Salvage/knock_1.wav"), preload("res://Sounds/Salvage/knock_2.wav"), preload("res://Sounds/Salvage/knock_3.wav")]
@export var dread_creaks: Array[AudioStream] = [preload("res://Sounds/Salvage/creak_1.wav"), preload("res://Sounds/Salvage/creak_2.wav")]
@export var dread_slam: AudioStream = preload("res://Sounds/Salvage/door_slam.wav")
@export var dread_whispers: Array[AudioStream] = [preload("res://Sounds/Salvage/whisper_1.wav"), preload("res://Sounds/Salvage/whisper_2.wav"), preload("res://Sounds/Salvage/whisper_3.wav")]
@export var dread_steps: Array[AudioStream] = [preload("res://Sounds/Salvage/step_behind_1.wav"), preload("res://Sounds/Salvage/step_behind_2.wav"), preload("res://Sounds/Salvage/step_behind_3.wav")]   ## footsteps behind you
@export var dread_lights_out: AudioStream = preload("res://Sounds/Salvage/lights_out.wav")
@export var dread_music_box: AudioStream = preload("res://Sounds/Salvage/music_box.wav")   ## somewhere far off
@export var dread_breathing: AudioStream = preload("res://Sounds/Salvage/breathing.wav")   ## the Bracken, close by
@export var dread_slender_hum: AudioStream = preload("res://Sounds/Salvage/hum_electric.wav")   ## Slender Man, all the time
@export_group("Items")
@export var item_count := 9                ## items at the biggest size
@export var item_kinds: Array[SalvageItem] = []   ## which kinds can turn up
@export var item_placeholder: Texture2D = preload("res://Sprites/Salvage/item_box.png")   ## shown for items without their own picture
@export var item_placeholder_height := 0.95   ## how tall the placeholder stands, in metres
@export_group("Chunks")
## The corridor chunks the facility is built from
@export var chunks: Array[PackedScene] = [
	preload("res://Scenes/Salvage/Chunks/dead_end.tscn"),
	preload("res://Scenes/Salvage/Chunks/straight.tscn"),
	preload("res://Scenes/Salvage/Chunks/corner.tscn"),
	preload("res://Scenes/Salvage/Chunks/t_junction.tscn"),
	preload("res://Scenes/Salvage/Chunks/crossroads.tscn"),
	preload("res://Scenes/Salvage/Chunks/stairs.tscn"),
]
@export_group("Rings")
@export_file("*.MP3", "*.mp3", "*.wav", "*.ogg") var ring_sound := "res://Sounds/Obstacles/Rings/ringsfx.MP3"
@export_range(-40.0, 6.0) var ring_volume_db := -18.0   ## the ring pickup sound
@export var ring_trail_every := 5           ## a line of rings every this many corridors on the way to the exit
@export var decoy_ring_groups := 3          ## lines of rings off the way to the exit
@export var ring_texture: Texture2D = preload("res://Sprites/Obstacles/Rings/ringsheet-sheet.png")
@export_group("Hazards")
@export var spike_chunk: PackedScene = preload("res://Scenes/Salvage/Chunks/straight_spikes.tscn")   ## a straight corridor with spikes across it
@export var pit_chunk: PackedScene = preload("res://Scenes/Salvage/Chunks/straight_pit.tscn")         ## a straight corridor with a gap to jump
@export var hazards_from_floor := 0         ## no spikes, pits or mines before this floor
@export var spike_strips := 3                ## at the biggest size
@export var pits := 2                        ## at the biggest size
@export var hazards_kill_without_rings := true   ## spikes (and mines, with Mines Kill off) only cost you rings
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var ring_loss_sound := "res://Sounds/SonicSFX/sonic-rings-drop.MP3"
@export var spike_ring_loss := 30            ## rings lost when spikes get you
@export var spike_push := 5.0                ## how hard they throw you back
@export var mine_scene: PackedScene = preload("res://Scenes/Salvage/mine.tscn")   ## step on it: click
@export var mines := 6                       ## at the biggest size
@export var mine_size := 3.0                 ## how big they are
@export var mine_fuse := 0.0                 ## seconds from stepping off to the blast
@export var mine_blast_radius := 3.0         ## anyone this close when it goes off is caught in it
@export var crushers := 4                    ## spiked crushers in the ceiling, at the biggest size
@export var crushers_from_floor := 9         ## none before this floor
@export var crusher_sense := 0.6             ## it senses anyone this close to the stretch under it
@export var crusher_react := 0.25            ## seconds from sensing you to dropping
@export var crusher_rearm := 1.0             ## once it's wound back up, this long before it can sense anyone again
@export var crusher_down_time := 0.8         ## how long it stays down
@export var crusher_slam_sound: AudioStream = preload("res://Sounds/Salvage/door_slam.wav")
@export var crusher_shake := 0.5             ## the slam shakes your camera this hard right next to it
@export var tables := 8                      ## metal tables to crawl under, at the biggest size
@export var table_height := 0.85             ## the top (you crouch to 0.6 m)
@export var grate_area := true               ## a stretch of the maze floored with rusted metal grates over darkness
@export var grate_size := 4                  ## how many cells out from its middle it spreads
@export var mirror_area := true              ## a corridor lined with mirrors on both walls
@export var mirror_length := 3               ## cells long
@export var mirror_ghost_every := Vector2(6.0, 14.0)   ## seconds between
@export var mirror_ghost_time := 2.5         ## how long it stands there
@export var narrow_corridors := 5           ## straight corridors squeezed so tight only one person fits through at a time
@export var narrow_width := 0.95             ## how wide the gap is
@export var narrow_safe := true             ## the hunters don't fit in them
@export var mines_kill := true               ## caught in a blast is the end of you, like a pit
@export var mine_ring_loss := 60             ## with Mines Kill off
@export var mine_push := 10.0                ## how hard a blast you survive throws you
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var mine_click_sound := "res://Sounds/SonicSFX/Sonic Homing Attack Reticle SFX.mp3"
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var mine_blast_sound := "res://Sounds/Obstacles/Mine/MineDetonate.wav"
@export var mine_blast_texture: Texture2D = preload("res://misc/explode/explode.png")   ## the levels' explosion, frames side by side
@export var mine_blast_frames := 7
@export_group("Deaths")
@export var ragdolls := true                 ## characters that die get flung around as physics bodies
@export var hunter_fling := 7.0              ## how hard a hunter throws whoever it catches
@export var mine_fling := 14.0               ## how hard a mine throws someone right on top of it
@export var ragdoll_spin := 9.0              ## how fast bodies tumble
@export var knockdowns := true               ## spikes or a mine you live through send you flying
@export var knockdown_time := 1.4            ## at least this long on the ground before you're back in control
@export var ragdoll_card_spin := 1.6         ## how fast the flung picture spins, for that tumble
@export var ragdoll_bounce := 0.35
@export var camera_shake := 1.0              ## explosions shake the camera
@export var blast_shake_range := 20.0        ## felt this far from a blast
@export var blast_shake_close := 2.6         ## how violent it is right next to one
@export var blast_smoke := 0.8               ## how thick the smoke a blast leaves is
@export var blast_smoke_size := Vector2(3.0, 7.0)   ## the smoke's reach in metres
@export var blast_smoke_time := 14.0         ## seconds for it to thin out and drift away
@export_range(0.0, 1.0) var blast_echo := 0.6   ## how much a blast rings round the corridors
@export_group("Shadows")
@export var character_shadows := true        ## a dark patch on the floor under players, teammates and hunters
@export_range(0.0, 1.0) var shadow_darkness := 0.65
@export var shadow_size := 0.85               ## across, in metres, for you
@export var shadow_width := 0.8               ## everyone else
@export var shadow_lean := 0.7                ## how far shadows stretch away from nearby lamps
@export var shadow_fade_height := 3.0         ## gone by the time someone is this far above the floor
@export var hunter_outline_shadows := true    ## hunters cast their own outline across the floor, not a round patch
@export var hunter_shadow_length := Vector2(0.45, 1.3)   ## outline length as a share of their height
@export_group("Fog")
@export var fog_areas := 2                   ## thick-fog areas at the biggest size
@export var fog_from_floor := 4              ## no fog before this floor
@export var fog_radius := 7.0                ## how big each foggy area is
@export var fog_density := 0.7               ## how thick it is inside
@export var fog_sight := 5.0                 ## in the fog, nobody sees further than this
@export var fog_color := Color(0.34, 0.35, 0.37)
@export var fog_clear_time := 2.5            ## seconds for the fog to lift once the latch is pulled
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var latch_sound := "res://Sounds/SonicSFX/Sonic Homing Attack Reticle SFX.mp3"
@export_group("Spectating")
@export var ragdoll_third_person := true     ## caught or blown up
@export var ragdoll_camera_distance := 3.2   ## how far back it pulls
@export var spectate := true                 ## like Lethal Company
@export var spectate_after := 4.5            ## seconds after you're caught before you start watching
@export var spectate_distance := 2.6         ## how far behind them the camera floats
@export var spectate_turn_speed := 2.6       ## right stick
@export_group("Exit")
@export var depart_time := 10.0             ## seconds from pressing ESCAPE to the elevator leaving
@export var depart_countdown_size := 64     ## the countdown everyone sees while the doors close
@export var doors_open_after := 2.6         ## seconds before the start elevator's doors open
@export_group("Map")
@export var map_enabled := true              ## M / Tab, Back on a controller, or the map button on touch screens
@export var map_color := Color(0.78, 0.78, 0.74)     ## the corridors you've walked
@export var map_you_color := Color(0.9, 0.1, 0.12)   ## your arrow
@export var map_exit_color := Color(0.25, 0.85, 0.35)  ## the exit, once you've been there
@export var map_entrance_color := Color(0.35, 0.6, 1.0)  ## the entrance
@export var map_back_color := Color(0, 0, 0, 0.72)     ## behind the map
@export_group("Touch Controls")
@export var touch_look_speed := 1.6          ## how fast dragging on the right side turns you
@export var touch_button_scale := 1.0        ## size of the jump, sprint, crouch and map buttons
@export var touch_stick_radius := 105.0      ## how far you drag the walking stick for full speed
@export_group("Characters")
@export_range(0.0, 1.0) var character_brightness := 0.6   ## teammates never get darker than this
@export_group("Miku")
@export var mikus := 1                       ## Mikus waiting somewhere down here each visit
@export var miku_height := 1.5               ## metres tall
@export var miku_looks: Array[Texture2D] = []   ## her pictures, one picked each visit
@export var miku_frames := 13                ## frames across her picture strip
@export var miku_idle_frames: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]   ## her idle animation, played the whole time
@export var miku_idle_fps := 13.0
@export var miku_gap := 1.3                  ## how far behind whoever she follows she walks
@export_group("Reviving")
@export_group("Rewrite Tree")
## Going in from the rest tree with Rewrite Sonic in it is worse
@export var danger_extra_hunters := 1        ## one more hunter than usual
@export var danger_extra_from_floor := 20    ## ...from this floor on
@export var danger_early_hunters := 0        ## on floors that usually have none, this many
@export var danger_hunters_sooner := 0.5     ## they turn up after this share of the usual time
@export var danger_hazards := 1.5            ## this many times the mines, spikes and pits
@export_range(0.0, 1.0) var danger_dead_lamps := 0.25   ## this much more of the lamps are dead
@export_group("Stun and Survive")
## The Stun item
@export var stun_range := 10.0              ## how far it reaches
@export var stun_time := 6.0                ## seconds they're frozen
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var stun_sound := "res://Sounds/Salvage/stun.wav"
@export var stun_color := Color(0.65, 0.85, 1.6)   ## a stunned hunter's tint
## The Survive item
@export var survive_grace := 3.0            ## seconds nothing can get you after
@export_group("Chaos Emerald")
## A Chaos Emerald sits in the exit elevator
@export var chaos_emerald := true
@export var emerald_from_floor := 9         ## no emerald before this floor
@export var emerald_texture: Texture2D = preload("res://Sprites/Intro/emerald.png")   ## its picture (a strip of frames across), when the list below is empty
## Each emerald a different colour, like the Sonic games
@export var emerald_colours: Array[Texture2D] = [
	preload("res://Sprites/Salvage/Emeralds/emerald_1_green.png"), preload("res://Sprites/Salvage/Emeralds/emerald_2_red.png"),
	preload("res://Sprites/Salvage/Emeralds/emerald_3_blue.png"), preload("res://Sprites/Salvage/Emeralds/emerald_4_yellow.png"),
	preload("res://Sprites/Salvage/Emeralds/emerald_5_cyan.png"), preload("res://Sprites/Salvage/Emeralds/emerald_6_purple.png"),
	preload("res://Sprites/Salvage/Emeralds/emerald_7_white.png")]
## Once you have all 7
@export var super_emerald_colours: Array[Texture2D] = [
	preload("res://Sprites/Salvage/Emeralds/super_emerald_1_green.png"), preload("res://Sprites/Salvage/Emeralds/super_emerald_2_red.png"),
	preload("res://Sprites/Salvage/Emeralds/super_emerald_3_blue.png"), preload("res://Sprites/Salvage/Emeralds/super_emerald_4_yellow.png"),
	preload("res://Sprites/Salvage/Emeralds/super_emerald_5_cyan.png"), preload("res://Sprites/Salvage/Emeralds/super_emerald_6_purple.png"),
	preload("res://Sprites/Salvage/Emeralds/super_emerald_7_white.png")]
@export var super_emerald_size := 1.45      ## how much bigger a Super Emerald is
## The glow round each one
@export var emerald_glows: Array[Color] = [Color(0.3, 1.0, 0.4), Color(1.0, 0.25, 0.25), Color(0.3, 0.5, 1.0),
	Color(1.0, 0.9, 0.3), Color(0.3, 0.95, 1.0), Color(0.8, 0.35, 1.0), Color(0.95, 0.95, 1.0)]
@export var emerald_frames := 9
@export var emerald_fps := 12.0
@export var emerald_size := 0.28            ## how big it looks
@export var emerald_rings := 50             ## rings for whoever gets out with it
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var alarm_sound := "res://Sounds/Salvage/nuclear_alarm.mp3"   ## loops until you're out
@export var alarm_volume_db := 2.0
@export var alarm_color := Color(1.0, 0.08, 0.06)   ## the lamps' light once the alarm's going
@export var alarm_brightness := 1.1        ## how brightly the whole maze is lit red
@export_range(0.0, 1.0) var alarm_screen_red := 0.0    ## a red wash over the screen too
@export var alarm_hunt_time := 45.0         ## seconds every hunter goes straight for whoever has it
@export var emerald_hunter_speed := 1.7   ## once you've taken the Chaos Emerald, every hunter moves this many times faster
@export var alarm_extra_hunter := true      ## the alarm brings more hunters into the maze
@export var alarm_extra_hunters := 2         ## how many more
@export var alarm_mines := 8                 ## when it goes red, this many more mines go down along your way back to the entrance
@export var alarm_blast_reach := 1.5         ## and every mine's blast reaches this many times further
@export var alarm_in_your_way := true        ## the hunters it brings out turn up between you and the entrance
@export var alarm_after_leaving := 2.5      ## the alarm waits till whoever took it is this far out of the elevator
@export var blackout_time := 2.0            ## ...then this much longer in the dark, then the alarm
@export var alarm_red_time := 7.0            ## the alarm and the red last this many seconds
@export var emerald_drop_dark := true        ## if whoever has it dies, it drops and the whole place goes dark and silent
@export_range(0.0, 1.0) var dark_flashlight := 0.2   ## taking it cuts every light
@export var chaos_control_reach := 3.0      ## how close to where you dropped in you have to be
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var power_out_sound := "res://Sounds/Salvage/power_out.mp3"   ## the lights cutting out as you take it
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var dead_button_sound := "res://Sounds/Salvage/button_dead.mp3"   ## pressing ESCAPE once it's too late
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var chaos_control_sound := "res://Sounds/SonicSFX/sparklesfx.MP3"
@export_group("Hunters")
@export_flags("Bracken", "Slender Man", "Freddy", "Tails Doll", "ROOM", "MX", "Clone", "Mimic", "Spider") var hunters := 511   ## which hunters can turn up
@export var hunters_from_floor := 8         ## no hunters before this floor
@export var hunter_floors: Array[int] = [4]   ## one hunter on these floors, even before Hunters From Floor
@export var no_hunter_floors: Array[int] = [8]   ## never any hunters on these floors
@export var more_hunters_at_floors: Array[int] = [20, 30, 45]   ## one hunter per visit, plus one more from each of these floors on
@export var three_hunters_from_floor := 20   ## never more than 2 hunters before this floor
@export var first_hunter_after := 70.0       ## seconds into the visit before the first one turns up
@export var next_hunter_after := 90.0        ## then each other one this many seconds after the last
@export var meet_before_exit := 4            ## every hunter on the floor crosses your path before you reach the exit
@export_range(0.05, 1.0) var hunter_waits_shrink_to := 0.35   ## the waits above
@export var hunter_waits_shortest_at := 40   ## ...by this floor
@export var hunter_settle_time := 25.0       ## once one turns up, it just wanders this long before it starts hunting anyone
@export var hunter_sight_range := 28.0       ## how far away you can see a hunter
@export_range(5.0, 90.0) var hunter_view_angle := 44.0   ## how far from the middle of your view
@export var hunter_catch_distance := 1.05    ## how close a walking hunter has to get to catch you
@export var hidden_safe_distance := 2.5      ## crouched behind cover, hunters lose you unless they're this close
@export var jumpscares := true               ## a hunter that gets you lunges at your screen
@export_range(-10.0, 20.0) var jumpscare_volume_db := 10.0   ## how loud the jumpscare sounds are
@export_range(1.0, 3.0) var jumpscare_closeness := 1.5
@export_range(0.0, 0.05) var jumpscare_shake := 0.016   ## how far it jerks about each frame
@export_range(0.0, 2.0) var jumpscare_wild := 1.0   ## the thrash on top
@export var jumpscare_shake_speed := 120.0   ## how fast it throbs in and out
@export var jumpscare_black := true          ## the jumpscare comes at you out of a black screen
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var jumpscare_sound := "res://Sounds/Obstacles/2011X/jumpscare.MP3"
@export var jumpscare_time := 1.1            ## seconds it stays in your face, shaking
@export var jumpscare_flash := 0.45          ## then the screen goes red for this long
@export var jumpscare_linger := 2.0          ## then the red fades to dark over this long
@export var caught_color := Color(0.25, 0.0, 0.0)   ## the flash when one gets you
@export var caught_fade_time := 1.2          ## seconds from that flash to black
@export_subgroup("If everyone is caught")
@export var wipe_out_loses_rings := true     ## back at the rest area with 0 rings
@export var wipe_out_loses_items := true     ## and no items or their upgrades
@export var wipe_out_delay := 2.5            ## seconds before you're sent back
@export_group("Bracken")
@export var bracken_neck_snap := true        ## it gets you by snapping your neck
@export var bracken_snap_sound: AudioStream = preload("res://Sounds/Salvage/crack_neck.mp3")
@export var bracken_hiss_sounds: Array[AudioStream] = [preload("res://Sounds/Salvage/bracken_hiss_1.wav"), preload("res://Sounds/Salvage/bracken_hiss_2.wav")]   ## when you catch it looking at you, and when it turns on you
@export var bracken_angry_sound: AudioStream = preload("res://Sounds/Salvage/bracken_angry.wav")   ## while it's coming for you
@export var bracken_snap_crack_at := 0.37    ## seconds into the sound when the crack is
@export var bracken_snap_black := 1.3        ## seconds from it grabbing you to black
@export var bracken_from_behind := true      ## it only ever turns up behind you
@export var bracken_behind_cells := 2        ## how many corridors behind
@export var bracken_anger_time := 3.0        ## seconds of being stared at
@export var bracken_angry_time := 7.0        ## how long a charge lasts
@export var bracken_stalk_speed := 3.0       ## creeping speed
@export var bracken_charge_speed := 7.4      ## charging speed
@export var bracken_flee_speed := 5.5        ## how fast it backs off when you look at it
@export var bracken_corner_distance := 2.2   ## get this close while it's backing off and it charges
@export var bracken_cool_rate := 0.25        ## how fast its anger wears off while nobody looks
@export var bracken_carry_time := 8.0        ## seconds it drags someone off for before hunting again
@export var bracken_drags_to_den := true     ## drags whoever it kills back to its den
@export var bracken_drag_speed := 3.3        ## how fast it drags a body
@export var bracken_echo_steps := true       ## while it stalks you, you hear its footsteps behind you, in step with yours
@export var bracken_echo_range := 16.0       ## ...this close
@export var bracken_hush_time := 1.0         ## before it charges, every sound but your footsteps cuts out this long
@export var bracken_lamp_range := 8.0        ## lamps this close to it fade out, the nearest first
@export var bracken_bold_max := 5            ## each time it's caught looking it gets bolder, up to this many times
@export_range(0.0, 0.2) var bracken_bold_step := 0.12   ## ...needing this much less staring to set off each time
@export var bracken_height := 1.75           ## metres
@export var bracken_texture: Texture2D       ## its picture
@export_group("Slender Man")
@export var slender_fill_time := 4.0         ## seconds of looking at him
@export var slender_teleport_every := 7.0    ## roughly how often he jumps closer while nobody's looking
@export var slender_start_cells := 6         ## how many corridor cells away he starts closing in from
@export var slender_vanish_time := 12.0      ## how long he's gone after taking someone
@export var slender_clear_rate := 0.12       ## how fast the static clears when you look away
@export var slender_near_range := 3.0        ## this close, the static builds even if you're not looking
@export var slender_near_rate := 0.3         ## how fast it builds then, right beside him
@export_range(0.0, 1.0) var slender_static_strength := 1.0   ## how thick the static looks
@export var slender_alone := true            ## when he's on the floor, he's the only hunter
@export var slender_anger_per_item := 0.2    ## every item picked up makes him this much angrier
@export var slender_height := 2.6            ## metres
@export var slender_texture: Texture2D       ## his picture
@export var slender_model: PackedScene       ## a 3D model to use instead of his picture
@export var slender_static_death := true     ## he gets you like in Slender
@export var slender_face: Texture2D = preload("res://Sprites/Salvage/slender_jumpscare.png")   ## the face in the static
@export var slender_death_sound: AudioStream = preload("res://Sounds/Salvage/slender_death.wav")
@export var slender_static_sound: AudioStream = preload("res://Sounds/Salvage/slender_static.wav")   ## the hiss while his static builds on your screen
@export var slender_death_fall := 0.9        ## seconds of falling to the floor as the static comes in
@export var slender_death_thick := 0.6       ## then thick static over everything
@export var slender_death_black := 0.4       ## then black
@export var slender_death_flicker := 1.8     ## then his face, flickering in and out of the static
@export_group("Freddy")
@export var freddy_walk_speed := 7.2         ## in the light
@export var freddy_dark_speed := 8.5         ## in the dark
@export var freddy_dark_level := 0.2         ## less lamp light than this and he's in the dark, where he moves faster
@export var freddy_rest_time := 4.0          ## how long he stands still after catching someone
@export var freddy_height := 1.9             ## metres
@export var freddy_stomp := 0.5              ## each heavy step shakes your camera this hard right next to him
@export var freddy_stomp_range := 45.0       ## felt this far away
@export_range(0.0, 1.0) var freddy_stomp_far := 0.2   ## share of it still felt at the far edge
@export var freddy_stride := 2.2             ## metres between his steps
@export var freddy_step_sounds: Array[AudioStream] = [preload("res://Sounds/Salvage/freddy_stomp_1.wav"), preload("res://Sounds/Salvage/freddy_stomp_2.wav"), preload("res://Sounds/Salvage/freddy_stomp_3.wav")]   ## his stomps, one picked each step
@export var freddy_step_pitch := 1.0         ## lower = heavier
@export_range(0.0, 1.0) var freddy_step_volume := 1.0   ## right next to him
@export var freddy_music_box: AudioStream = preload("res://Sounds/Salvage/freddy_music_box.mp3")   ## his tune: it plays from him while he's out, and cuts off when you look at him
@export_range(0.0, 2.0) var freddy_music_box_volume := 1.0
@export_range(0.0, 0.5) var freddy_jumpscare_aim := 0.14  ## his jumpscare shows this much further down him
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var freddy_jumpscare_sound := "res://Sounds/Salvage/freddy_scream.mp3"   ## his scream when he gets you
@export var freddy_texture: Texture2D        ## his picture
@export_group("Tails Doll")
## It haunts one player, and only they can see it
@export var tails_doll_appear_every := Vector2(7.0, 15.0)   ## seconds between showings
@export var tails_doll_show_for := 14.0      ## how long it stays if you don't look at it
@export var tails_doll_look_time := 2.5      ## seconds of looking at it before it vanishes
@export var tails_doll_vanish_distance := 3.0   ## walk this close and it vanishes
@export var tails_doll_chase_speed := 5.4    ## coming for you
@export var tails_doll_chase_time := 9.0     ## how long it keeps after you before giving up
@export_range(0.0, 1.0) var tails_doll_chase_chance := 0.15   ## chance a showing is a chase
@export var tails_doll_sightings := 3        ## times you have to actually see it before it can come for you
@export var tails_doll_sightings_after := 1  ## and again after each time it gives up chasing
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var tails_doll_laugh_sound := "res://Sounds/Obstacles/2011X/exelaugh.MP3"   ## heard (only by the haunted player) when it comes for them
@export var tails_doll_hover := 0.2          ## how high it floats
@export var tails_doll_touch_distance := 0.9 ## how close it has to get to catch you
@export var tails_doll_front_only := true    ## it can only catch you from the front, and only if you've seen it coming
@export var tails_doll_hallucinations := true   ## while it haunts you, you see other hunters fly straight at you now and then
@export var tails_doll_hallucinate_every := Vector2(8.0, 16.0)   ## seconds between them
@export var tails_doll_hallucination_speed := 8.0   ## how fast they fly at you
@export var tails_doll_height := 0.95        ## metres (about as tall as Sonic and the others)
@export var tails_doll_texture: Texture2D    ## its picture
@export_range(0.0, 0.6) var tails_doll_jumpscare_aim := 0.22   ## its jumpscare shows this much further down it
@export var tails_doll_jumpscare: Texture2D   ## when it gets you
@export var tails_doll_jumpscare_cut := 0.3  ## the jumpscare sound is cut off after this many seconds
@export var tails_doll_jumpscare_hold := 2.6   ## how long the picture stays up
@export_range(0.0, 1.0) var tails_doll_jumpscare_quiet := 0.03   ## everything else drops to this while it's up
@export_group("ROOM")
## It just comes for you, in stop-motion skips
@export var room_speed := 3.6                ## coming for you, on average
@export var room_skip_every := 0.3           ## seconds it holds still between skips
@export var room_lunge_range := 8.0          ## this close, and you can see it, it rushes you
@export var room_lunge_speed := 10.0         ## rushing you
@export_range(0.0, 0.3) var room_twitch := 0.05   ## how much it shakes on the spot
@export var room_smear := true               ## leaves a fading copy of itself behind each skip
@export var room_rest_time := 4.0            ## how long it stands still after catching someone
@export var room_static_range := 16.0        ## the static starts this close
@export_range(0.0, 1.0) var room_static_strength := 0.9   ## how thick the static gets right next to it
@export var room_theme: AudioStream = preload("res://Sounds/Salvage/room_theme.ogg")   ## plays from it the whole time it's out
@export_range(0.0, 2.0) var room_theme_volume := 1.0
@export var room_hear_distance := 30.0       ## further than this and you can't hear its theme
@export var room_height := 2.1               ## metres
@export var room_texture: Texture2D          ## its picture
@export var room_jumpscare: Texture2D = preload("res://Sprites/Salvage/room_jumpscare.png")   ## when it gets you
@export var room_jumpscare_hold := 3.0       ## how long its face stays up
@export var room_scare_frames := "res://Sprites/Salvage/RoomScare"   ## when it gets you
@export var room_scare_fps := 15.0
@export_file("*.ogg", "*.wav", "*.mp3") var room_scare_sound := "res://Sounds/Salvage/room_scare.ogg"   ## the video's sound with it
@export_group("Spider")
## Waits in a pit
@export var spider_emerge_range := 5.0       ## this close to its pit and it may climb out
@export_range(0.0, 1.0) var spider_emerge_chance := 0.6   ## ...this likely, each pit, once
@export var spider_crawl_speed := 4.0        ## scuttling off along the wall
@export var spider_return_after := Vector2(20.0, 40.0)   ## seconds before it's back
@export var spider_roam_speed := 2.2         ## wandering, listening
@export var spider_rush_speed := 14.0        ## when it hears you
@export var spider_hear_range := 16.0        ## how far it hears you moving
@export var spider_quiet_speed := 0.8        ## slower than this
@export var spider_drag_speed := 4.5         ## dragging you back to its pit
@export_range(0.0, 1.0) var spider_drop_chance := 0.12   ## chance a second it drops you on the way
@export var spider_listen_time := 6.0        ## after dropping you it stays and listens this long
@export var spider_size := 3.2               ## metres across, legs and all
@export_range(0.2, 1.0) var spider_body := 0.65   ## how long its body is, as a share of that
@export var spider_texture: Texture2D        ## its body, seen from above, head at the top, no legs
@export_group("Mimic")
## Looks just like one of you, walking about like a player
@export var mimic_walk_speed := 3.0          ## wandering, and strolling over to you
@export var mimic_lunge_speed := 6.5         ## close up, it lunges
@export var mimic_lunge_range := 5.0         ## this close (and it can see you), it lunges
@export var mimic_spot_range := 18.0         ## how far it can spot you
@export var mimic_lose_time := 4.0           ## out of its sight this long and it loses you
@export var mimic_rest_time := 4.0           ## how long it stands still after catching someone
@export var mimic_string_range := 6.0        ## its strings show this close
@export var mimic_stare_time := 2.0          ## when it spots you, it stares at you this long before walking over
@export var mimic_spreads := true            ## whoever it catches becomes a Mimic too
@export var mimic_rise_after := 2.5          ## seconds before their body gets up as a Mimic
@export_group("Clone")
## Not a hunter itself
@export var clone_count := 6                 ## how many copies stand there
@export var clone_spread := 2                ## the room and this many corridors on from it get some of them
@export_group("MX")
## Starts out as harmless NES Mario, wandering
@export var mx_transform_after := 60.0       ## seconds after it turns up that it stops being Mario
@export var mx_mario_speed := 1.8            ## wandering as Mario
@export var mx_roam_speed := 2.6             ## wandering as MX
@export var mx_chase_speed := 4.0            ## after you
@export var mx_spot_range := 22.0            ## how far it can spot you
@export var mx_spot_angle := 70.0            ## how wide it looks
@export var mx_lose_time := 3.0              ## out of its sight this long and it loses you
@export var mx_voicelines: Array[AudioStream] = [preload("res://Sounds/Salvage/MX/mx_1.ogg"), preload("res://Sounds/Salvage/MX/mx_3.ogg"), preload("res://Sounds/Salvage/MX/mx_4.ogg"), preload("res://Sounds/Salvage/MX/mx_6.ogg"), preload("res://Sounds/Salvage/MX/mx_7.ogg")]   ## one is said when it spots you
@export var mx_voice_time := 1.0             ## how long it speaks
@export var mx_transform_sound: AudioStream = preload("res://Sounds/Salvage/MX/mx_9.ogg")   ## when it stops being Mario
@export var mx_rest_time := 4.0              ## how long it stands still after catching someone
@export var mx_stomp := 0.6                  ## each step shakes your camera this hard right next to it
@export var mx_stomp_range := 40.0           ## felt this far away
@export var mx_stride := 2.6                 ## metres between its steps
@export var mx_step_pitch := 0.8             ## its stomps
@export_range(0.0, 1.0) var mx_step_volume := 1.0
@export var mx_height := 2.6                 ## metres, as MX
@export var mx_mario_height := 1.1           ## metres, as Mario
@export var mx_texture: Texture2D = preload("res://Sprites/Salvage/Hunters/MX/mx.png")
@export var mx_chase_texture: Texture2D = preload("res://Sprites/Salvage/Hunters/MX/mx_chase.png")   ## while after you
@export var mx_mario_frames: Array[Texture2D] = [preload("res://Sprites/Salvage/Hunters/MX/mario_0.png"), preload("res://Sprites/Salvage/Hunters/MX/mario_1.png"), preload("res://Sprites/Salvage/Hunters/MX/mario_2.png"), preload("res://Sprites/Salvage/Hunters/MX/mario_3.png")]   ## standing, then the walk
@export_group("Top-Down")
@export var force_top_down := false          ## always top-down here
@export var top_down_height := 13.0          ## how high above you the camera hangs
@export var top_down_fov := 76.0             ## how much of the floor fits on screen
@export_range(30.0, 360.0) var top_down_cone := 100.0   ## how wide you can see, in front of you
@export var top_down_reach := 10.0           ## how far you can see
@export var top_down_glow := 10.0            ## your own light reaches this far
@export var top_down_brightness := 1.1       ## how bright that light is
@export var top_down_dark := Color(0, 0, 0, 1)   ## what covers everything you can't see
@export var top_down_soft_edge := 1.6        ## metres over which your sight fades into the dark, instead of a hard line
@export var top_down_soft_sides := 22.0      ## degrees past the sides of the cone that it fades out over
@export_range(0.0, 0.3) var top_down_waver := 0.05   ## how much the edge of your sight breathes and wavers
@export var top_down_sharpness := 2.5        ## top-down is drawn this many times finer than first person
@export var top_down_pickup_scale := 1.8     ## rings and items drawn this much bigger from above
@export var top_down_mine_light := 2.5       ## a mine's blinking light drawn this much bigger from above
@export var top_down_character_scale := 1.7  ## characters drawn this much bigger from above
@export var top_down_hunter_scale := 1.4     ## hunters too
@export_range(0.0, 1.0) var top_down_hunter_brightness := 0.75   ## the darkest a hunter gets from above
@export_group("Look")
@export var render_size := Vector2i(400, 225)   ## size each view is drawn at before it's scaled up
@export_subgroup("PS1 Filter")
## A PlayStation look
@export var ps1_filter := true
@export var ps1_resolution := Vector2i(320, 180)   ## the size it's drawn at
@export var ps1_colour_levels := 32.0              ## shades per colour channel
@export var ps1_wobble := 110.0                    ## vertex grid: lower = more wobble as you move
@export_range(0.0, 1.0) var ps1_warp := 0.45       ## texture warping on every surface
@export var ps1_close_calm := 6.0                  ## nearer than this
@export var web_max_steps := 2   ## in a browser: physics steps a slow frame may run to catch up

var rng := RandomNumberGenerator.new()
var maze_size := Vector2i(20, 20)   # this visit's size, from the floor you're on
var maze_lo := Vector2i.ZERO        # its first cell
var size_scale := 1.0               # this visit's area / the biggest area
var item_list: Array = []       # [name, cost, effect, shape, colour, texture, height, amount] for each kind
var hazards := {}                # Vector2i -> the hazard chunk placed there
var mine_nodes: Array = []
var ragdoll_cards: Array = []
var fog_zones: Array = []        # {cell, center, thick
var smoke: Array = []            # what blasts leave behind
var _smoke_was := false
var _grown := false              # rings and items are at their top-down size
var world_env: Environment    # flung bodies' sprites, lit like everything else
var skip_floors := 0             # floors to skip on the way back
var players: Array = []          # local players
var player: CharacterBody3D      # 1P (used by the follower sprites)
var fade: ColorRect
var mats := {}
var lamps: Array[Vector3] = []
var lamp_states := {}      # lamp index -> LAMP_DEAD / LAMP_STUTTER / LAMP_ON
var lamp_mats := {}        # lamp index -> [its fixture's material, its halo's material]
var lamp_power := PackedFloat32Array()   # every lamp's brightness this frame
var sign_labels: Array = []   # [Label3D, its colour]
var doors: Array[Node3D] = []
var exit_cell := Vector2i.ZERO
var exit_car: Node3D              # the exit elevator
var exit_doors: Array[Node3D] = []
var departing := false            # ESCAPE was pressed
var item_nodes: Array[Node3D] = []
var ring_sfx: AudioStreamPlayer
var ring_nodes: Array[Sprite3D] = []
var leaving := false
var time := 0.0
var followers: Array = []        # AI teammates following 1P
var partner_sprites := {}        # local player index -> its sprite
var hazard_scale := 1.0           # more mines, spikes and pits
var miku_list: Array = []         # {"sprite", "body", "leader"
var level := {}     # Vector2i -> the cell's floor height
var stair := {}     # Vector2i -> direction its stairs climb toward
var tree_links := {}   # Vector2i -> the cells the maze's paths join it to
var maze_body: StaticBody3D   # collision for the maze pieces made in code
var lamp_spots: Array[Vector3] = []   # where ceiling lamps can hang
var _batches := {}  # "material|chunk" -> SurfaceTool
var _batch_mats := {}   # the same keys -> the material to draw that mesh with
var walls_h := {}   # Vector2i -> true
var walls_v := {}   # Vector2i -> true
var touch: Control               # salvage_touch.gd, on touch screens
var top_down := false            # motion sickness mode
var bracken: Sprite3D            # bracken.gd, if it's one of this visit's hunters
var monsters: Array = []         # this visit's hunters
var watchers := {}               # who the hunters can see or be seen by
var _all_out := false
var _knocked := {}               # player -> seconds left before they can get up
var _shadows := {}               # character node -> its shadow on the floor


var _steps_before := 8


func _enter_tree() -> void:
	# In a browser a slow frame makes Godot run up to 8 physics steps to catch up
	_steps_before = Engine.max_physics_steps_per_frame
	if OS.has_feature("web"):
		Engine.max_physics_steps_per_frame = web_max_steps


func _exit_tree() -> void:
	Engine.max_physics_steps_per_frame = _steps_before
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("alarm_light", Vector3.ZERO)


func _ready() -> void:
	top_down = force_top_down or Test.salvage_top_down
	rng.randomize()
	Pause.current_scene = "Salvage"
	_size_for_floor()
	if Test.salvage_danger:
		_make_dangerous()
	var pads := _setup_input()
	for k in item_kinds:
		if k and k.effect == SalvageItem.Effect.SKIP_FLOORS and not SalvageItem.can_skip(Test.level):
			continue
		if k:
			item_list.append([k.display_name, k.cost, k.effect, k.shape, k.color, k.texture, k.height, k.amount, k.says(), k])
	if item_list.is_empty():
		item_list.append(["Item", 5, SalvageItem.Effect.RINGS, "square", Color(0.6, 0.6, 0.6), null, 0.5, 10])
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	env.environment = e
	add_child(env)
	world_env = e
	_build_materials()
	_apply_scary_look()
	var dread := preload("res://Scenes/Salvage/salvage_dread.gd").new()
	dread.name = "Dread"
	add_child(dread)
	dread.setup(self)
	_build_elevator_level()
	_build_maze()
	_place_lamps()
	_place_items()
	_place_exit()
	_place_mikus()
	_place_rings()
	_place_mines()
	_place_crushers()
	_place_narrows()
	_place_tables()
	_place_grates()
	_place_mirrors()
	_place_fog()
	_send_fog_to_shader()
	_build_players(pads)
	_build_others()
	_build_hunters()
	if top_down:
		_pickups_grow(true)
	for m in get_tree().get_nodes_in_group("salvage_mirror"):
		m.setup(self, players)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Test.mobile or top_down else Input.MOUSE_MODE_CAPTURED
	_set_view_lighting()
	_hide_ceilings_from_above()
	get_tree().node_added.connect(func(n):
		if top_down:
			_face_up.call_deferred(n))
	if top_down:
		_face_up(self)
	# Fade in, then the doors open
	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, 1.2)
	get_tree().create_timer(doors_open_after).timeout.connect(_open_doors)


# Small on the early floors, growing steadily to its biggest by full_size_floor
func _size_for_floor() -> void:
	var f: int = Test.level
	var t := clampf(float(f - small_until_floor) / maxf(full_size_floor - small_until_floor, 1), 0.0, 1.0)
	maze_size = Vector2i(roundi(lerpf(min_maze_size.x, max_maze_size.x, t)), roundi(lerpf(min_maze_size.y, max_maze_size.y, t)))
	maze_size = maze_size.clamp(Vector2i(3, 3), Vector2i(64, 64))
	size_scale = float(maze_size.x * maze_size.y) / maxf(max_maze_size.x * max_maze_size.y, 1)
	# With three ways out, you land in the middle of the near edge instead of a corner
	maze_lo = Vector2i(-(maze_size.x / 2), 0) if start_paths >= 3 else Vector2i.ZERO
	# The higher you go, the less time before
	var k := clampf(float(f - hunters_from_floor) / maxf(hunter_waits_shortest_at - hunters_from_floor, 1), 0.0, 1.0)
	var waits := lerpf(1.0, hunter_waits_shrink_to, k)
	first_hunter_after *= waits
	next_hunter_after *= waits
	hunter_settle_time *= waits


# From the Rewrite tree
func _make_dangerous() -> void:
	hazard_scale = danger_hazards
	dead_lamps = minf(dead_lamps + danger_dead_lamps, 0.9)
	first_hunter_after *= danger_hunters_sooner
	next_hunter_after *= danger_hunters_sooner


func _scaled(full: int, least: int) -> int:
	return maxi(roundi(full * size_scale), mini(least, full))


# Input Keys changed in the pause menu
func apply_saved_keys() -> void:
	for a in Test.SALVAGE_KEY_ACTIONS:
		var saved: InputEvent = Test.salvage_key(a)
		if saved == null or not InputMap.has_action("sv_" + a):
			continue
		for e in InputMap.action_get_events("sv_" + a):
			if e.get_class() == saved.get_class():
				InputMap.action_erase_event("sv_" + a, e)
		InputMap.action_add_event("sv_" + a, saved)


# Back to the default keys
func reset_keys() -> void:
	Test.clear_salvage_keys()
	_setup_input()


# 1P: keyboard + mouse
func _setup_input() -> Array:
	var pads: Array = Input.get_connected_joypads()
	var p1_pad: int = pads[0] if pads.size() >= 1 else -1
	var keys := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT], "interact": [KEY_E], "sprint": [KEY_SHIFT], "jump": [KEY_SPACE],
		"crouch": [KEY_CTRL, KEY_C], "map": [KEY_M, KEY_TAB], "trick": [KEY_F], "stun": [KEY_Q],
	}
	# Controller: sprint is the left trigger
	var buttons := {"interact": [JOY_BUTTON_X], "jump": [JOY_BUTTON_A], "trick": [JOY_BUTTON_B], "stun": [JOY_BUTTON_Y],
		"crouch": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_RIGHT_STICK], "map": [JOY_BUTTON_BACK]}
	var triggers := {"sprint": JOY_AXIS_TRIGGER_LEFT}
	for a in keys:
		var action: String = "sv_" + a
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
	for a in keys:
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("sv_" + a, ev)
	if not Test.mobile:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("sv_interact", click)
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("sv_trick", right)
	apply_saved_keys()
	for a in buttons:
		for b in buttons[a]:
			if p1_pad >= 0:
				var j1 := InputEventJoypadButton.new()
				j1.button_index = b
				j1.device = p1_pad
				InputMap.action_add_event("sv_" + a, j1)
	for a in triggers:
		if p1_pad >= 0:
			var t := InputEventJoypadMotion.new()
			t.axis = triggers[a]
			t.axis_value = 1.0
			t.device = p1_pad
			InputMap.action_add_event("sv_" + a, t)
			InputMap.action_set_deadzone("sv_" + a, 0.3)
	return [p1_pad, -1]


# Mouse look is read before the screen's controls see the mouse
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if players.is_empty():
			return
		if is_instance_valid(players[0].knocked) or players[0].dead:
			players[0].orbit_mouse(event.relative)
		elif not players[0].escaped and not players[0].busy():
			players[0].look_mouse(event.relative)


# The lighting follows the camera
func _set_view_lighting() -> void:
	for m in mats.values():
		if not m is ShaderMaterial:
			continue
		if not m.has_meta("fp"):
			m.set_meta("fp", [m.get_shader_parameter("flash_strength"), m.get_shader_parameter("player_light"), m.get_shader_parameter("player_glow")])
		var fp: Array = m.get_meta("fp")
		m.set_shader_parameter("view_drop", top_down_height - 1.3 if top_down else 0.0)
		m.set_shader_parameter("flash_strength", 0.0 if top_down else (fp[0] if fp[0] != null else 1.0))
		m.set_shader_parameter("player_light", top_down_glow if top_down else (fp[1] if fp[1] != null else 3.2))
		m.set_shader_parameter("player_glow", top_down_brightness if top_down else (fp[2] if fp[2] != null else 0.15))


# Ceilings and roofs go on their own layer
func _hide_ceilings_from_above() -> void:
	var overhead := []   # ceilings, the lamps hanging off them, and their halos
	for key in mats:
		if key == "ceiling" or key.begins_with("lamp") or key.begins_with("halo"):
			overhead.append(mats[key])
	for mi in find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if mi.material_override in overhead or n.contains("ceiling") or n.contains("roof"):
			mi.layers = CEILING_LAYER


# From above, upright DOOM-style sprites would be edge-on
func _face_up(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is SpriteBase3D and n.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		n.set_meta("upright", [n.billboard, n.no_depth_test, n.offset, n.render_priority, n.alpha_cut])
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.no_depth_test = true   # lying flat it would sink into the floor
		n.offset = Vector2.ZERO  # centred on where it stands, not sticking out past it
		n.render_priority = 1
		n.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # drawn after the shadows
	for c in n.get_children():
		_face_up(c)


# How finely a player's view is drawn
func _view_size(p) -> void:
	var res: Vector2i = p.get_meta("eye_res")
	if top_down:
		res = Vector2i(Vector2(res) * top_down_sharpness)
	p.view.size = res
	var post: SubViewport = p.get_meta("post")
	post.size = res
	var look := post.get_child(0) as TextureRect
	look.size = Vector2(res)
	(look.material as ShaderMaterial).set_shader_parameter("low_res", Vector2(res))


# Back from above
func _stand_up(n: Node) -> void:
	if n is SpriteBase3D and n.has_meta("upright"):
		var was: Array = n.get_meta("upright")
		n.billboard = was[0]
		n.no_depth_test = was[1]
		n.offset = was[2]
		n.render_priority = was[3]
		n.alpha_cut = was[4]
		n.remove_meta("upright")
	for c in n.get_children():
		_stand_up(c)


# Pause > Settings > Salvage Top-Down, changed while you're down here
func set_top_down(on: bool) -> void:
	on = on or force_top_down
	if on == top_down or players.is_empty():
		return
	top_down = on
	_set_view_lighting()
	for i in players.size():
		var p = players[i]
		_view_size(p)
		var own: int = 1 << (1 + i)
		if on:
			_add_vision(p, p.screen.get_parent())
			p.use_top_down(top_down_height, top_down_fov)
			p.cam.cull_mask = (p.cam.cull_mask | own) & ~CEILING_LAYER
		else:
			if is_instance_valid(p.vision):
				p.vision.queue_free()
			p.vision = null
			p.use_first_person()
			p.cam.cull_mask = (p.cam.cull_mask & ~own) | CEILING_LAYER
			if is_instance_valid(p.knocked) or (p.dead and is_instance_valid(p.ragdoll)):
				p.cam.cull_mask |= own   # still watching your own body
	# Alone, you only have a sprite of your own from above
	if players.size() == 1:
		if on and not partner_sprites.has(0):
			var spr = _make_sprite(players[0].character, 1 << 1)
			if spr:
				partner_sprites[0] = spr
		elif not on and partner_sprites.has(0):
			partner_sprites[0].queue_free()
			partner_sprites.erase(0)
	# Bigger and always lit from above, back to normal from the eyes
	var grow := top_down_character_scale if on else 1.0 / top_down_character_scale
	var people: Array = followers + partner_sprites.values() + miku_list.map(func(mk): return mk.sprite)
	for spr in people:
		if is_instance_valid(spr) and not (on and spr == partner_sprites.get(0) and players.size() == 1):
			spr.pixel_size *= grow
			spr.min_light = 1.0 if on else character_brightness
	for mon in monsters:
		var scale: float = top_down_character_scale if mon is TAILS_DOLL else top_down_hunter_scale
		mon.pixel_size *= scale if on else 1.0 / scale
		if on:
			mon.set_meta("min_shade", mon.min_shade)
			mon.min_shade = top_down_hunter_brightness
		elif mon.has_meta("min_shade"):
			mon.min_shade = mon.get_meta("min_shade")
	_pickups_grow(on)
	if on:
		_face_up(self)
	else:
		_stand_up(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Test.mobile or on else Input.MOUSE_MODE_CAPTURED


# Rings, items and mines' lights bigger from above
func _pickups_grow(on: bool) -> void:
	if on == _grown:
		return
	_grown = on
	var by := top_down_pickup_scale if on else 1.0 / top_down_pickup_scale
	for r in ring_nodes:
		if is_instance_valid(r):
			r.pixel_size *= by
	for it in item_nodes:
		if is_instance_valid(it) and it.has_node("Sprite"):
			var spr: Sprite3D = it.get_node("Sprite")
			spr.pixel_size *= by
			spr.position.y *= by
	var light := top_down_mine_light if on else 1.0 / top_down_mine_light
	for m in mine_nodes:
		if is_instance_valid(m) and m.has_node("Light"):
			m.get_node("Light").scale *= light


func _add_vision(p, area: Control) -> void:
	var vision := VISION.new()
	p.vision = vision
	vision.cone = top_down_cone
	vision.reach = top_down_reach
	vision.color = top_down_dark
	vision.soft_edge = top_down_soft_edge
	vision.soft_sides = top_down_soft_sides
	vision.waver = top_down_waver
	area.add_child(vision)
	area.move_child(vision, p.screen.get_index() + 1)   # just over the view, under the HUD
	vision.setup(self, p)


# The pause menu is open
func menu_open() -> bool:
	return Pause.visible


func _unhandled_input(event: InputEvent) -> void:
	if Test.mobile or top_down or menu_open():
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


# A surface material
func _mat(key: String, pattern: int, a: Color, b := Color.BLACK, tile := 1.0) -> ShaderMaterial:
	var path := MATERIALS_DIR + key + ".tres"
	if ResourceLoader.exists(path):
		mats[key] = load(path)
		_ps1_material(mats[key], pattern)
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("level_height", 3.6)
	# A touch of PS1 texture warp on the elevator
	m.set_shader_parameter("affine_amount", 0.0 if pattern in [0, 1, 2, 6] else 0.3)
	_ps1_material(m, pattern)
	mats[key] = m
	return m


# The PS1 filter
func ps1_on() -> bool:
	return ps1_filter and (Test.display == null or Test.display.salvage_ps1)


# A surface's wobble and warp
func _ps1_material(m: Material, pattern: int) -> void:
	if not (m is ShaderMaterial):
		return
	var on := ps1_on()
	m.set_shader_parameter("snap_res", ps1_wobble if on else 160.0)
	m.set_shader_parameter("affine_amount", ps1_warp if on else (0.0 if pattern in [0, 1, 2, 6] else 0.3))
	m.set_shader_parameter("close_calm", ps1_close_calm)


func _build_materials() -> void:
	# Plain white and black checks
	_mat("floor", 0, Color.WHITE, Color.BLACK, 1.4)
	_mat("wall", 1, Color.WHITE, Color.BLACK, 1.4)
	_mat("ceiling", 2, Color.WHITE, Color.BLACK, 1.4)
	_mat("metal", 3, Color(0.26, 0.27, 0.28))
	_mat("door", 3, Color(0.26, 0.2, 0.36))
	_mat("hazard", 6, Color(0.85, 0.7, 0.1), Color(0.05, 0.05, 0.05))
	_mat("lamp", 5, Color(1.0, 0.92, 0.75))
	_mat("exit", 5, Color(0.62, 0.05, 0.04))
	_mat("red", 5, Color(1.0, 0.15, 0.1))
	_mat("grate", 7, Color(0.36, 0.2, 0.12), Color(0.004, 0.003, 0.003))
	# The elevator: purple walls with magenta bands, like the reference picture
	_mat("elev_wall", 4, Color(0.3, 0.2, 0.46))
	_mat("elev_band", 4, Color(0.62, 0.14, 0.52))
	_mat("elev_rail", 4, Color(0.07, 0.04, 0.11))
	_mat("elev_floor", 4, Color(0.2, 0.12, 0.34))
	_mat("elev_lamp", 5, Color(1.0, 0.45, 0.47))
	_mat("elev_panel", 4, Color(0.62, 0.63, 0.72))
	_mat("elev_screen", 5, Color(0.72, 0.76, 0.82))
	_mat("elev_button", 4, Color(0.42, 0.5, 0.78))
	_mat("board", 4, Color(0.34, 0.27, 0.19))
	_mat("paint", 4, Color(0.7, 0.06, 0.04))
	_mat("stairs", 3, Color(0.62, 0.07, 0.05))
	_mat("door_frame", 3, Color(0.17, 0.18, 0.2))
	# The grime band along the bottom of the walls repeats every floor height
	mats["wall"].set_shader_parameter("level_height", level_step)


# Building blocks A box from min corner to max corner, with collision
func _box(a: Vector3, b: Vector3, mat_key: String, solid := true, parent: Node3D = self) -> Node3D:
	var size := (b - a).abs()
	var center := (a + b) * 0.5
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	# Extra subdivisions so the vertex wobble and warping read on big faces, PS1 style
	bm.subdivide_width = int(clamp(size.x / 2.0, 0, 8))
	bm.subdivide_depth = int(clamp(size.z / 2.0, 0, 8))
	bm.subdivide_height = int(clamp(size.y / 2.0, 0, 4))
	mesh.mesh = bm
	mesh.material_override = mats[mat_key]
	if not solid:
		mesh.position = center
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


# A soft glowing halo around a light
func _halo(at: Vector3, size: float, color: Color, strength := 0.55) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("glow_color", color)
	m.set_shader_parameter("strength", strength)
	mats["halo_%d" % mats.size()] = m
	q.material_override = m
	q.position = at
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


# A cell's centre, at its floor
func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * cell_size, _floor_y(c) + (level_step * 0.5 if stair.has(c) else 0.0), c.y * cell_size)


func _floor_y(c: Vector2i) -> float:
	return level.get(c, 0) * level_step


func _ceil_y(c: Vector2i) -> float:
	return (level.get(c, 0) + (1 if stair.has(c) else 0)) * level_step + wall_height


# The floor height where a cell meets its neighbour in direction d
func _side_level(c: Vector2i, d: Vector2i) -> int:
	var l: int = level.get(c, 0)
	if stair.has(c) and stair[c] == d:
		return l + 1
	return l


# The elevator and the landing with the hole
func _build_elevator_level() -> void:
	var area := START_AREA.instantiate()
	add_child(area)
	_register_props(area)
	_dress_deck(area)
	_build_signs()
	_build_tv()
	for d in area.find_children("*", "", true, false):
		if d.is_in_group("elevator_door"):
			doors.append(d)
	var floor_node := area.get_node_or_null("ElevFloor") as Node3D
	if floor_node:
		_elevator_music(area, floor_node.position + Vector3(0, 2.0, 0))


# The deck above the maze looks nothing like the maze
@export_group("Deck")
@export var deck_look := false               ## the pool hall / terrace, city and train up top
@export_enum("Pool Hall", "Glass Terrace") var deck_style := 0   ## a vaulted hall with glowing pools, or a glass-roofed terrace
@export var deck_city_art := true            ## the city from your 2D layers
@export var city_train := true              ## your 2D train, running round the city on its track
@export var train_speed := 24.0              ## m/s (minus for the other way)
@export var city_extra_rings := 3           ## more rings of buildings in among the layers
@export var city_layer_size := 0.35         ## how big the city's pictures look
@export var deck_towers := 110               ## towers in the city around it
@export var deck_seed := 7                   ## the same city every visit

const DECK_DIR := "res://Shaders/Deck/"
var _deck_outside: Node3D                    # the city, the water and the sky


func _dress_deck(area: Node3D) -> void:
	if not deck_look:
		return
	var floor_mat := _deck_mat("deck_floor")
	var glass_mat := _deck_mat("deck_glass")   # the walls: at the hall's ends you look out at the city
	var chrome_mat := _deck_mat("deck_chrome")
	var tube_mat := _deck_mat("deck_tube")
	for n in area.get_children():
		var nm := String(n.name)
		if nm.begins_with("Floor"):
			for m in n.find_children("*", "MeshInstance3D", true, false):
				m.material_override = floor_mat
		elif nm.begins_with("BackWall") or nm.begins_with("SideWall") or nm == "FrontWall":
			for m in n.find_children("*", "MeshInstance3D", true, false):
				m.material_override = glass_mat
		elif nm.begins_with("Hazard") or nm.begins_with("LightPole") or nm.begins_with("LightHead") or nm == "Cable":
			n.visible = false
			for c in n.find_children("*", "CollisionShape3D", true, false):
				c.disabled = true
	var deck := Node3D.new()
	deck.name = "Deck"
	add_child(deck)
	if deck_style == 0:
		for n in area.get_children():
			if String(n.name).begins_with("Floor"):
				for m in n.find_children("*", "MeshInstance3D", true, false):
					m.material_override = _deck_mat("deck_tiles")
			elif String(n.name).begins_with("SideWall"):
				for m in n.find_children("*", "MeshInstance3D", true, false):
					m.visible = false
		_build_pool_hall(deck, chrome_mat)
	else:
		_build_terrace(deck, glass_mat, chrome_mat, tube_mat)
	_build_hole_rail(deck, chrome_mat)
	_build_outside(deck)


# A glass roof with chrome beams across it, and rows of green tubes under it
func _build_terrace(deck: Node3D, glass_mat: Material, chrome_mat: Material, tube_mat: Material) -> void:
	_deck_box(deck, Vector3(32.2, 0.05, 39.4), Vector3(0, UP_Y + 6.0, 6.4), glass_mat)
	var z := -13.0
	while z <= 26.0:
		_deck_box(deck, Vector3(32.2, 0.18, 0.14), Vector3(0, UP_Y + 5.9, z), chrome_mat)
		z += 4.0
	# Fluorescent tubes hanging in rows
	for x in [-8.0, 0.0, 8.0]:
		z = -12.4
		while z < 25.0:
			_deck_box(deck, Vector3(0.11, 0.11, 2.3), Vector3(x, UP_Y + 5.45, z + 1.15), tube_mat)
			_deck_box(deck, Vector3(0.03, 0.4, 0.03), Vector3(x, UP_Y + 5.7, z + 0.3), chrome_mat)
			_deck_box(deck, Vector3(0.03, 0.4, 0.03), Vector3(x, UP_Y + 5.7, z + 2.0), chrome_mat)
			z += 3.1


# Chrome railing round the hole, open on the elevator side
func _build_hole_rail(deck: Node3D, chrome_mat: Material) -> void:
	var r := 1.65
	for corner in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r), Vector2(0, r), Vector2(-r, 0), Vector2(r, 0)]:
		_deck_box(deck, Vector3(0.07, 1.05, 0.07), Vector3(corner.x, UP_Y + 0.52, corner.y), chrome_mat, true)
	for h in [0.55, 1.02]:
		_deck_box(deck, Vector3(2.0 * r + 0.07, 0.06, 0.06), Vector3(0, UP_Y + h, r), chrome_mat, true)
		_deck_box(deck, Vector3(0.06, 0.06, 2.0 * r + 0.07), Vector3(-r, UP_Y + h, 0), chrome_mat, true)
		_deck_box(deck, Vector3(0.06, 0.06, 2.0 * r + 0.07), Vector3(r, UP_Y + h, 0), chrome_mat, true)


# A tall vaulted hall
func _build_pool_hall(deck: Node3D, chrome_mat: Material) -> void:
	var arch := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 16.05
	cyl.bottom_radius = 16.05
	cyl.height = 39.4
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 48
	arch.mesh = cyl
	var arch_mat := _deck_mat("deck_arch")
	arch_mat.set_shader_parameter("floor_y", UP_Y - 0.05)
	arch.material_override = arch_mat
	arch.rotation.x = PI * 0.5   # lying along the hall
	arch.position = Vector3(0, UP_Y, 6.4)
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck.add_child(arch)
	var pool_mat := _deck_mat("deck_pool")
	var globe_mat := _deck_mat("deck_globe")
	for side in [-1.0, 1.0]:
		var x: float = side * 10.0
		_deck_box(deck, Vector3(7.0, 0.02, 30.0), Vector3(x, UP_Y + 0.02, 7.0), pool_mat)
		# Its rim
		_deck_box(deck, Vector3(7.3, 0.1, 0.15), Vector3(x, UP_Y + 0.05, -8.0), chrome_mat)
		_deck_box(deck, Vector3(7.3, 0.1, 0.15), Vector3(x, UP_Y + 0.05, 22.0), chrome_mat)
		_deck_box(deck, Vector3(0.15, 0.1, 30.3), Vector3(x - 3.6, UP_Y + 0.05, 7.0), chrome_mat)
		_deck_box(deck, Vector3(0.15, 0.1, 30.3), Vector3(x + 3.6, UP_Y + 0.05, 7.0), chrome_mat)
		# Ladders
		for lz in [-2.0, 14.0]:
			for dz in [-0.25, 0.25]:
				_deck_box(deck, Vector3(0.05, 0.9, 0.05), Vector3(x - side * 3.45, UP_Y + 0.45, lz + dz), chrome_mat)
				_deck_box(deck, Vector3(0.35, 0.05, 0.05), Vector3(x - side * 3.3, UP_Y + 0.9, lz + dz), chrome_mat)
		# Lamps on posts, between the pool and the walk
		var z := -10.0
		while z <= 22.0:
			_deck_box(deck, Vector3(0.08, 2.6, 0.08), Vector3(side * 5.6, UP_Y + 1.3, z), chrome_mat, true)
			var globe := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.22
			ball.height = 0.44
			globe.mesh = ball
			globe.material_override = globe_mat
			globe.position = Vector3(side * 5.6, UP_Y + 2.75, z)
			deck.add_child(globe)
			var lamp := Marker3D.new()
			lamp.add_to_group("salvage_light")
			lamp.position = Vector3(side * 5.6, UP_Y + 2.6, z)
			deck.add_child(lamp)
			z += 6.0
		# Benches facing the water
		for bz in [5.0, 11.0, 17.0]:
			var bx: float = side * 4.9
			_deck_box(deck, Vector3(0.45, 0.06, 1.7), Vector3(bx, UP_Y + 0.45, bz), chrome_mat, true)
			_deck_box(deck, Vector3(0.06, 0.45, 1.7), Vector3(bx - side * 0.22, UP_Y + 0.72, bz), chrome_mat)
			for lz in [-0.75, 0.75]:
				_deck_box(deck, Vector3(0.05, 0.45, 0.05), Vector3(bx, UP_Y + 0.22, bz + lz), chrome_mat)
	_register_props(deck)


# Outside: the sky, the water, the city
func _build_outside(deck: Node3D) -> void:
	_deck_outside = Node3D.new()
	_deck_outside.name = "Outside"
	deck.add_child(_deck_outside)
	var sky := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 420.0
	sphere.height = 840.0
	sky.mesh = sphere
	sky.material_override = _deck_mat("deck_sky")
	sky.position = Vector3(0, UP_Y, 6.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deck_outside.add_child(sky)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(840, 840)
	water.mesh = plane
	water.material_override = _deck_mat("deck_water")
	water.position = Vector3(0, UP_Y - 14.0, 6.0)
	_deck_outside.add_child(water)
	if deck_city_art:
		_build_city_layers()
		return
	var city_mat := _deck_mat("deck_city")
	var rr := RandomNumberGenerator.new()
	rr.seed = deck_seed
	var placed := 0
	var tries := 0
	while placed < deck_towers and tries < deck_towers * 20:
		tries += 1
		var at := Vector3(rr.randf_range(-260, 260), 0, rr.randf_range(-250, 270))
		var dist := Vector2(at.x, at.z - 6.0).length()
		if dist < 75.0 or dist > 300.0:
			continue
		var w := rr.randf_range(10.0, 28.0)
		var top := rr.randf_range(4.0, 22.0) + dist * rr.randf_range(0.08, 0.32)
		var height := top + 14.0
		_deck_box(_deck_outside, Vector3(w, height, rr.randf_range(8.0, 22.0)), Vector3(at.x, UP_Y - 14.0 + height * 0.5, at.z), city_mat)
		placed += 1


# Back to front
const CITY_LAYERS := [
	["2-backround", 300.0, false], ["3-backround", 262.0, false],
	["5-backround", 225.0, false], ["4backround-traffic-lights", 223.0, true],
	["7-backround", 192.0, false], ["4b-backround--traffic-lights", 190.0, true],
	["8-backround", 165.0, false], ["9-middleground-tower", 142.0, false],
	["10-middleground-lights-tower", 140.0, true], ["12-middleground", 122.0, false],
	["11-middleground", 108.0, false],
]


# Clouds: your night cloud banks behind the city
const CLOUD_LAYERS := [
	["Night/9", 400.0, 0.5, 0.0, 0.0], ["Night/7", 385.0, 0.45, 0.0, 0.0],
	["Night/6", 370.0, 0.42, 0.0, 0.0], ["Night/5", 355.0, 0.38, 0.0, 0.0],
]


func _build_city_layers() -> void:
	for c in CLOUD_LAYERS:
		var path := "res://Sprites/Background/%s.png" % c[0]
		if not ResourceLoader.exists(path):
			continue
		var r: float = c[1]
		var reps := maxf(roundf(PI / float(c[2])), 2.0)
		var height := PI * r / reps
		var m := _deck_mat("deck_layer")
		m.set_shader_parameter("art", load(path))
		m.set_shader_parameter("repeats", reps)
		m.set_shader_parameter("drift", c[4])
		var loose: bool = c[3] > 0.0
		m.set_shader_parameter("tint", Color(0.3, 0.38, 0.55) if loose else Color(0.85, 0.9, 1.05))
		m.set_shader_parameter("haze_amount", 0.35 if loose else 0.15)
		_deck_ring(r, height, UP_Y - 14.0 + c[3], m)
	var far := 300.0
	var rr := RandomNumberGenerator.new()
	rr.seed = deck_seed
	var rings: Array = []   # [picture, how far, lit up, how big, turned]
	for layer in CITY_LAYERS:
		rings.append([layer[0], layer[1], layer[2], city_layer_size, 0.0])
		# More of the same buildings in among them
		if layer[2] or String(layer[0]).begins_with("11"):
			continue
		for k in city_extra_rings:
			rings.append([layer[0], float(layer[1]) * (1.0 - 0.055 * (k + 1)), false, city_layer_size * rr.randf_range(0.8, 1.35), rr.randf()])
	rings.sort_custom(func(a, b): return a[1] > b[1])
	if city_train:
		_build_train()
	for ring in rings:
		var path := "res://Sprites/Background/City/%s.png" % ring[0]
		if not ResourceLoader.exists(path):
			continue
		var r: float = ring[1]
		# The same size to the eye whatever the distance
		var reps := maxf(roundf(PI / float(ring[3])), 2.0)
		var height := PI * r / reps
		var m := _deck_mat("deck_layer")
		m.set_shader_parameter("art", load(path))
		m.set_shader_parameter("repeats", reps)
		m.set_shader_parameter("turn", ring[4])
		m.set_shader_parameter("lights", ring[2])
		# Night: darker and bluer, and the further off the more it fades into the haze
		var depth := inverse_lerp(100.0, far, r)
		m.set_shader_parameter("tint", Color.WHITE if ring[2] else Color(0.42, 0.5, 0.72).lerp(Color(0.6, 0.7, 0.92), depth))
		m.set_shader_parameter("haze_amount", lerpf(0.0, 0.4, depth))
		_deck_ring(r, height, UP_Y - 14.0, m)


# Your train, going round and round in front of the city on a raised track
const TRAIN_ART := "res://Sprites/Background/City/6-backround-train.png"
const TRAIN_RADIUS := 90.0         # in front of the buildings
const TRAIN_TRACK_Y := 3.5        # a raised line, a little above the deck
func _build_train() -> void:
	if not ResourceLoader.exists(TRAIN_ART):
		return
	var art: Texture2D = load(TRAIN_ART)
	var img := art.get_image()
	# Where the train sits in its picture
	var bottom := img.get_height()
	for y in range(img.get_height() - 1, -1, -1):
		var any := false
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				any = true
				break
		if any:
			bottom = y + 1
			break
	var reps := 2.0   # two trains, either side of the city
	var height := PI * TRAIN_RADIUS / reps * float(img.get_height()) / (float(img.get_width()) * 0.5)
	var below := height * (1.0 - float(bottom) / float(img.get_height()))
	var m := _deck_mat("deck_layer")
	m.set_shader_parameter("art", art)
	m.set_shader_parameter("repeats", reps)
	m.set_shader_parameter("lights", true)
	m.set_shader_parameter("tint", Color(1.0, 1.05, 0.95))
	m.set_shader_parameter("bright", 1.9)
	m.set_shader_parameter("drift", train_speed / (TAU * TRAIN_RADIUS))
	_deck_ring(TRAIN_RADIUS, height, UP_Y + TRAIN_TRACK_Y - below, m)
	# Its track
	var rail := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = TRAIN_RADIUS + 0.3
	band.bottom_radius = TRAIN_RADIUS + 0.3
	band.height = 0.6
	band.cap_top = false
	band.cap_bottom = false
	band.radial_segments = 128
	rail.mesh = band
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.albedo_color = Color(0.05, 0.07, 0.12)
	rail.material_override = dark
	rail.position = Vector3(0, UP_Y + TRAIN_TRACK_Y - 0.3, 6.0)
	_deck_outside.add_child(rail)


# One picture wrapped round the hall
func _deck_ring(r: float, height: float, base_y: float, m: Material) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = height
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 96
	ring.mesh = cyl
	if m is ShaderMaterial:
		m.set_shader_parameter("ring_h", height)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, base_y + height * 0.5, 6.0)
	_deck_outside.add_child(ring)


func _deck_mat(file: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(DECK_DIR + file + ".gdshader")
	return m


func _deck_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid := false) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.add_child(mi)
		parent.add_child(body)
		body.position = at
	else:
		parent.add_child(mi)
		mi.position = at


# The city's only drawn while someone's up on the deck, and you can see that far
func _update_deck() -> void:
	var up := false
	for p in players:
		var on_deck: bool = p.global_position.y > UP_Y - 4.0
		up = up or on_deck
		if is_instance_valid(_deck_outside) and not p.top_down:
			p.cam.far = 480.0 if on_deck else 60.0
	if is_instance_valid(_deck_outside):
		_deck_outside.visible = up
	_update_tv(up)


# A Space Channel 5 broadcast on an old TV up on the deck, past the hole
@export_group("Space Channel 5 TV")
@export var tv_on := true
@export var tv_spot := Vector3(0.0, 0.0, 24.0)  ## where it stands
@export var tv_songs: Array[RhythmSong] = [preload("res://Sounds/Salvage/TV Songs/Space Channel 5 Mix/space_channel_5_mix.tres")]   ## what it plays, one after another
@export var tv_volume_db := 10.0              ## dB louder than the music setting
# Elevator music
@export var elevator_music: AudioStream = preload("res://Sounds/Salvage/Elevator/have_fun.mp3")   ## loops (empty = none)
@export var elevator_music_db := -6.0               ## how loud, close up
@export var elevator_music_full_within := 3.0       ## metres: as loud as it gets this close, fading after
@export var elevator_music_hear_within := 22.0      ## metres: silent beyond this
@export var tv_full_volume_within := 4.0       ## metres: as loud as it gets this close, fading after
@export var tv_hear_within := 30.0             ## metres: silent beyond this
@export var tv_clip: Texture2D = preload("res://Sprites/Salvage/space_channel_5_tv.png")   ## what's on: frames side by side, row by row
@export var tv_clip_columns := 9
@export var tv_clip_rows := 3
@export var tv_clip_frames := 27
@export var tv_clip_fps := 16.67
@export var tv_ticker := "SPACE CHANNEL 5  -  LIVE FROM THE DECK  -  NOW PLAYING: %s  -  "   ## scrolls along the bottom of the screen
@export var tv_game := true                    ## the rhythm game you can play in front of it
@export var tv_play_within := 6.0              ## metres from the screen you can start it from
@export var tv_reward_grades: PackedStringArray = ["S", "A"]   ## finishing the song with one of these grades drops a free item
@export_file("*.wav", "*.mp3", "*.MP3", "*.ogg") var tv_reward_sound := "res://Sounds/Obstacles/Rings/ringsfx.MP3"   ## played when it drops

var _tv_music: AudioStreamPlayer3D
var _tv_picture: ShaderMaterial
var _tv_ticker: Label3D
const TV_TICKER_WIDTH := 22   # letters showing at once


func _build_tv() -> void:
	if not tv_on:
		return
	var root := Node3D.new()
	root.name = "SpaceChannel5TV"
	add_child(root)
	_tv_root = root
	root.global_position = tv_spot + Vector3(0, UP_Y, 0)
	root.look_at(Vector3(tv_spot.x, UP_Y, -13.5), Vector3.UP, true)   # the screen faces the elevator
	root.rotation.x = 0.0
	root.rotation.z = 0.0
	var shell := _mat("tv_shell", 3, Color(0.92, 0.92, 0.94))        # glossy white, like the show's sets
	var trim := _mat("tv_trim", 3, Color(1.0, 0.5, 0.08))            # orange
	var blue := _mat("tv_blue", 3, Color(0.15, 0.35, 0.95))
	var chrome := _mat("tv_chrome", 3, Color(0.7, 0.72, 0.76))
	var dark := _mat("tv_dark", 3, Color(0.05, 0.05, 0.08))
	# A round space-age set on a stem
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.95
	sm.height = 1.9
	ball.mesh = sm
	ball.material_override = shell
	ball.position = Vector3(0, 1.75, 0)
	root.add_child(ball)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.93
	bm.outer_radius = 0.99
	band.mesh = bm
	band.material_override = blue
	band.position = Vector3(0, 1.75, 0)
	band.rotation.x = PI * 0.5   # round its edge as you face it, clear of the screen
	root.add_child(band)
	var visor := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 0.7
	vm.bottom_radius = 0.7
	vm.height = 0.3
	visor.mesh = vm
	visor.material_override = dark
	visor.rotation.x = PI * 0.5
	visor.position = Vector3(0, 1.75, 0.78)
	root.add_child(visor)
	var ring := MeshInstance3D.new()
	var rm2 := TorusMesh.new()
	rm2.inner_radius = 0.66
	rm2.outer_radius = 0.78
	ring.mesh = rm2
	ring.material_override = trim
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0, 1.75, 0.94)
	root.add_child(ring)
	var stem := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = 0.09
	stm.bottom_radius = 0.12
	stm.height = 0.9
	stem.mesh = stm
	stem.material_override = chrome
	stem.position = Vector3(0, 0.5, 0)
	root.add_child(stem)
	var base := MeshInstance3D.new()
	var basem := CylinderMesh.new()
	basem.top_radius = 0.45
	basem.bottom_radius = 0.6
	basem.height = 0.12
	base.mesh = basem
	base.material_override = trim
	base.position = Vector3(0, 0.06, 0)
	root.add_child(base)
	var rod := MeshInstance3D.new()
	var rodm := CylinderMesh.new()
	rodm.top_radius = 0.015
	rodm.bottom_radius = 0.025
	rodm.height = 0.7
	rod.mesh = rodm
	rod.material_override = chrome
	rod.position = Vector3(0, 2.95, 0)   # straight up out of the top
	root.add_child(rod)
	var tip := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.07
	tm.height = 0.14
	tip.mesh = tm
	tip.material_override = trim
	tip.position = rod.position + Vector3(0, 0.35, 0)
	root.add_child(tip)
	# You can't walk through it
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.95
	shape.height = 2.7
	col.shape = shape
	col.position = Vector3(0, 1.35, 0)
	body.add_child(col)
	root.add_child(body)
	# The picture: your clip, playing on a loop
	_tv_picture = ShaderMaterial.new()
	_tv_picture.shader = load(DECK_DIR + "deck_tv.gdshader")
	_tv_picture.set_shader_parameter("clip", tv_clip)
	_tv_picture.set_shader_parameter("cols", maxi(tv_clip_columns, 1))
	_tv_picture.set_shader_parameter("rows", maxi(tv_clip_rows, 1))
	if tv_clip:
		# Fill the round screen
		var cell := Vector2(tv_clip.get_width() / float(maxi(tv_clip_columns, 1)), tv_clip.get_height() / float(maxi(tv_clip_rows, 1)))
		_tv_picture.set_shader_parameter("crop_x", clampf(cell.y / maxf(cell.x, 1.0), 0.1, 1.0))
	# The song's name scrolling along a dark bar across the bottom of the glass
	if tv_ticker != "":
		var bar := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(1.0, 0.13, 0.01)
		bar.mesh = bm2
		bar.material_override = dark
		bar.position = Vector3(0, 1.75 - 0.4, 0.975)
		root.add_child(bar)
		_tv_ticker = Label3D.new()
		_tv_ticker.font = load("res://Fonts/diest64.ttf")
		_tv_ticker.font_size = 32
		_tv_ticker.pixel_size = 0.0023
		_tv_ticker.outline_size = 0
		_tv_ticker.modulate = Color(1, 1, 1)
		_tv_ticker.shaded = false
		_tv_ticker.double_sided = false
		_tv_ticker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_tv_ticker.position = Vector3(0, 1.75 - 0.4, 0.983)
		root.add_child(_tv_ticker)
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.34, 1.34)
	glass.mesh = q
	glass.material_override = _tv_picture
	glass.position = Vector3(0, 1.75, 0.965)   # just in front of the ball
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	# Its glow lights up whoever's watching
	var glow := Marker3D.new()
	glow.add_to_group("salvage_light")
	glow.position = Vector3(0, 1.6, 1.6)
	root.add_child(glow)
	_register_props(root)
	# The songs, coming out of the set, one after another
	if not tv_songs.is_empty():
		_tv_music = AudioStreamPlayer3D.new()
		_tv_music.name = "TVSong"
		_tv_music.bus = "Music"
		_tv_music.volume_db = _tv_db()
		_tv_music.unit_size = tv_full_volume_within
		_tv_music.max_distance = tv_hear_within
		_tv_music.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_tv_music.attenuation_filter_cutoff_hz = 20500.0
		_tv_music.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_tv_music.position = Vector3(0, 1.75, 0.6)
		root.add_child(_tv_music)
		_tv_index = -1
		_tv_next()


var _tv_index := 0


func _elevator_music(parent: Node3D, at: Vector3) -> void:
	if elevator_music == null:
		return
	var m := AudioStreamPlayer3D.new()
	m.name = "ElevatorMusic"
	var stream := elevator_music.duplicate()
	if "loop" in stream:
		stream.loop = true
	m.stream = stream
	m.bus = "Music"
	m.volume_db = elevator_music_db
	m.unit_size = elevator_music_full_within
	m.max_distance = elevator_music_hear_within
	m.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	m.attenuation_filter_cutoff_hz = 20500.0
	m.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	m.autoplay = true
	m.position = at
	parent.add_child(m)


# The song that's on
func tv_song() -> RhythmSong:
	if tv_songs.is_empty():
		return null
	return tv_songs[clampi(_tv_index, 0, tv_songs.size() - 1)]


# On to the next song in the list
var _tv_last_pos := 0.0

func _tv_next() -> void:
	if tv_songs.is_empty() or _tv_music == null:
		return
	_tv_index = (_tv_index + 1) % tv_songs.size()
	var song := tv_song()
	if song == null or song.music() == null:
		return
	var music := song.music()
	if "loop" in music:
		music.set("loop", true)
	_tv_last_pos = 0.0
	if _tv_music.stream != music:
		_tv_music.stream = music
	_tv_music.play()


var _tv_root: Node3D
var _tv_game_ended := -10.0
var _tv_rewarded := false       # one free item per visit


# A free item for a good grade
func _tv_reward(p: Node3D) -> void:
	if item_list.is_empty() or _tv_root == null or _tv_rewarded:
		return
	_tv_rewarded = true
	var kind: Array = item_list[randi() % item_list.size()]
	var from := _tv_root.global_transform * Vector3(0, 0.3, 0.7)
	var to := p.global_position + (-p.global_transform.basis.z) * 1.8 + p.global_transform.basis.x * 0.9
	to.y = UP_Y
	var id := "tv%d_%d" % [p.index, _drops]
	_drops += 1
	_spawn_drop(kind, from, to, id)
	if ResourceLoader.exists(tv_reward_sound):
		p.sfx.stream = load(tv_reward_sound)
		p.sfx.play()


# Down in the maze
func below_deck(p: Node3D) -> bool:
	return p.global_position.y < UP_Y - 4.0


# Standing in front of the TV, facing it, close enough to play
func near_tv(p: Node3D) -> bool:
	if not tv_game or _tv_root == null or _tv_music == null or tv_song() == null or tv_song().notes().times.is_empty():
		return false
	var front := _tv_root.global_transform * Vector3(0, 0, 0.6)
	var to := front - p.global_position
	to.y = 0.0
	if to.length() > tv_play_within or absf(p.global_position.y - UP_Y) > 2.0:
		return false
	var facing := -p.global_transform.basis.z
	return to.length() < 1.6 or facing.dot(to.normalized()) > 0.25


func start_rhythm(p: Node3D) -> void:
	if p.rhythm != null or Time.get_ticks_msec() / 1000.0 - _tv_game_ended < 0.6:
		return
	var g := preload("res://Scenes/Salvage/salvage_rhythm.gd").new()
	g.name = "Rhythm"
	var chart := tv_song().notes()
	g.setup(p, _tv_music, chart, chart.bpm if chart.bpm > 0.0 else 120.0, chart.first_beat)
	p.rhythm = g
	p.prompt.text = ""
	# Face the screen
	var to := _tv_root.global_position - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = 0.08
	p.hud.add_child(g)
	g.graded.connect(func(grade: String) -> void:
		if grade in tv_reward_grades:
			_tv_reward(p))
	g.finished.connect(func() -> void:
		p.rhythm = null
		_tv_game_ended = Time.get_ticks_msec() / 1000.0
		if not _tv_music.playing:
			_tv_music.play())


# As loud as the music setting allows
func _tv_db() -> float:
	if not Test.music:
		return -80.0
	return minf(MusicManager.volume + tv_volume_db, 6.0)


# The clip plays while someone's up here
func _update_tv(up: bool) -> void:
	if _tv_picture == null:
		return
	if _tv_music:

		if _tv_music.stream_paused != (not up):
			_tv_music.stream_paused = not up
		var db := _tv_db()
		if absf(_tv_music.volume_db - db) > 0.05:
			_tv_music.volume_db = db
	if not up:
		return
	if tv_songs.size() > 1 and _tv_music and _tv_music.playing:
		var pos := _tv_music.get_playback_position()
		if pos + 1.0 < _tv_last_pos:
			_tv_next()
		else:
			_tv_last_pos = pos
	if tv_clip and tv_clip_frames > 0:
		var n := mini(tv_clip_frames, maxi(tv_clip_columns, 1) * maxi(tv_clip_rows, 1))
		var at := Time.get_ticks_msec() / 1000.0 * tv_clip_fps
		var song := tv_song()
		if _tv_music and _tv_music.playing and song and song.clip_beats > 0.0 and song.notes().bpm > 0.0:
			# Dancing in time with the song
			var chart := song.notes()
			var beat := maxf(_tv_music.get_playback_position() - chart.first_beat, 0.0) * chart.bpm / 60.0
			at = beat / song.clip_beats * n
		_tv_picture.set_shader_parameter("frame", int(at) % n)
	if _tv_ticker:
		# A marquee: the letters step along, a window of them at a time
		var text := tv_ticker.replace("%s", tv_song().shown_title() if tv_song() else "")
		var start := int(Time.get_ticks_msec() / 1000.0 * 7.0) % maxi(text.length(), 1)
		var shown := (text + text).substr(start, TV_TICKER_WIDTH)
		if _tv_ticker.text != shown:
			_tv_ticker.text = shown


# Signs up here, before the drop
@export_group("Signs")
@export var signs_on := true
@export var sign_spots: Array[Vector3] = [Vector3(2.9, 0.0, -9.0)]   ## where the controls sign stands


func _build_signs() -> void:
	if not signs_on:
		return
	var pages := [_sign_controls()]
	var paper := _mat("sign_board", 0, Color(0.5, 0.47, 0.4), Color(0.5, 0.47, 0.4))   # a pale board, lit by the lamps like the rest
	for i in mini(pages.size(), sign_spots.size()):
		var at: Vector3 = sign_spots[i] + Vector3(0, UP_Y, 0)
		var root := Node3D.new()
		root.name = "Sign%d" % (i + 1)
		add_child(root)
		root.global_position = at
		root.look_at(Vector3(0, UP_Y, -13.5), Vector3.UP, true)   # face the elevator
		root.rotation.x = 0.0
		root.rotation.z = 0.0
		var board := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 2.2, 0.06)
		board.mesh = box
		board.material_override = paper
		board.position = Vector3(0, 1.55, 0)
		root.add_child(board)
		for side in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.07, 0.5, 0.07)
			post.mesh = pm
			post.material_override = SIGN_BOARD
			post.position = Vector3(side * 1.1, 0.25, 0.02)
			root.add_child(post)
		var title := Label3D.new()
		title.text = pages[i][0]
		title.font_size = 64
		title.pixel_size = 0.0045
		title.outline_size = 0
		title.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		title.position = Vector3(0, 2.42, 0.035)
		title.set_meta("paint", Color(0.8, 0.08, 0.05))
		root.add_child(title)
		var body := Label3D.new()
		body.text = pages[i][1]
		body.font_size = 40
		body.pixel_size = 0.0031
		body.outline_size = 0
		body.line_spacing = 4.0
		body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body.width = 2.35 / body.pixel_size   # wraps inside the board
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.position = Vector3(0, 2.2, 0.035)
		body.set_meta("paint", Color(0.06, 0.05, 0.05))
		root.add_child(body)
		var lamp := Marker3D.new()
		lamp.add_to_group("salvage_light")
		lamp.position = Vector3(0, 2.9, 0.9)
		root.add_child(lamp)
		_register_props(root)
		# Walk up to it and press use to read it close up
		var read := StaticBody3D.new()
		read.collision_layer = 2   # only the use ray hits it
		read.collision_mask = 0
		read.set_meta("sign", pages[i])
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.6, 2.2, 0.1)
		col.shape = shape
		read.add_child(col)
		read.position = board.position
		root.add_child(read)


const TOP_DOWN_TIP := "Feeling sick? Turn on Salvage Top-Down in the settings."


func _sign_controls() -> Array:
	if Test.mobile:
		return ["CONTROLS", "\n".join(["Move: Left side", "Look: Right side", "", TOP_DOWN_TIP])]
	var rows := [
		["Move", _keys_for(["forward", "left", "back", "right"])],
		["Look", "Mouse"],
		["Run", _keys_for(["sprint"])],
		["Jump", _keys_for(["jump"])],
		["Crouch", _keys_for(["crouch"])],
		["Use", _keys_for(["interact"])],
		["Trick", _keys_for(["trick"])],
		["Map", _keys_for(["map"])],
	]
	var lines: Array[String] = []
	for r in rows:
		lines.append("%s: %s" % [r[0], r[1]])
	lines.append("")
	lines.append(TOP_DOWN_TIP)
	return ["CONTROLS", "\n".join(lines)]


# The keys for these actions, as they're set right now
func _keys_for(actions: Array) -> String:
	var names: Array[String] = []
	for a in actions:
		var action: String = "sv_" + a
		if not InputMap.has_action(action):
			continue
		var mine: Array[String] = []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var k: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
				mine.append(OS.get_keycode_string(k))
			elif e is InputEventMouseButton:
				mine.append("Left click" if e.button_index == MOUSE_BUTTON_LEFT else ("Right click" if e.button_index == MOUSE_BUTTON_RIGHT else "Mouse %d" % e.button_index))
		if actions.size() > 1:
			names.append(mine[0] if not mine.is_empty() else "?")   # movement: one key each
		else:
			names.append_array(mine.slice(0, 2))
	return (" " if actions.size() > 1 else " / ").join(names)


# Pick up what a placed scene brings
func _register_props(root: Node) -> void:
	for n in root.find_children("*", "", true, false):
		if n is Marker3D and n.is_in_group("salvage_light"):
			lamps.append(n.global_position)
		elif n is Label3D and n.has_meta("paint"):
			sign_labels.append([n, n.get_meta("paint")])


func _open_doors() -> void:
	for d in doors:
		var t := create_tween()
		t.tween_property(d, "position:x", d.get_meta("open_x"), 1.4).set_trans(Tween.TRANS_SINE)


# The maze
func _build_maze() -> void:
	# Recursive backtracker
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			walls_h[Vector2i(x, z)] = true
			walls_v[Vector2i(x, z)] = true
			tree_links[Vector2i(x, z)] = []
	var seen := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	# Every way out of the landing is a corridor
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if in_maze(d) and not seen.has(d):
			_open(Vector2i.ZERO, d)
			tree_links[Vector2i.ZERO].append(d)
			tree_links[d].append(Vector2i.ZERO)
			seen[d] = true
			stack.append(d)
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options := []
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if in_maze(n) and not seen.has(n):
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_open(c, d)
		tree_links[c].append(c + d)
		tree_links[c + d].append(c)
		seen[c + d] = true
		stack.append(c + d)
	# Knock out a few more walls so there are loops, like the facility halls
	for x in range(maze_lo.x, maze_lo.x + maze_size.x - 1):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			if rng.randf() < extra_openings:
				walls_h[Vector2i(x, z)] = false
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y - 1):
			if rng.randf() < extra_openings:
				walls_v[Vector2i(x, z)] = false
	_assign_levels()
	_build_from_chunks()


# Floor heights
func _assign_levels() -> void:
	level[Vector2i.ZERO] = 0
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var top := floor_levels - 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in tree_links[c]:
			if level.has(n):
				continue
			var d: Vector2i = n - c
			var e := _side_level(c, d)
			var links: Array = tree_links[n]
			var straight: bool = links.size() == 2 and links.has(n + d)
			var near_start: bool = maxi(absi(n.x), absi(n.y)) <= 1
			if top > 0 and straight and not near_start and rng.randf() < stairs:
				var up := e < top and (e == 0 or rng.randf() < 0.5)
				if up:
					level[n] = e
					stair[n] = d
				else:
					level[n] = e - 1
					stair[n] = -d
			else:
				level[n] = e
			queue.append(n)
	# Wall up openings that don't line up
	for c in level:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if not level.has(n) or _wall_between(c, n):
				continue
			var bad := _side_level(c, d) != _side_level(n, -d)
			bad = bad or (stair.has(c) and stair[c].x * d.x + stair[c].y * d.y == 0)   # its side
			bad = bad or (stair.has(n) and stair[n].x * d.x + stair[n].y * d.y == 0)
			if bad:
				if d.x == 1: walls_h[c] = true
				else: walls_v[c] = true


func _wall_between(c: Vector2i, n: Vector2i) -> bool:
	var d := n - c
	if d == Vector2i(1, 0): return walls_h.get(c, true)
	if d == Vector2i(-1, 0): return walls_h.get(n, true)
	if d == Vector2i(0, 1): return walls_v.get(c, true)
	return walls_v.get(n, true)


# Build the maze out of chunks, then merge their meshes per material
func _build_from_chunks() -> void:
	_pick_hazards()
	maze_body = StaticBody3D.new()
	maze_body.name = "MazeCollision"
	add_child(maze_body)
	# What each chunk offers
	var kinds := []   # [scene, openings, stairs, weight]
	for sc in chunks:
		if sc == null:
			continue
		var probe := sc.instantiate()
		if probe is SalvageChunk:
			kinds.append([sc, probe.openings(), probe.stairs, probe.weight])
		probe.free()
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			var need: Array[Vector2i] = []
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var n: Vector2i = c + d
				if level.has(n) and not _wall_between(c, n):
					need.append(d)
			# Chunks that fit, and the turn each needs
			var fits := []
			var total := 0.0
			if hazards.has(c):
				var probe: SalvageChunk = hazards[c].instantiate()
				for turn in 4:
					if _fits(probe.openings(), turn, need, false, Vector2i.ZERO):
						fits.append([hazards[c], turn, 1.0])
						total = 1.0
						break
				probe.free()
			for k in (kinds if fits.is_empty() else []):
				if k[2] != stair.has(c):
					continue
				for turn in 4:
					if _fits(k[1], turn, need, k[2], stair.get(c, Vector2i.ZERO)):
						fits.append([k[0], turn, k[3]])
						total += k[3]
						break
			var chunk: Node3D
			var turn := 0
			if fits.is_empty():
				# None fits: a plain one made to measure
				var B = load("res://Scenes/Salvage/Chunks/chunk_builder.gd")
				if stair.has(c):
					chunk = B.build(true, true, false, false, true)
					turn = _turn_to(Vector2i(0, 1), stair[c])
				else:
					chunk = B.build(need.has(Vector2i(0, -1)), need.has(Vector2i(0, 1)), need.has(Vector2i(1, 0)), need.has(Vector2i(-1, 0)))
			else:
				var pick := rng.randf() * total
				var chosen = fits[0]
				for f in fits:
					pick -= f[2]
					if pick <= 0.0:
						chosen = f
						break
				chunk = (chosen[0] as PackedScene).instantiate()
				turn = chosen[1]
			_widen(chunk, cell_size / CHUNK_CELL)
			chunk.position = Vector3(x * cell_size, _floor_y(c), z * cell_size)
			chunk.rotation.y = turn * PI / 2.0
			add_child(chunk)
			if c == Vector2i.ZERO:
				_cut_hole(chunk)
			for a in chunk.find_children("*", "Area3D", true, false):
				if a.is_in_group("salvage_spikes"):
					a.body_entered.connect(_on_spikes.bind(a))
				elif a.is_in_group("salvage_pit"):
					a.body_entered.connect(_on_pit)
			_absorb_chunk(chunk, c)
	_flush_batches()


# Foggy areas: a few spots in the maze filled with thick fog
func _place_fog() -> void:
	if Test.level < fog_from_floor:
		return
	var cells: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			if absi(c.x) + absi(c.y) > 3 and c != exit_cell and not stair.has(c) and _neighbours(c).size() < 4:
				cells.append(c)
	for i in mini(_scaled(fog_areas, 1), 8):
		var free := cells.filter(func(c): return fog_zones.all(func(z): return Vector2(c - z.cell).length() > fog_radius * 2.0 / cell_size))
		if free.is_empty():
			break
		var c: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var zone := {"cell": c, "center": _cell_center(c), "thick": 1.0, "clearing": false}
		zone.latch = _make_latch(c, fog_zones.size())
		fog_zones.append(zone)


# A latch on a wall of this cell
func _make_latch(c: Vector2i, index: int) -> StaticBody3D:
	var open := _neighbours(c)
	var side := Vector2i(0, 1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not open.has(c + d):
			side = d
			break
	var out := Vector3(side.x, 0, side.y)
	var body := StaticBody3D.new()
	body.collision_layer = 2   # only the interact ray
	body.collision_mask = 0
	body.set_meta("latch", index)
	add_child(body)
	body.global_position = _cell_center(c) + out * (cell_size * 0.5 - 0.22) + Vector3(0, 1.3, 0)
	body.rotation.y = atan2(out.x, out.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.8, 0.5)
	shape.shape = box
	body.add_child(shape)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.36, 0.56, 0.1)
	plate.mesh = pm
	plate.material_override = mats.get("metal")
	body.add_child(plate)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.07, 0.34, 0.07)
	handle.mesh = hm
	handle.material_override = mats.get("hazard")
	handle.position = Vector3(0, 0.08, -0.12)
	handle.rotation.x = 0.5
	handle.name = "Handle"
	body.add_child(handle)
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.05
	bm.height = 0.1
	bulb.mesh = bm
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1, 0.12, 0.08)
	glow.disable_fog = true   # so you can find it in the murk
	bulb.material_override = glow
	bulb.position = Vector3(0, -0.2, -0.07)
	bulb.name = "Bulb"
	body.add_child(bulb)
	return body


func latch_pulled(latch: Node3D) -> bool:
	var i: int = latch.get_meta("latch")
	return i < 0 or i >= fog_zones.size() or fog_zones[i].clearing


func pull_latch(latch: Node3D) -> void:
	var i: int = latch.get_meta("latch")
	if latch_pulled(latch):
		return
	_clear_fog(i, true)


func _clear_fog(i: int, send: bool) -> void:
	var zone: Dictionary = fog_zones[i]
	if zone.clearing:
		return
	zone.clearing = true
	var latch: Node3D = zone.latch
	var handle: Node3D = latch.get_node("Handle")
	latch.create_tween().tween_property(handle, "rotation:x", -0.5, 0.25)
	(latch.get_node("Bulb").material_override as StandardMaterial3D).albedo_color = Color(0.2, 1, 0.3)
	if ResourceLoader.exists(latch_sound):
		var snd := AudioStreamPlayer.new()
		snd.stream = load(latch_sound)
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
# How deep in fog a point is
func fog_at(p: Vector3) -> float:
	var f := 0.0
	for z in fog_zones:
		var d := Vector2(p.x - z.center.x, p.z - z.center.z).length()
		f = maxf(f, (1.0 - smoothstep(fog_radius - 1.5, fog_radius, d)) * z.thick)
	for s in smoke:
		var d := Vector2(p.x - s.center.x, p.z - s.center.z).length()
		var r := _smoke_reach(s)
		f = maxf(f, (1.0 - smoothstep(r - 1.5, r, d)) * _smoke_thick(s))
	return f


# Blast smoke: thick at first, spreading as it thins until it's gone
func _smoke_reach(s: Dictionary) -> float:
	return lerpf(blast_smoke_size.x, blast_smoke_size.y, sqrt(clampf(s.age / blast_smoke_time, 0.0, 1.0)))


func _smoke_thick(s: Dictionary) -> float:
	var left := 1.0 - clampf(s.age / blast_smoke_time, 0.0, 1.0)
	return blast_smoke * left * left


func _update_fog(delta: float) -> void:
	var changed := false
	for z in fog_zones:
		if z.clearing and z.thick > 0.0:
			z.thick = maxf(z.thick - delta / maxf(fog_clear_time, 0.01), 0.0)
			changed = true
	for s in smoke:
		s.age += delta
	if not smoke.is_empty():
		smoke = smoke.filter(func(s): return s.age < blast_smoke_time)
		changed = true
	if changed or _smoke_was:
		_send_fog_to_shader()
	_smoke_was = not smoke.is_empty()
	for p in players:
		var f := fog_at(p.cam.global_position if is_instance_valid(p.watching) else p.head.global_position)
		if top_down:
			if p.vision:
				p.vision.reach = lerpf(top_down_reach, fog_sight, f)
		elif p.fog_env:
			p.fog_env.fog_density = f * fog_density


func _send_fog_to_shader() -> void:
	var arr := PackedVector4Array()
	for z in fog_zones:
		arr.append(Vector4(z.center.x, z.center.z, fog_radius, z.thick))
	for s in smoke:
		if arr.size() < 8:
			arr.append(Vector4(s.center.x, s.center.z, _smoke_reach(s), _smoke_thick(s)))
	var count := arr.size()
	while arr.size() < 8:
		arr.append(Vector4.ZERO)
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("fog_zones", arr)
			m.set_shader_parameter("fog_zone_count", count)
			m.set_shader_parameter("fog_tint", fog_color)


# Spikes and pits go in straight corridors, away from the landing
func _pick_hazards() -> void:
	var spots: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			var ways := _neighbours(c)
			if ways.size() != 2 or ways[0] - c != c - ways[1] or stair.has(c):
				continue
			if absi(c.x) + absi(c.y) <= 2:
				continue   # not right where you land
			spots.append(c)
	var want := []
	if Test.level < hazards_from_floor:
		return
	if spike_chunk:
		for i in roundi(_scaled(spike_strips, 1) * hazard_scale):
			want.append(spike_chunk)
	if pit_chunk:
		for i in roundi(_scaled(pits, 1) * hazard_scale):
			want.append(pit_chunk)
	for scene in want:
		var free := spots.filter(func(c): return not hazards.has(c) and _neighbours(c).all(func(n): return not hazards.has(n)))
		if free.is_empty():
			break
		hazards[free[rng.randi_range(0, free.size() - 1)]] = scene


# Spiked crushers
var crusher_nodes: Array = []    # [{"node", "cell", "along", "floor", "state", "t", "snd"}]
var CRUSHER_LONG: float:        # metres along the corridor
	get: return cell_size * 0.45
var CRUSHER_WIDE: float:        # across it
	get: return cell_size * 0.85
const CRUSHER_SPIKE := 0.5       # how far the spikes stick down

func _place_crushers() -> void:
	if crushers <= 0 or Test.level < crushers_from_floor:
		return
	var taken := {}
	for it in item_nodes:
		taken[Vector2i(roundi(it.global_position.x / cell_size), roundi(it.global_position.z / cell_size))] = true
	for m in mine_nodes:
		taken[Vector2i(roundi(m.global_position.x / cell_size), roundi(m.global_position.z / cell_size))] = true
	var spots: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			var ways := _neighbours(c)
			if ways.size() != 2 or ways[0] - c != c - ways[1] or stair.has(c) or hazards.has(c) or taken.has(c):
				continue
			if absi(c.x) + absi(c.y) <= 2 or c == exit_cell:
				continue
			spots.append(c)
	for i in mini(roundi(_scaled(crushers, 1) * hazard_scale), spots.size()):
		var c: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var ways := _neighbours(c)
		var along := Vector3(ways[0].x - c.x, 0, ways[0].y - c.y).normalized()
		var at := _cell_center(c)
		at.y = _floor_at(c, at)
		var node := _crusher_mesh()
		add_child(node)
		node.global_position = at + Vector3(0, wall_height, 0)
		node.rotation.y = atan2(along.x, along.z)
		var snd := AudioStreamPlayer3D.new()
		snd.stream = crusher_slam_sound
		snd.unit_size = 6.0
		snd.max_distance = 40.0
		snd.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		node.add_child(snd)
		crusher_nodes.append({"node": node, "cell": c, "along": along, "floor": at.y, "state": "up", "t": 0.0, "snd": snd})


# A heavy block with spikes underneath
func _crusher_mesh() -> Node3D:
	var root := Node3D.new()
	var metal: Material = mats.get("metal")   # lit by the lamps like everything else
	if metal == null:
		metal = StandardMaterial3D.new()
	var block := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CRUSHER_WIDE, 0.6, CRUSHER_LONG)
	block.mesh = bm
	block.material_override = metal
	block.position = Vector3(0, -0.3, 0)
	root.add_child(block)
	var steel: Material = mats.get("metal")
	if steel == null:
		steel = StandardMaterial3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.0
	cone.height = CRUSHER_SPIKE
	cone.radial_segments = 6
	for ix in 6:
		for iz in 4:
			var sp := MeshInstance3D.new()
			sp.mesh = cone
			sp.material_override = steel
			sp.position = Vector3(lerpf(-CRUSHER_WIDE * 0.42, CRUSHER_WIDE * 0.42, ix / 5.0), -0.6 - CRUSHER_SPIKE * 0.5, lerpf(-CRUSHER_LONG * 0.4, CRUSHER_LONG * 0.4, iz / 3.0))
			root.add_child(sp)
	return root


# Waits up in the ceiling till it senses someone, a jolt, SLAM, a moment down
func _update_crushers(delta: float) -> void:
	var drop := wall_height - 0.05   # how far its top comes down
	for i in crusher_nodes.size():
		var cr: Dictionary = crusher_nodes[i]
		var node: Node3D = cr.node
		var mid := _cell_center(cr.cell)
		var side := Vector3(-cr.along.z, 0, cr.along.x)
		cr.t += delta
		var y := 0.0
		var jitter := Vector3.ZERO
		match cr.state:
			"up":
				if cr.t >= crusher_rearm:
					for p in players:
						if p.dead or p.escaped:
							continue
						var d: Vector3 = p.global_position - Vector3(mid.x, cr.floor, mid.z)
						if absf(d.dot(cr.along)) < CRUSHER_LONG * 0.5 + crusher_sense and absf(d.dot(side)) < CRUSHER_WIDE * 0.5 and absf(d.y) < 2.0:
							crusher_trip(i)
							break
			"warn":
				jitter = Vector3(randf_range(-0.05, 0.05), randf_range(-0.04, 0.0), randf_range(-0.05, 0.05))
				if cr.t >= crusher_react:
					cr.state = "slam"
					cr.t = 0.0
			"slam":
				y = drop * ease(minf(cr.t / 0.12, 1.0), 2.5)
				if cr.t >= 0.12:
					cr.state = "down"
					cr.t = 0.0
					_crusher_slammed(cr)
			"down":
				y = drop
				if cr.t >= crusher_down_time:
					cr.state = "rise"
					cr.t = 0.0
			"rise":
				y = drop * (1.0 - minf(cr.t / 1.2, 1.0))
				if cr.t >= 1.2:
					cr.state = "up"
					cr.t = 0.0
		node.global_position = Vector3(mid.x, cr.floor + wall_height - y, mid.z) + jitter
		# Under it while it's
		if y > drop * 0.55:
			var bottom: float = node.global_position.y - 0.6 - CRUSHER_SPIKE
			for p in players:
				if p.dead or p.escaped:
					continue
				var d: Vector3 = p.global_position - Vector3(mid.x, cr.floor, mid.z)
				if absf(d.dot(cr.along)) < CRUSHER_LONG * 0.5 and absf(d.dot(side)) < CRUSHER_WIDE * 0.5 and absf(d.y) < 1.5 and bottom < p.global_position.y + 1.4:
					hazard_kill(p, Vector3(0, -2, 0))   # no rings save you


# Someone set it off
func crusher_trip(i: int) -> void:
	if i < 0 or i >= crusher_nodes.size() or crusher_nodes[i].state != "up":
		return
	crusher_nodes[i].state = "warn"
	crusher_nodes[i].t = 0.0


func _crusher_slammed(cr: Dictionary) -> void:
	if cr.snd.stream:
		cr.snd.play()
	var at: Vector3 = Vector3(cr.node.global_position.x, cr.floor, cr.node.global_position.z)
	for p in players:
		var d: float = p.global_position.distance_to(at)
		var near := clampf(1.0 - d / 18.0, 0.0, 1.0)
		p.add_shake(near * near * crusher_shake * camera_shake)


# The grate area
var grate_cells := {}

func _place_grates() -> void:
	if not grate_area:
		return
	var mid := far_cell_from([_cell_center(Vector2i.ZERO), _cell_center(exit_cell)])
	var cells: Array = [mid]
	var edge: Array = [mid]
	for step in grate_size:
		var next: Array = []
		for c in edge:
			for n in _neighbours(c):
				if not cells.has(n):
					cells.append(n)
					next.append(n)
		edge = next
	for c in cells:
		if stair.has(c) or hazards.has(c):
			continue   # not over pits or stairs
		grate_cells[c] = true
		var plane := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(cell_size, cell_size)
		plane.mesh = pm
		plane.material_override = mats["grate"]
		add_child(plane)
		var at := _cell_center(c)
		plane.global_position = Vector3(at.x, _floor_at(c, at) + 0.015, at.z)


# The mirror corridor
const MIRROR_GHOST_LAYER := 1 << 10
const MIRROR_GLASS_LAYER := 1 << 9    # the mirrors don't see themselves
const MIRROR_SHADER := preload("res://Shaders/salvage_mirror.gdshader")
var _mirror_cells: Array = []
var _mirrors: Array = []         # [{"view": SubViewport, "cam": Camera3D, "at": point on it, "n": its normal}]
var _mirror_mid := Vector3.ZERO
var _mirror_ghost: Sprite3D
var _mirror_ghost_in := 4.0
var _mirror_ghost_left := 0.0

func _place_mirrors() -> void:
	if not mirror_area or mirror_length < 1:
		return
	var avoid := grate_cells.duplicate()
	for cr in crusher_nodes:
		avoid[cr.cell] = true
	for c in narrow_cells:
		avoid[c] = true
	# A straight run of corridor
	var runs: Array = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
				var run: Array = []
				for k in mirror_length:
					var c: Vector2i = Vector2i(x, z) + dir * k
					var ways := _neighbours(c)
					if not (ways.has(c + dir) or k == mirror_length - 1) or not (ways.has(c - dir) or k == 0):
						break
					if ways.size() != 2 or stair.has(c) or hazards.has(c) or avoid.has(c) or absi(c.x) + absi(c.y) <= 1 or c == exit_cell:
						break
					run.append(c)
				if run.size() == mirror_length:
					runs.append([run, dir])
	if runs.is_empty():
		return
	var pick: Array = runs[rng.randi_range(0, runs.size() - 1)]
	_mirror_cells = pick[0]
	var dir: Vector2i = pick[1]
	var along := Vector3(dir.x, 0, dir.y)
	var side := Vector3(-along.z, 0, along.x)
	var c0: Vector2i = _mirror_cells[mirror_length / 2]
	_mirror_mid = (_cell_center(_mirror_cells[0]) + _cell_center(_mirror_cells[-1])) * 0.5
	var fl := _floor_at(c0, _cell_center(c0))
	_mirror_mid.y = fl
	var space := get_world_3d().direct_space_state
	var frame_mat: Material = mats.get("metal")
	for sgn in [-1.0, 1.0]:
		var from: Vector3 = _mirror_mid + Vector3(0, 1.2, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + side * sgn * cell_size, 1))
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		n.y = 0.0
		n = n.normalized()
		var view := SubViewport.new()
		view.size = Vector2i(320, 180)
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		var cam := Camera3D.new()
		cam.cull_mask = 0xFFFFF & ~MIRROR_GLASS_LAYER
		view.add_child(cam)
		var mat := ShaderMaterial.new()
		mat.shader = MIRROR_SHADER
		mat.set_shader_parameter("mirror_tex", view.get_texture())
		var panel := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(cell_size * mirror_length, wall_height * 0.82)
		panel.mesh = qm
		panel.material_override = mat
		panel.layers = MIRROR_GLASS_LAYER
		add_child(panel)
		var at: Vector3 = Vector3(hit.position.x, fl + wall_height * 0.45, hit.position.z) + n * 0.03
		panel.global_position = at
		panel.global_basis = Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n)   # facing into the corridor
		var trim := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(cell_size * mirror_length, 0.08, 0.06)
		trim.mesh = tb
		if frame_mat:
			trim.material_override = frame_mat
		add_child(trim)
		trim.global_position = at - Vector3(0, wall_height * 0.41, 0) + n * 0.02
		trim.global_basis = panel.global_basis
		_mirrors.append({"view": view, "cam": cam, "at": at, "n": n})


func _in_mirror_area(at: Vector3) -> bool:
	return _mirror_cells.has(Vector2i(roundi(at.x / cell_size), roundi(at.z / cell_size)))


func _update_mirrors(delta: float) -> void:
	if _mirrors.is_empty():
		return
	var inside = null
	var viewer = null
	for p in players:
		p.cam.cull_mask = (p.cam.cull_mask & ~MIRROR_GHOST_LAYER) | MIRROR_GLASS_LAYER
		if p.dead:
			continue
		if viewer == null and p.global_position.distance_to(_mirror_mid) < cell_size * (mirror_length * 0.5 + 1.5):
			viewer = p
		if _in_mirror_area(p.global_position):
			inside = p
	# Each mirror: a camera mirroring yours across it
	for m in _mirrors:
		var view: SubViewport = m.view
		if viewer == null:
			view.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		var eye: Camera3D = viewer.cam
		var n: Vector3 = m.n
		var at: Vector3 = m.at
		var pos: Vector3 = eye.global_position
		var d := (pos - at).dot(n)
		var mpos := pos - n * 2.0 * d
		var fwd := -eye.global_basis.z
		var up := eye.global_basis.y
		var mfwd := fwd - n * 2.0 * fwd.dot(n)
		var mup := up - n * 2.0 * up.dot(n)
		var cam: Camera3D = m.cam
		cam.global_transform = Transform3D(Basis.looking_at(mfwd, mup), mpos)
		cam.fov = eye.fov
		cam.near = maxf(absf(d) * maxf(absf(mfwd.dot(n)), 0.2) * 0.95, 0.05)
		cam.far = eye.far
		var size: Vector2i = eye.get_viewport().size
		if view.size != size:
			view.size = size
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _mirror_ghost_left > 0.0:
		_mirror_ghost_left -= delta
		if _mirror_ghost_left <= 0.0 and is_instance_valid(_mirror_ghost):
			_mirror_ghost.visible = false
		return
	if inside == null:
		return
	_mirror_ghost_in -= delta
	if _mirror_ghost_in > 0.0:
		return
	_mirror_ghost_in = randf_range(mirror_ghost_every.x, mirror_ghost_every.y)
	var look: Array = _hunter_look([0, 2, 4, 5][randi() % 4]) if randf() < 0.75 else [slender_texture, slender_height]
	if look[0] == null:
		return
	if _mirror_ghost == null:
		_mirror_ghost = Sprite3D.new()
		_mirror_ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_mirror_ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mirror_ghost.shaded = false
		_mirror_ghost.layers = MIRROR_GHOST_LAYER
		add_child(_mirror_ghost)
	_mirror_ghost.texture = look[0]
	_mirror_ghost.pixel_size = float(look[1]) / float(look[0].get_height())
	_mirror_ghost.offset = Vector2(0, look[0].get_height() * 0.5)
	_mirror_ghost.modulate = Color(0.55, 0.55, 0.55)
	var behind: Vector3 = inside.head.global_transform.basis.z
	behind.y = 0.0
	_mirror_ghost.global_position = inside.global_position + behind.normalized() * 1.6
	_mirror_ghost.visible = true
	_mirror_ghost_left = mirror_ghost_time


# Tables to hide under
func _place_tables() -> void:
	if tables <= 0:
		return
	var busy := {}
	for list in [item_nodes, mine_nodes]:
		for n in list:
			busy[Vector2i(roundi(n.global_position.x / cell_size), roundi(n.global_position.z / cell_size))] = true
	for cr in crusher_nodes:
		busy[cr.cell] = true
	var spots: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			var ways := _neighbours(c)
			if ways.size() > 2 or ways.is_empty() or stair.has(c) or hazards.has(c) or busy.has(c) or narrow_cells.has(c):
				continue
			if ways.size() == 2 and ways[0] - c != c - ways[1]:
				continue   # not on corners
			if absi(c.x) + absi(c.y) <= 1 or c == exit_cell:
				continue
			spots.append(c)
	var metal: Material = mats.get("metal")
	for i in mini(_scaled(tables, 1), spots.size()):
		var c: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var ways := _neighbours(c)
		var along := Vector3(ways[0].x - c.x, 0, ways[0].y - c.y).normalized()
		var side := Vector3(-along.z, 0, along.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var mid := _cell_center(c)
		mid.y = _floor_at(c, mid)
		# Against one side
		var q := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 0.5, 0), mid + Vector3(0, 0.5, 0) + side * cell_size, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var wall_d: float = (hit.position - (mid + Vector3(0, 0.5, 0))).length() if not hit.is_empty() else 2.0
		var at: Vector3 = mid + side * maxf(wall_d - 0.6, 0.0)
		_table(at, along, metal)


func _table(at: Vector3, along: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.add_to_group("salvage_cover")
	add_child(body)
	body.global_position = at
	body.rotation.y = atan2(along.x, along.z)
	var top := Vector3(1.1, 0.06, 1.8)   # across, thick, along
	var parts: Array = [[top, Vector3(0, table_height - 0.03, 0)]]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append([Vector3(0.06, table_height - 0.06, 0.06), Vector3(sx * 0.48, (table_height - 0.06) * 0.5, sz * 0.82)])
	for part in parts:
		var size: Vector3 = part[0]
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		if mat:
			mesh.material_override = mat
		mesh.position = part[1]
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = part[1]
		body.add_child(shape)


# Narrow corridors
var narrow_cells := {}           # Vector2i -> true


# Someone's in this narrow corridor
func narrow_taken(c: Vector2i) -> bool:
	for p in players:
		if not p.dead and Vector2i(roundi(p.global_position.x / cell_size), roundi(p.global_position.z / cell_size)) == c:
			return true
	return false


# In one of the narrow corridors
func in_narrow(at: Vector3) -> bool:
	if not narrow_safe or at.y > UP_Y - 4.0:
		return false
	return narrow_cells.has(Vector2i(roundi(at.x / cell_size), roundi(at.z / cell_size)))

func _place_narrows() -> void:
	if narrow_corridors <= 0:
		return
	var busy := {}
	for list in [item_nodes, mine_nodes]:
		for n in list:
			busy[Vector2i(roundi(n.global_position.x / cell_size), roundi(n.global_position.z / cell_size))] = true
	for cr in crusher_nodes:
		busy[cr.cell] = true
	var spots: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			var ways := _neighbours(c)
			if ways.size() != 2 or ways[0] - c != c - ways[1] or stair.has(c) or hazards.has(c) or busy.has(c):
				continue
			if absi(c.x) + absi(c.y) <= 1 or c == exit_cell:
				continue
			spots.append(c)
	var wall: Material = mats.get("wall")
	for i in mini(_scaled(narrow_corridors, 1), spots.size()):
		var c: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		narrow_cells[c] = true
		var ways := _neighbours(c)
		var along := Vector3(ways[0].x - c.x, 0, ways[0].y - c.y).normalized()
		var side := Vector3(-along.z, 0, along.x)
		var mid := _cell_center(c)
		mid.y = _floor_at(c, mid)
		var thick := cell_size * 0.5 - narrow_width * 0.5
		for sgn in [-1.0, 1.0]:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()

			var size := Vector3(thick, wall_height, cell_size)
			box.size = size
			shape.shape = box
			body.add_child(shape)
			var mesh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mesh.mesh = bm
			if wall:
				mesh.material_override = wall
			body.add_child(mesh)
			add_child(body)
			body.global_position = mid + side * sgn * (narrow_width * 0.5 + thick * 0.5) + Vector3(0, wall_height * 0.5, 0)
			body.rotation.y = atan2(along.x, along.z)
		# Rings that were in there move onto the gap's line
		for r in ring_nodes:
			if Vector2i(roundi(r.global_position.x / cell_size), roundi(r.global_position.z / cell_size)) == c:
				var off: float = (r.global_position - mid).dot(side)
				r.global_position -= side * off


# Mines on the floor, scattered through corridors
func _place_mines() -> void:
	if mine_scene == null or Test.level < hazards_from_floor:
		return
	var taken := {}
	for it in item_nodes:
		taken[Vector2i(roundi(it.global_position.x / cell_size), roundi(it.global_position.z / cell_size))] = true
	var cells: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			var c := Vector2i(x, z)
			if absi(c.x) + absi(c.y) > 2 and c != exit_cell and not stair.has(c) and not hazards.has(c) and not taken.has(c):
				cells.append(c)
	for i in mini(roundi(_scaled(mines, 1) * hazard_scale), cells.size()):
		var c: Vector2i = cells.pop_at(rng.randi_range(0, cells.size() - 1))
		var spread := clampf(cell_size * 0.45 - 0.3 * mine_size, 0.0, 1.1)   # big ones stay off the walls
		_new_mine(_cell_center(c) + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread)), c)


func _new_mine(at: Vector3, c: Vector2i) -> void:
	var m: Node3D = mine_scene.instantiate()
	m.position = at
	m.position.y = _floor_at(c, m.position)
	m.scale = Vector3.ONE * mine_size
	add_child(m)
	m.game = self
	m.index = mine_nodes.size()
	mine_nodes.append(m)


# When it goes red
func _alarm_mines(from: Vector3) -> void:
	if mine_scene == null or alarm_mines <= 0 or monsters.is_empty():
		return
	var way: Array = monsters[0]._route(monsters[0]._cell(from), Vector2i.ZERO)
	var picks: Array = []
	var used := {}
	for i in alarm_mines:
		var k := lerpf(0.15, 0.92, float(i) / maxf(alarm_mines - 1, 1))
		var idx := int(way.size() * k)
		if idx < 2 or idx >= way.size():
			continue
		var c: Vector2i = way[idx]
		if used.has(c) or stair.has(c) or hazards.has(c) or c == Vector2i.ZERO:
			continue
		used[c] = true
		var side := randf_range(-0.8, 0.8)
		picks.append([c.x, c.y, snappedf(side, 0.01)])
	_place_alarm_mines(picks)
func _place_alarm_mines(picks: Array) -> void:
	for pk in picks:
		var c := Vector2i(int(pk[0]), int(pk[1]))
		_new_mine(_cell_center(c) + Vector3(float(pk[2]), 0, -float(pk[2])), c)


func mine_click(_m: Node3D, p) -> void:
	p._sound(mine_click_sound, 1.0)


# Someone stepped off
func mine_trip(m: Node3D) -> void:
	if not m.armed:
		return
	m.armed = false
	m.light.visible = true
	await get_tree().create_timer(mine_fuse).timeout
	_mine_blast(m)


# Blasts go through their own bus
func _blast_bus() -> String:
	const NAME := "SalvageBlast"
	var i := AudioServer.get_bus_index(NAME)
	if i == -1:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, NAME)
		AudioServer.set_bus_send(i, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		AudioServer.add_bus_effect(i, AudioEffectDelay.new())
		AudioServer.add_bus_effect(i, AudioEffectReverb.new())
	var echo := AudioServer.get_bus_effect(i, 0) as AudioEffectDelay
	echo.dry = 1.0
	echo.tap1_active = true
	echo.tap1_delay_ms = 260.0
	echo.tap1_level_db = lerpf(-40.0, -5.0, blast_echo)
	echo.tap2_active = true
	echo.tap2_delay_ms = 610.0
	echo.tap2_level_db = lerpf(-40.0, -10.0, blast_echo)
	echo.feedback_active = true
	echo.feedback_delay_ms = 900.0
	echo.feedback_level_db = lerpf(-40.0, -9.0, blast_echo)
	var room := AudioServer.get_bus_effect(i, 1) as AudioEffectReverb
	room.room_size = 0.95
	room.damping = 0.35
	room.wet = 0.5 * blast_echo
	room.dry = 1.0
	return NAME


func _mine_blast(m: Node3D) -> void:
	if not is_instance_valid(m) or m.get_meta("gone", false):
		return
	m.set_meta("gone", true)
	var at := m.global_position
	m.visible = false
	if blast_smoke > 0.0:
		smoke.append({"center": at, "age": 0.0})
	# The levels' explosion, as a sprite facing you
	if mine_blast_texture:
		var fx := Sprite3D.new()
		fx.texture = mine_blast_texture
		fx.hframes = maxi(mine_blast_texture.get_width() / maxi(mine_blast_texture.get_height(), 1), 1)
		fx.pixel_size = 3.0 / mine_blast_texture.get_height()
		fx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fx.shaded = false
		fx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		fx.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		fx.position = at + Vector3(0, 1.0, 0)
		add_child(fx)
		var tw := fx.create_tween()
		tw.tween_property(fx, "frame", mini(mine_blast_frames, fx.hframes) - 1, 0.45).from(0)
		tw.tween_callback(fx.queue_free)
	var nearest := INF
	for p in players:
		nearest = minf(nearest, (p.cam.global_position).distance_to(at))
	if ResourceLoader.exists(mine_blast_sound):
		var snd := AudioStreamPlayer.new()
		snd.stream = load(mine_blast_sound)
		snd.bus = _blast_bus()
		snd.volume_db = linear_to_db(clampf(1.0 - nearest / 60.0, 0.25, 1.0))   # far off: duller, but still heard
		add_child(snd)
		snd.play()
		# Let the echo ring out after the sound itself ends
		snd.finished.connect(func(): get_tree().create_timer(3.0).timeout.connect(snd.queue_free))
	for p in players:
		var d: float = p.cam.global_position.distance_to(at)
		var near := clampf(1.0 - d / blast_shake_range, 0.0, 1.0)
		p.add_shake(near * near * blast_shake_close * camera_shake)
		if p.dead or p.escaped:
			continue
		if absf(p.global_position.y - at.y) > 2.5:
			continue
		var reach: float = mine_blast_radius * (alarm_blast_reach if emerald_taken else 1.0)   # further once it's red
		if d < reach:
			var close := 1.0 - d / reach
			if not mines_kill and _hazard_hit(p, roundi(mine_ring_loss * lerpf(0.5, 1.0, close))):
				knock_down(p, _fling(at, p.global_position, mine_push * lerpf(0.6, 1.0, close)))
			else:
				hazard_kill(p, _fling(at, p.global_position, mine_fling * (0.5 + 0.5 * close)))


func _on_spikes(body: Node3D, area: Area3D) -> void:
	if not players.has(body) or body.dead or body.escaped or body.hurt_left > 0.0:
		return
	if _hazard_hit(body, spike_ring_loss):
		knock_down(body, _fling(area.global_position, body.global_position, spike_push))
	else:
		hazard_kill(body, _fling(area.global_position, body.global_position, 5.0))


func _on_pit(body: Node3D) -> void:
	if players.has(body) and not body.dead and not body.escaped:
		hazard_kill(body, Vector3(0, -3, 0))   # no rings save you from a fall


# Spikes or a mine got someone
func _hazard_hit(p, loss: int) -> bool:
	if p.rings <= 0 and hazards_kill_without_rings:
		return false
	p.rings = maxi(p.rings - Test.rings_lost(loss), 0)
	p._sound(ring_loss_sound, 1.0)
	return true


# A local player died to a hazard
func hazard_kill(p, fling := Vector3.ZERO) -> void:
	kill_player(p, fling)
	var w = watchers.get("local%d" % players.find(p))
	if w:
		w.alive = false


# Do these open sides, turned this many quarter turns, match what's needed?
func _fits(open: Array, turn: int, need: Array, is_stairs: bool, climb: Vector2i) -> bool:
	if open.size() != need.size():
		return false
	for o in open:
		if not need.has(_turned(o, turn)):
			return false
	if is_stairs and _turned(Vector2i(0, 1), turn) != climb:
		return false
	return true


# A direction in a chunk's own frame, as it points after this many quarter turns
func _turned(v: Vector2i, turn: int) -> Vector2i:
	for i in turn:
		v = Vector2i(v.y, -v.x)
	return v


func _turn_to(v: Vector2i, want: Vector2i) -> int:
	for t in 4:
		if _turned(v, t) == want:
			return t
	return 0


# Stretch a 4 m chunk across
func _widen(chunk: Node3D, k: float) -> void:
	if is_equal_approx(k, 1.0):
		return
	var sc := Basis.from_scale(Vector3(k, 1, k))
	var nodes := chunk.find_children("*", "Node3D", true, false)
	var old := {}
	for n in nodes:
		var rel: Transform3D = n.transform
		var p := n.get_parent()
		while p != chunk:
			rel = (p as Node3D).transform * rel
			p = p.get_parent()
		old[n] = rel
	var new := {chunk: Transform3D.IDENTITY}
	for n in nodes:
		var rel: Transform3D = old[n]
		var to := Transform3D(rel.basis, sc * rel.origin)
		if n is MeshInstance3D:
			to.basis = sc * rel.basis
		elif n is CollisionShape3D and (n as CollisionShape3D).shape is BoxShape3D:
			var m := sc * rel.basis
			var x := m.x.normalized()
			var z := (m.z - x * m.z.dot(x)).normalized()
			var box := (n as CollisionShape3D).shape.duplicate() as BoxShape3D
			var b0 := rel.basis
			box.size = Vector3(box.size.x * m.x.length() / b0.x.length(), box.size.y, box.size.z * m.z.length() / b0.z.length())
			(n as CollisionShape3D).shape = box
			to.basis = Basis(x, z.cross(x), z)
		new[n] = to
		var parent_to: Transform3D = new.get(n.get_parent(), Transform3D.IDENTITY)
		n.transform = parent_to.affine_inverse() * to


# The landing spot
func _cut_hole(chunk: Node3D) -> void:
	for n in ["Ceiling", "Collision/CeilingShape"]:
		var node := chunk.get_node_or_null(n)
		if node:
			node.free()
	var half := cell_size * 0.5
	var cy := _ceil_y(Vector2i.ZERO)
	var c := Vector2i.ZERO
	_mbox(Vector3(-half, cy, -half), Vector3(half, cy + 0.2, -HOLE), "ceiling", c)
	_mbox(Vector3(-half, cy, HOLE), Vector3(half, cy + 0.2, half), "ceiling", c)
	_mbox(Vector3(-half, cy, -HOLE), Vector3(-HOLE, cy + 0.2, HOLE), "ceiling", c)
	_mbox(Vector3(HOLE, cy, -HOLE), Vector3(half, cy + 0.2, HOLE), "ceiling", c)


# Take a placed chunk's meshes into the merged ones, and note its lamp spots
func _absorb_chunk(chunk: Node3D, c: Vector2i) -> void:
	for mk in chunk.find_children("*", "Marker3D", true, false):
		if mk.is_in_group("lamp_spot") and c != Vector2i.ZERO:
			lamp_spots.append(mk.global_position)
	for mi in chunk.find_children("*", "MeshInstance3D", true, false):
		var m: Material = mi.material_override
		if m == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			m = mi.mesh.surface_get_material(0)
		if m == null:
			continue
		if m is ShaderMaterial and not mats.values().has(m):
			mats["chunk_%d" % m.get_instance_id()] = m   # so the lamps light it too
		_batch_add(mi.mesh, mi.global_transform, m, c)
		mi.free()


# A box in the merged maze meshes
func _mbox(a: Vector3, b: Vector3, mat_key: String, cell: Vector2i, solid := true) -> void:
	var size := (b - a).abs()
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var center := (a + b) * 0.5
	var bm := BoxMesh.new()
	bm.size = size
	bm.subdivide_width = int(clamp(size.x / 2.0, 0, 8))
	bm.subdivide_depth = int(clamp(size.z / 2.0, 0, 8))
	bm.subdivide_height = int(clamp(size.y / 2.0, 0, 4))
	_batch_add(bm, Transform3D(Basis(), center), mats[mat_key], cell)
	if solid:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.position = center
		maze_body.add_child(shape)


func _batch_add(mesh: Mesh, xform: Transform3D, mat: Material, cell: Vector2i) -> void:
	var key := "%d|%d|%d" % [mat.get_instance_id(), cell.x / 5, cell.y / 5]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = st
		_batch_mats[key] = mat
	_batches[key].append_from(mesh, 0, xform)


func _flush_batches() -> void:
	for key in _batches:
		var mi := MeshInstance3D.new()
		mi.mesh = _batches[key].commit()
		mi.material_override = _batch_mats[key]
		add_child(mi)
	_batches.clear()
	_batch_mats.clear()


func _open(c: Vector2i, d: Vector2i) -> void:
	if d == Vector2i(1, 0): walls_h[c] = false
	elif d == Vector2i(-1, 0): walls_h[c + d] = false
	elif d == Vector2i(0, 1): walls_v[c] = false
	else: walls_v[c + d] = false


func _neighbours(c: Vector2i) -> Array:
	var out := []
	if not walls_h.has(c) or not walls_v.has(c):
		return out
	var hi := maze_lo + maze_size
	if c.x < hi.x - 1 and not walls_h[c]: out.append(c + Vector2i(1, 0))
	if c.x > maze_lo.x and not walls_h[c - Vector2i(1, 0)]: out.append(c - Vector2i(1, 0))
	if c.y < hi.y - 1 and not walls_v[c]: out.append(c + Vector2i(0, 1))
	if c.y > maze_lo.y and not walls_v[c - Vector2i(0, 1)]: out.append(c - Vector2i(0, 1))
	return out


# A cell is part of this visit's maze
func in_maze(c: Vector2i) -> bool:
	return c.x >= maze_lo.x and c.y >= maze_lo.y and c.x < maze_lo.x + maze_size.x and c.y < maze_lo.y + maze_size.y


# Clamp a cell into the maze
func clamp_cell(c: Vector2i) -> Vector2i:
	return c.clamp(maze_lo, maze_lo + maze_size - Vector2i.ONE)


func _distances() -> Dictionary:
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in _neighbours(c):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


# Lamps, items and the exit
func _place_lamps() -> void:
	# The chunks' lamp spots, shuffled with the run's own random numbers
	var spots := lamp_spots.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = spots[i]; spots[i] = spots[j]; spots[j] = tmp
	var n := 0
	for p in spots:
		if n >= _scaled(lamp_count, 14):
			break
		var ceil_h: float = p.y
		# Some lamps are dead, some stutter on and off, the rest barely hold on
		var roll := rng.randf()
		var state := LAMP_DEAD if roll < dead_lamps else (LAMP_STUTTER if roll < dead_lamps + stuttering_lamps else LAMP_ON)
		var key := "lamp_%d" % n
		var lm: ShaderMaterial = mats["lamp"].duplicate()
		mats[key] = lm
		_box(Vector3(p.x - 0.45, ceil_h - 0.1, p.z - 0.25), Vector3(p.x + 0.45, ceil_h, p.z + 0.25), key, false)
		_halo(Vector3(p.x, ceil_h - 0.25, p.z), 2.0, Color(0.95, 0.62, 0.38), 0.4)
		lamp_states[lamps.size()] = state
		lamp_mats[lamps.size()] = [lm, mats["halo_%d" % (mats.size() - 1)]]
		lamps.append(Vector3(p.x, ceil_h - 0.4, p.z))
		n += 1
	for m in mats.values():
		var arr := PackedVector3Array(lamps)
		m.set_shader_parameter("lamps", arr)
		m.set_shader_parameter("lamp_count", mini(lamps.size(), MAX_LAMPS))


# Each lamp's brightness this frame
var _dip_in := -1.0
var _dip_left := 0.0

# The flashlight and the lamps doing their worst
func _scary_lighting(delta: float) -> float:
	if _dip_in < 0.0:
		_dip_in = randf_range(power_dip_every.x, power_dip_every.y)
	_dip_in -= delta
	if _dip_in <= 0.0:
		_dip_left = power_dip_time
		_dip_in = randf_range(power_dip_every.x, power_dip_every.y)
	var beam := 1.0
	# Looking at a hunter
	var near := INF
	var space := get_world_3d().direct_space_state
	for m in monsters:
		if not is_instance_valid(m) or not m.visible or (m is TAILS_DOLL and m.layers == 0):
			continue
		var at: Vector3 = m.global_position + Vector3(0, m.height * 0.6, 0)
		for p in players:
			if p.dead:
				continue
			var eye: Vector3 = p.head.global_position
			var to := at - eye
			var dist := to.length()
			if dist > hunter_flicker_distance or dist < 0.05:
				continue
			if (-p.head.global_transform.basis.z).dot(to / dist) < LOOKING_AT:
				continue   # not where you're looking
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1, [p.get_rid()])).is_empty():
				continue   # a wall in the way
			near = minf(near, dist)
	if near < hunter_flicker_distance and randf() < 0.5 * (1.0 - near / hunter_flicker_distance):
		beam *= randf_range(0.0, 0.4)
	var flash := 0.0 if top_down else beam
	if _blackout or _alarm_pending != null or _all_dark():
		flash *= dark_flashlight   # almost pitch black
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("flash_strength", flash)
	var dip := 1.0
	if _dip_left > 0.0:
		_dip_left -= delta
		dip = 0.15 if randf() < 0.7 else 0.5
	return dip


# How much a hunter stands out of the dark
func hunter_glow_at(at: Vector3) -> float:
	if hunter_glow <= 0.0:
		return 0.0
	var near := INF
	for p in players:
		if not p.dead:
			near = minf(near, p.head.global_position.distance_to(at))
	return hunter_glow * sqrt(clampf(1.0 - near / hunter_glow_distance, 0.0, 1.0))


# The lighting's look, from the Scary Lighting settings
func _apply_scary_look() -> void:
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("lamp_tint", lamp_color)
			m.set_shader_parameter("lamp_range", lamp_reach)
			m.set_shader_parameter("flash_tint", flashlight_color)
			m.set_shader_parameter("flash_range", flashlight_reach)
			m.set_shader_parameter("flash_outer", flashlight_width)
			m.set_shader_parameter("flash_inner", minf(flashlight_width + 0.09, 0.995))
			m.set_shader_parameter("dark_falloff", darkness)


func _update_lamps(delta: float) -> void:
	var dip := _scary_lighting(delta)
	lamp_power.resize(lamps.size())
	for i in lamps.size():
		var v := 1.0   # the elevator's, the hole's and the exit's lights stay on
		match lamp_states.get(i, -1):
			LAMP_DEAD:
				v = 0.0
			LAMP_ON:
				v = (0.85 + 0.1 * sin(time * 23.0 + i) * sin(time * 7.3 + i * 2.0)) * lamp_brightness
				if randf() < 0.003:
					v = 0.3 * lamp_brightness
			LAMP_STUTTER:
				# off most of a second, then a few frantic blinks
				var t := fmod(time * (0.6 + 0.07 * i) + i * 0.37, 1.0)
				v = 0.0 if t < 0.55 else (0.8 if randf() < 0.55 else 0.05)
		if _blackout or _alarm_pending != null or _all_dark():
			v = 0.0   # lights out: from taking the emerald till the alarm
		elif emerald_taken and _alarm_pending == null:
			v = (0.35 + 0.65 * (0.5 + 0.5 * sin(time * 6.0))) * lamp_brightness   # the alarm: every lamp pulsing red
		if lamp_states.has(i):
			v *= dip   # the elevator's, the hole's and the exit's stay on through a dip
			if bracken_lamp_range > 0.0:
				v *= _bracken_dims(lamps[i])
		lamp_power[i] = v
		if not lamp_mats.has(i):
			continue
		var lm: ShaderMaterial = lamp_mats[i][0]
		var glow := 0.12 + 0.88 * v
		lm.set_shader_parameter("color_a", lamp_color.lightened(0.4) * glow if v > 0.0 else Color(0.08, 0.07, 0.06))
		lamp_mats[i][1].set_shader_parameter("strength", 0.4 * v)
	# The nearest lit lamps to any local player
	var order := []
	for i in lamps.size():
		if lamp_power[i] <= 0.0:
			continue
		var dist := INF
		for p in players:
			dist = minf(dist, p.global_position.distance_squared_to(lamps[i]))
		order.append([dist, i])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var pos := PackedVector3Array()
	var pw := PackedFloat32Array()
	for k in mini(order.size(), MAX_LAMPS):
		pos.append(lamps[order[k][1]])
		pw.append(lamp_power[order[k][1]])
	pos.resize(MAX_LAMPS)
	pw.resize(MAX_LAMPS)
	for m in mats.values():
		m.set_shader_parameter("lamps", pos)
		m.set_shader_parameter("lamp_power", pw)
		m.set_shader_parameter("lamp_count", mini(order.size(), MAX_LAMPS))


# Lamps die around a Bracken, the nearest first, and come back once it's gone
func _bracken_dims(at: Vector3) -> float:
	var k := 1.0
	for m in monsters:
		if m.get_script() == BRACKEN and m.visible:
			var d: float = m.global_position.distance_to(at)
			k = minf(k, clampf((d - bracken_lamp_range * 0.4) / (bracken_lamp_range * 0.6), 0.0, 1.0))
	return k


func _place_items() -> void:
	# Spread out across the whole facility
	var chosen: Array[Vector2i] = [Vector2i.ZERO]
	var cells: Array[Vector2i] = []
	for x in range(maze_lo.x, maze_lo.x + maze_size.x):
		for z in range(maze_lo.y, maze_lo.y + maze_size.y):
			if Vector2i(x, z) != Vector2i.ZERO and not stair.has(Vector2i(x, z)) and not hazards.has(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	for i in mini(_scaled(item_count, 6), cells.size()):
		var best := Vector2i.ZERO
		var best_score := -1.0
		for c in cells:
			if chosen.has(c):
				continue
			var gap := INF
			for o in chosen:
				gap = minf(gap, Vector3(c.x - o.x, (level.get(c, 0) - level.get(o, 0)) * 2.5, c.y - o.y).length())
			var score := gap + (0.8 if _neighbours(c).size() == 1 else 0.0) + rng.randf() * 0.6
			if score > best_score:
				best_score = score
				best = c
		chosen.append(best)
		var kind: Array = item_list[rng.randi_range(0, item_list.size() - 1)]
		var p := _cell_center(best) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var node := _make_item(kind, p)
		node.set_meta("id", "i%d" % item_nodes.size())
		item_nodes.append(node)


func _make_item(kind: Array, at: Vector3, turn := true) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2   # only the interact ray hits items
	body.collision_mask = 0
	body.position = at
	if turn:
		body.rotation.y = rng.randf() * TAU
	# A flat sprite that turns to face you, like the characters
	var tex := _item_texture(kind)
	var height: float = kind[6] if kind.size() > 6 else 0.5
	if tex == item_placeholder:
		height = item_placeholder_height
	var spr := Sprite3D.new()
	spr.name = "Sprite"
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.pixel_size = height / float(maxi(tex.get_height(), 1))
	spr.centered = true
	spr.position.y = height * 0.5
	if _grown:   # dropped while seen from above
		spr.pixel_size *= top_down_pickup_scale
		spr.position.y *= top_down_pickup_scale
	body.add_child(spr)
	var width := height * float(tex.get_width()) / float(maxi(tex.get_height(), 1))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()   # round, so it's as easy to aim at from any side
	cyl.radius = width * 0.5 + 0.15
	cyl.height = height + 0.3
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.set_meta("item", kind)
	add_child(body)
	return body


# An item's picture
func _item_texture(kind: Array) -> Texture2D:
	if kind.size() > 5 and kind[5] != null:
		return kind[5]
	if item_placeholder:
		return item_placeholder
	return _placeholder_texture(kind[3], kind[4])


# Items are lit like the characters
func _update_items() -> void:
	for node in item_nodes:
		if node.visible:
			var spr := node.get_node_or_null("Sprite") as Sprite3D
			if spr:
				var l := minf(_light_at(node.global_position + Vector3(0, 0.3, 0)) * 1.25 + 0.08, 1.0)
				if top_down:
					l = maxf(l, 0.9)   # easy to pick out from above
				spr.modulate = Color(l, l, l)


# Stand-in art until an item has its own picture
var _placeholder_cache := {}
func _placeholder_texture(shape: String, color: Color) -> Texture2D:
	var key := "%s_%s" % [shape, color.to_html()]
	if _placeholder_cache.has(key):
		return _placeholder_cache[key]
	const N := 32
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var inside := func(x: float, y: float) -> bool:
		var u := (x + 0.5) / N * 2.0 - 1.0   # -1..1
		var v := (y + 0.5) / N * 2.0 - 1.0
		match shape:
			"circle": return u * u + v * v <= 0.86
			"triangle": return v >= -0.86 and v <= 0.86 and absf(u) <= (v + 0.86) / 1.72 * 0.92
			"diamond": return absf(u) + absf(v) <= 0.95
			_: return absf(u) <= 0.82 and absf(v) <= 0.82
	var edge := color.darkened(0.7)
	var shine := color.lightened(0.35)
	for y in N:
		for x in N:
			if not inside.call(x, y):
				continue
			var border: bool = not (inside.call(x - 2, y) and inside.call(x + 2, y) and inside.call(x, y - 2) and inside.call(x, y + 2))
			var c := edge if border else color
			if not border and x < N * 0.45 and y < N * 0.45 and inside.call(x - 4, y - 4):
				c = shine if (x + y) % 9 == 0 else c   # a few highlight pixels, top left
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[key] = tex
	return tex


func _place_exit() -> void:
	var dist := _distances()
	# Furthest to walk to, and far away across the map too
	var far := Vector2i.ZERO
	var best := -1.0
	for c in dist:
		if stair.has(c):
			continue
		var score: float = dist[c] + Vector2(c).length() * 2.0
		if score > best:
			best = score
			far = c
	exit_cell = far
	var p := _cell_center(far)
	# Back the elevator onto a side of that cell that's a wall
	var side := Vector3(0, 0, 1)
	if far.y == maze_lo.y + maze_size.y - 1 or walls_v.get(far, false):
		side = Vector3(0, 0, 1)
	elif far.x == maze_lo.x + maze_size.x - 1 or walls_h.get(far, false):
		side = Vector3(1, 0, 0)
	elif far.y == maze_lo.y or walls_v.get(far - Vector2i(0, 1), false):
		side = Vector3(0, 0, -1)
	else:
		side = Vector3(-1, 0, 0)
	_build_exit_elevator(p, side)
	for m in mats.values():
		m.set_shader_parameter("lamps", PackedVector3Array(lamps))
		m.set_shader_parameter("lamp_count", mini(lamps.size(), MAX_LAMPS))


# Rings to collect
func _place_rings() -> void:
	ring_sfx = AudioStreamPlayer.new()
	ring_sfx.volume_db = ring_volume_db
	if ResourceLoader.exists(ring_sound):
		ring_sfx.stream = load(ring_sound)
	add_child(ring_sfx)
	# The way out: walk back from the exit to the landing
	var parent := {Vector2i.ZERO: Vector2i.ZERO}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == exit_cell:
			break
		for n in _neighbours(c):
			if not parent.has(n):
				parent[n] = c
				queue.append(n)
	var path: Array[Vector2i] = []
	var at := exit_cell
	while parent.has(at) and at != Vector2i.ZERO:
		path.push_front(at)
		at = parent[at]
	path.push_front(Vector2i.ZERO)
	var on_path := {}
	for c in path:
		on_path[c] = true
	if ring_trail_every > 0:
		for i in range(2, path.size() - 1, ring_trail_every):
			_ring_line(path[i], path[i + 1] - path[i])
	# Decoys: lines in corridors off the way out
	var others: Array[Vector2i] = []
	for c in level:
		if not on_path.has(c) and c != Vector2i.ZERO and c != exit_cell:
			others.append(c)
	others.sort()
	for k in mini(_scaled(decoy_ring_groups, 2), others.size()):
		var c: Vector2i = others[rng.randi_range(0, others.size() - 1)]
		var ways := _neighbours(c)
		if not ways.is_empty():
			_ring_line(c, ways[rng.randi_range(0, ways.size() - 1)] - c)


# Three rings in a line through a cell
func _ring_line(c: Vector2i, d: Vector2i) -> void:
	var dir := Vector3(d.x, 0, d.y)
	var center := Vector3(c.x * cell_size, 0, c.y * cell_size)
	for k in [-1.0, 0.0, 1.0]:
		var pos: Vector3 = center + dir * k * 1.1
		pos.y = _floor_at(c, pos) + 0.55
		var r := Sprite3D.new()
		r.texture = ring_texture
		r.hframes = 7
		r.pixel_size = 0.4 / maxf(ring_texture.get_height(), 1.0)
		r.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		r.shaded = false
		r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		r.position = pos
		r.set_meta("index", ring_nodes.size())
		add_child(r)
		ring_nodes.append(r)


# The floor's height at a point in a cell
func _floor_at(c: Vector2i, pos: Vector3) -> float:
	if not stair.has(c):
		return _floor_y(c)
	var d: Vector2i = stair[c]
	var along := ((pos.x - c.x * cell_size) * d.x + (pos.z - c.y * cell_size) * d.y) / cell_size + 0.5
	return _floor_y(c) + level_step * clampf(along, 0.0, 1.0)


# Spin the rings, and collect the ones a local player touches
func _update_rings() -> void:
	var spin := int(time * 8.0) % 4
	for r in ring_nodes:
		if not is_instance_valid(r) or r.get_meta("taken", false):
			continue
		r.frame = spin
		if top_down:
			# Each ring glints now and then, catching your eye from above
			var glint := fmod(time + float(r.get_meta("index")) * 0.37, 2.2)
			if glint < 0.24:
				r.frame = 4 + int(glint / 0.08)
		for p in players:
			if p.escaped:
				continue
			var off: Vector3 = r.global_position - (p.global_position + Vector3(0, 0.5, 0))
			if Vector2(off.x, off.z).length() < 0.7 and absf(off.y) < 1.0:
				p.rings += 1
				if ring_sfx.stream:
					ring_sfx.play()
				_take_ring(r)
				break


# A ring is gone
func _take_ring(r: Sprite3D) -> void:
	if r.get_meta("taken", false):
		return
	r.set_meta("taken", true)
	var t := create_tween()
	for f in [4, 5, 6]:
		t.tween_callback(func(): r.frame = f)
		t.tween_interval(0.08)
	t.tween_callback(func(): r.visible = false)


# The way out, doors open, backed onto the wall of the exit cell
func _build_exit_elevator(cell_center: Vector3, side: Vector3) -> void:
	var car: Node3D = EXIT_ELEVATOR.instantiate()
	car.position = cell_center + side * (cell_size - CHUNK_CELL) * 0.5
	car.rotation.y = atan2(side.x, side.z)
	add_child(car)
	exit_car = car
	_register_props(car)
	_elevator_music(car, Vector3(0, 2.0, 0))
	_place_emerald.call_deferred(car)
	for d in car.find_children("*", "", true, false):
		if d.is_in_group("elevator_door"):
			# open: slid aside behind the front wall
			d.position.x = d.get_meta("closed_x") + signf(d.get_meta("closed_x")) * 0.72
			exit_doors.append(d)


# Chaos Emerald
var emerald_taken := false       # the alarm's gone off


# How much faster the hunters go right now
func hunter_speed() -> float:
	return emerald_hunter_speed if emerald_taken else 1.0
var emerald_node: Node3D         # the emerald, where it can be picked up
var _emerald_holder = null       # the player who has it
var _alarm: AudioStreamPlayer
var _alarm_red: Array = []       # a red wash over each of our screens
var _chaos_escape := false       # leaving by Chaos Control, not the elevator
var _alarm_pending = null        # took it, still in or by the elevator
var _blackout := false           # the lights are out, just before the alarm


# The Chaos Emerald on a stand in the exit elevator
func _place_emerald(car: Node3D) -> void:
	if not chaos_emerald or _emerald_tex() == null or Test.level < emerald_from_floor:
		return
	if not is_instance_valid(emerald_case):
		_build_emerald_case(car)
	_put_emerald(emerald_case.global_transform * Vector3(0, CASE_GEM_Y, 0))
	_case_powered(true)


# The emerald powers the exit elevator from a glass case on a stand beside it
const CASE_AT := Vector3(2.1, 0.0, 0.95)   # beside the elevator, against the wall it backs onto
const CASE_GEM_Y := 1.22
var emerald_case: Node3D
var _case_wire: StandardMaterial3D

func _build_emerald_case(car: Node3D) -> void:
	var side := 1.0 if posmod(floori(car.global_position.x + car.global_position.z), 2) == 0 else -1.0   # either side, the same on every machine
	var case := Node3D.new()
	case.name = "EmeraldCase"
	car.add_child(case)
	case.position = Vector3(CASE_AT.x * side, 0, CASE_AT.z)
	emerald_case = case
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.21, 0.24)
	metal.metallic = 0.7
	metal.roughness = 0.45
	# the stand, and the case's lid and base rims
	_case_box(case, Vector3(0.6, 0.85, 0.6), Vector3(0, 0.425, 0), metal)
	_case_box(case, Vector3(0.66, 0.06, 0.66), Vector3(0, 0.88, 0), metal)
	_case_box(case, Vector3(0.66, 0.06, 0.66), Vector3(0, 1.52, 0), metal)
	# the glass
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.92, 1.0, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_case_box(case, Vector3(0.56, 0.58, 0.56), Vector3(0, 1.2, 0), glass)
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		_case_box(case, Vector3(0.04, 0.6, 0.04), Vector3(corner.x * 0.29, 1.2, corner.y * 0.29), metal)   # the frame
	# the wire into the elevator's side, lit while the emerald's in
	_case_wire = StandardMaterial3D.new()
	_case_wire.albedo_color = Color(0.1, 0.1, 0.1)
	_case_wire.emission_enabled = true
	var reach := absf(CASE_AT.x) - 1.45 - 0.3   # from the stand to the elevator's outside wall
	_case_box(case, Vector3(reach, 0.07, 0.07), Vector3(-side * (0.3 + reach * 0.5), 1.0, 0), _case_wire)
	_case_box(case, Vector3(0.07, 0.7, 0.07), Vector3(-side * 0.32, 0.65, 0), _case_wire)
	# solid, so you walk round it
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.66, 1.56, 0.66)
	shape.shape = box
	shape.position.y = 0.78
	body.add_child(shape)
	case.add_child(body)
	# what you look at to put it back
	var spot := StaticBody3D.new()
	spot.collision_layer = 2
	spot.collision_mask = 0
	spot.set_meta("emerald_case", true)
	var s2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(0.6, 0.62, 0.6)
	s2.shape = b2
	s2.position.y = 1.2
	spot.add_child(s2)
	case.add_child(spot)


func _case_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)


# The wire lit in the emerald's colour while it's in its case
func _case_powered(on: bool) -> void:
	if _case_wire == null:
		return
	var c: Color = emerald_glows[_emerald_i() % emerald_glows.size()] if not emerald_glows.is_empty() else Color(0.3, 1.0, 0.4)
	_case_wire.emission = c
	_case_wire.emission_energy_multiplier = 2.5 if on else 0.0


func _put_emerald(at: Vector3) -> void:
	if is_instance_valid(emerald_node):
		emerald_node.queue_free()
	var body := StaticBody3D.new()
	body.collision_layer = 2   # only the interact ray
	body.collision_mask = 0
	body.set_meta("emerald", true)
	add_child(body)
	body.global_position = at
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	body.add_child(shape)
	var spr := Sprite3D.new()
	spr.name = "Gem"
	spr.texture = _emerald_tex()
	spr.hframes = maxi(emerald_frames, 1)
	spr.pixel_size = emerald_size * (super_emerald_size if is_super_emerald() else 1.0) / (spr.texture.get_height() * 0.4)   # the gem fills about 40% of its frame
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	body.add_child(spr)
	var glow := OmniLight3D.new()
	glow.light_color = emerald_glows[_emerald_i() % emerald_glows.size()] if not emerald_glows.is_empty() else Color(0.3, 1.0, 0.4)
	glow.omni_range = 2.0
	glow.light_energy = 0.8
	if is_super_emerald():
		glow.omni_range = 3.0
		glow.light_energy = 1.4
	body.add_child(glow)
	emerald_node = body


func _spin_emerald() -> void:
	if is_instance_valid(emerald_node):
		var spr: Sprite3D = emerald_node.get_node("Gem")
		spr.frame = int(time * emerald_fps) % spr.hframes
		spr.position.y = 0.06 * sin(time * 2.0)
		if is_super_emerald():
			spr.modulate = Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.8), 0.5 + 0.5 * sin(time * 9.0))   # a Super Emerald shimmers


# Which emerald this floor's is
func _emerald_i() -> int:
	return clampi(Test.super_emeralds if is_super_emerald() else Test.chaos_emeralds, 0, 6)


# After the 7 Chaos Emeralds, the emerald here is a Super Emerald
func is_super_emerald() -> bool:
	return Test.chaos_emeralds >= Test.SUPER_EMERALDS and not super_emerald_colours.is_empty()


# This floor's emerald picture
func _emerald_tex() -> Texture2D:
	var list := (super_emerald_colours if is_super_emerald() else emerald_colours).filter(func(t): return t != null)
	return list[_emerald_i() % list.size()] if not list.is_empty() else emerald_texture


# A frame of the emerald, for the item icons
func emerald_icon() -> Texture2D:
	var tex := _emerald_tex()
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := tex.get_width() / maxi(emerald_frames, 1)
	at.region = Rect2(0, 0, w, tex.get_height())
	return at


# One of our players picks it up
func take_emerald(p) -> void:
	if not is_instance_valid(emerald_node) or leaving or _chaos_escape:
		return
	var first := not emerald_taken
	_emerald_taken_by(p, first)


func _emerald_taken_by(who, first: bool) -> void:
	if is_instance_valid(emerald_node):
		emerald_node.queue_free()
	emerald_node = null
	_emerald_holder = who
	_case_powered(false)
	_emerald_down = false
	if who is Node and who.has_method("add_item_icon"):
		who.has_emerald = true
		who.add_item_icon(emerald_icon())
		if who.hud_items and who.hud_items.get_child_count() > 0:
			who.hud_items.get_child(who.hud_items.get_child_count() - 1).set_meta("emerald", true)
	if first:
		emerald_taken = true
		_alarm_pending = who
		_cancel_depart()   # if the doors were closing, they stop
		_play_once(power_out_sound, Vector3.ZERO, true)


# Still in the elevator with it, nothing set off yet
func can_put_back() -> bool:
	return emerald_taken and _alarm_pending != null and not _blackout and _alarm_red.is_empty() and _alarm == null


# Pressing the dead button
func play_dead_button() -> void:
	if is_instance_valid(exit_button()):
		_play_once(dead_button_sound, exit_button().global_position, true)


func put_emerald_back(p) -> void:
	if not can_put_back():
		return
	_emerald_put_back(p)


func _emerald_put_back(who) -> void:
	emerald_taken = false
	_alarm_pending = null
	_emerald_holder = null
	if who is Node and who.has_method("remove_emerald_icon"):
		who.has_emerald = false
		who.remove_emerald_icon()
	if is_instance_valid(exit_car):
		_place_emerald(exit_car)


# Whoever took it is out of the elevator
func _check_alarm_start() -> void:
	if _alarm_pending == null or _blackout or not is_instance_valid(exit_car):
		return
	var p = _alarm_pending
	if not (p is Node) or not is_instance_valid(p):
		return
	var car := exit_car.global_position
	var out := Vector2(p.global_position.x - car.x, p.global_position.z - car.z).length()
	if p.dead or (not in_exit_car(p.global_position) and out > CHUNK_CELL * 0.5 + alarm_after_leaving):
		_lights_out(p)


func _lights_out(who) -> void:
	if _blackout:
		return
	_blackout = true
	_alarm_pending = null
	await get_tree().create_timer(blackout_time).timeout
	_blackout = false
	if not is_inside_tree() or leaving:
		return
	if who is int and who == 0:
		who = players[0] if not players.is_empty() else who   # it's us
	_sound_alarm(who)


# The alarm: the elevator's dead, the maze goes red, every hunter comes for them
func _sound_alarm(who) -> void:
	_alarm_at = time
	emerald_taken = true
	if ResourceLoader.exists(alarm_sound):
		_alarm = AudioStreamPlayer.new()
		var st = load(alarm_sound)
		if st is AudioStreamWAV:
			st = st.duplicate()
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_end = int(st.get_length() * st.mix_rate)
		elif "loop" in st:
			st = st.duplicate()
			st.loop = true
			if "loop_offset" in st:
				st.loop_offset = 0.4   # past the quiet bit at the start
		_alarm.stream = st
		_alarm.volume_db = alarm_volume_db
		_alarm.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(_alarm)
		_alarm.play()
	lamp_color = alarm_color
	flashlight_color = alarm_color
	for i in lamp_states.keys():
		lamp_states[i] = LAMP_ON   # every lamp comes on, flashing red
	_apply_scary_look()
	# The foggy patches go red as well
	fog_color = alarm_color.darkened(0.55)
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("fog_tint", fog_color)
	for p in players:
		if p.get("fog_env"):
			p.fog_env.fog_light_color = fog_color
	for p in players:
		var red := ColorRect.new()
		red.color = Color(alarm_color, 0.0)
		red.set_anchors_preset(Control.PRESET_FULL_RECT)
		red.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.hud.add_child(red)
		p.hud.move_child(red, 1)   # over the view, under the HUD
		_alarm_red.append(red)
	if alarm_extra_hunter:
		for n in alarm_extra_hunters:
			var have := monsters.map(func(m): return _hunter_kind(m))
			var kind := 0
			for k in [0, 2, 3, 4, 5, 1]:
				if not have.has(k):
					kind = k
					break
			_add_hunter(kind)
	var w = null
	if who is Node:
		w = watchers.get("local%d" % players.find(who))
	else:
		w = watchers.get(who)
	var at: Vector3 = w.feet if w else players[0].global_position
	_alarm_mines(at)
	# The way back to the entrance
	var way: Array = []
	if alarm_in_your_way and not monsters.is_empty():
		way = monsters[0]._route(monsters[0]._cell(at), Vector2i.ZERO)
	var new_ones := monsters.filter(func(m): return not m.visible)
	for i in new_ones.size():
		var mon = new_ones[i]
		mon.spawn_after = time - hunter_settle_time - 0.1   # here now, and hunting straight away
		if way.size() >= 6:
			var k := 0.35 + 0.4 * float(i) / maxf(new_ones.size() - 1, 1)
			mon.spawn(_cell_center(way[clampi(int(way.size() * k), 3, way.size() - 1)]))
		else:
			mon.spawn(_cell_center(far_cell_from([at])))
	for mon in monsters:
		mon.alarm(w, alarm_hunt_time)


func _hunter_kind(m: Node) -> int:
	if m is SLENDER: return 1
	if m is FREDDY: return 2
	if m is TAILS_DOLL: return 3
	if m is ROOM: return 4
	if m is MX: return 5
	if m is CLONE: return 6
	if m is MIMIC: return 7
	if m is SPIDER: return 8
	return 0


# Every frame while it's going
func _update_alarm(_delta: float) -> void:
	if _all_dark():
		# Dropped: no red, nothing, till someone picks it up
		for m in mats.values():
			if m is ShaderMaterial:
				m.set_shader_parameter("alarm_light", Vector3.ZERO)
		for red in _alarm_red:
			if is_instance_valid(red):
				red.color.a = 0.0
		return
	if not emerald_taken or _alarm_pending != null or _blackout or _alarm == null and _alarm_red.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var light: Color = alarm_color * alarm_brightness * (0.8 + 0.2 * pulse)
	for m in mats.values():
		if m is ShaderMaterial:
			m.set_shader_parameter("alarm_light", Vector3(light.r, light.g, light.b))
	for red in _alarm_red:
		if is_instance_valid(red):
			red.color.a = alarm_screen_red * (0.45 + 0.55 * pulse)
	if _alarm and (departing or leaving):
		_alarm.volume_db = lerpf(_alarm.volume_db, -40.0, 0.05)


# Whoever has it died
var _alarm_at := -1.0           # when the alarm went off

# After the alarm's few seconds of red
func _all_dark() -> bool:
	if _emerald_down:
		return true
	return emerald_taken and _alarm_pending == null and _alarm_at >= 0.0 and alarm_red_time > 0.0 and time - _alarm_at > alarm_red_time


var _emerald_down := false      # it's been dropped

func _drop_emerald(at: Vector3) -> void:
	_emerald_holder = null
	_put_emerald(at + Vector3(0, 0.6, 0))
	if emerald_taken and emerald_drop_dark:
		_emerald_down = true


# Back where you dropped in, with the emerald
func near_entrance(at: Vector3) -> bool:
	var c := _cell_center(Vector2i.ZERO)
	return Vector2(at.x - c.x, at.z - c.z).length() < chaos_control_reach and absf(at.y - c.y) < 2.0


func can_chaos_control(p) -> bool:
	return emerald_taken and p.get("has_emerald") and not p.dead and not departing and near_entrance(p.global_position)


func chaos_control(p) -> void:
	if not can_chaos_control(p):
		return
	_chaos_control()


func _chaos_control() -> void:
	if departing:
		return
	departing = true
	_chaos_escape = true
	if ResourceLoader.exists(chaos_control_sound):
		var snd := AudioStreamPlayer.new()
		snd.stream = load(chaos_control_sound)
		snd.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(snd)
		snd.play()
	# A white flash, and whoever's close enough is gone with it
	for p in players:
		p.prompt.text = ""
		var flash := ColorRect.new()
		flash.color = Color(1, 1, 1, 0)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.hud.add_child(flash)
		create_tween().tween_property(flash, "color:a", 1.0, 0.5)
	await get_tree().create_timer(0.6).timeout
	var got_emerald := false
	for p in players:
		if p.dead:
			continue
		p.escaped = true
		if near_entrance(p.global_position):
			if p.get("has_emerald"):
				p.rings += emerald_rings
			_apply_upgrades(p)
			got_emerald = true
	if got_emerald:
		if Test.chaos_emeralds >= Test.SUPER_EMERALDS:
			Test.super_emeralds = mini(Test.super_emeralds + 1, Test.SUPER_EMERALDS)
		else:
			Test.chaos_emeralds += 1   # everyone who got out with it
	_count_mikus()
	_leave()


# Where you get out from
func in_escape(at: Vector3) -> bool:
	return near_entrance(at) if _chaos_escape else in_exit_car(at)


var _told_saves := false
# STUN: each Salvage visit, as many as your Stun items
func stuns_left(p) -> int:
	return Test.salvage_stuns - int(p.get_meta("stuns_used", 0))


# One of our players pressed Stun
func use_stun(p) -> void:
	if stuns_left(p) <= 0 or p.dead or p.escaped:
		return
	p.set_meta("stuns_used", int(p.get_meta("stuns_used", 0)) + 1)
	_play_once(stun_sound, p.global_position)
	p.flash_screen(Color(0.85, 0.95, 1.0), 0.45)
	var w = watchers.get("local%d" % players.find(p))
	var hit: Array = []
	for i in monsters.size():
		var mon = monsters[i]
		if mon.visible and w and mon._flat_dist(w.feet) < stun_range and mon._sees_me(w):
			hit.append(i)
	for i in hit:
		_stun_hunter(monsters[i])


func _stun_hunter(mon: Node3D) -> void:
	mon.stunned_left = stun_time
# The Survive item took the hit
func _survived(p, mon: Node3D) -> void:
	_stun_hunter(mon)
	p.hurt_left = survive_grace
	p.flash_screen(Color(1, 1, 1), 0.6)
	_play_once(stun_sound, p.global_position)


func _play_once(path: String, _at: Vector3, in_the_dark := false) -> void:
	if not ResourceLoader.exists(path):
		return
	var snd := AudioStreamPlayer.new()
	if in_the_dark:
		snd.set_meta("keep_in_dark", true)
	snd.stream = load(path)
	snd.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)


# The exit elevator's ESCAPE button
var _exit_button: Node3D
func exit_button() -> Node3D:
	if _exit_button == null and exit_car:
		for n in exit_car.find_children("*", "CollisionObject3D", true, false):
			if n.has_meta("button"):
				_exit_button = n
	return _exit_button


# Is this point inside the exit elevator?
func in_exit_car(world: Vector3) -> bool:
	if exit_car == null:
		return false
	var l := exit_car.to_local(world)
	return absf(l.x) < 1.15 and l.z > -0.55 and l.z < 1.6 and l.y > -0.5 and l.y < 2.5


# Players Render layers
func _build_players(pads: Array) -> void:
	var count := 1
	var canvas := CanvasLayer.new()
	canvas.layer = 90   # over everything from the 2D game
	add_child(canvas)
	var size_now: Vector2i = ps1_resolution if ps1_on() else render_size
	var res := size_now
	var chars := [Test.characterone]
	for i in count:
		var p = PLAYER.instantiate()
		p.index = i
		p.actions = "sv_"
		p.pad = pads[i]
		p.use_mouse = i == 0
		p.character = chars[i]
		add_child(p)
		var mask: int = MIRROR.camera_mask(0xFFFFF ^ (1 << (1 + i)), i)
		for j in 2:
			if j != i:
				mask &= ~(1 << (TAILS_DOLL.HAUNT_LAYER_BIT + j))   # only the haunted see the doll
		p.build(self, res, mask)
		var spot := _spawn_spot(i, count)
		p.global_position = spot
		p.rotation.y = PI   # facing the doors
		var mirrors := get_tree().get_nodes_in_group("salvage_mirror")
		if start_facing_mirror and not mirrors.is_empty():
			# Looking at yourself in the elevator's mirror, to start with
			var to: Vector3 = (mirrors[0] as Node3D).global_position - spot
			p.rotation.y = atan2(-to.x, -to.z)
		var area := Control.new()
		area.set_anchors_preset(Control.PRESET_FULL_RECT)
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.clip_contents = true
		canvas.add_child(area)
		# The screen look
		var post := SubViewport.new()
		post.disable_3d = true
		post.transparent_bg = false
		post.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(post)
		var look := TextureRect.new()
		look.texture = p.view.get_texture()
		look.stretch_mode = TextureRect.STRETCH_SCALE
		look.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var m := ShaderMaterial.new()
		m.shader = SCREEN_SHADER
		if ps1_on():
			m.set_shader_parameter("levels", ps1_colour_levels)
		look.material = m
		post.add_child(look)
		p.set_meta("post", post)
		var screen := TextureRect.new()
		screen.texture = post.get_texture()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.stretch_mode = TextureRect.STRETCH_SCALE
		screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if ps1_on() else CanvasItem.TEXTURE_FILTER_LINEAR   # hard PS1 pixels, or soft
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm := ShaderMaterial.new()
		fm.shader = FINISH_SHADER
		screen.material = fm
		area.add_child(screen)
		p.screen = screen
		p.set_meta("eye_res", res)
		_view_size(p)
		p.fog_env = world_env.duplicate()
		p.fog_env.fog_enabled = true
		p.fog_env.fog_light_color = fog_color
		p.fog_env.fog_density = 0.0
		p.fog_env.fog_sky_affect = 1.0
		p.cam.environment = p.fog_env
		if top_down:
			_add_vision(p, area)
		var tag := ""
		var tag_col: Color = TAG_COLORS[i % TAG_COLORS.size()]
		p.build_hud(area, tag, tag_col)
		if top_down:
			p.use_top_down(top_down_height, top_down_fov)
			p.cam.cull_mask = (p.cam.cull_mask | (1 << (1 + i))) & ~CEILING_LAYER   # see yourself, not the ceiling
		p.caught_color = caught_color
		p.caught_fade = caught_fade_time
		if map_enabled:
			p.map = MAP.new()
			p.map.room_color = map_color
			p.map.you_color = map_you_color
			p.map.exit_color = map_exit_color
			p.map.entrance_color = map_entrance_color
			p.map.back_color = map_back_color
			area.add_child(p.map)
			p.map.setup(self, p)
		if Test.mobile and i == 0:
			touch = TOUCH.new()
			touch.look_speed = touch_look_speed
			touch.button_scale = touch_button_scale
			touch.STICK_RADIUS = touch_stick_radius
			area.add_child(touch)
			touch.setup(self, p)
		players.append(p)
	player = players[0]
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)


# Elevator spots
func _spawn_spot(slot: int, count: int) -> Vector3:
	var spread := 0.6
	var row := slot / 4
	var in_row := mini(count - row * 4, 4)
	var x := (slot % 4 - (in_row - 1) * 0.5) * spread
	return Vector3(clampf(x, -1.2, 1.2), UP_Y + 0.05, -14.6 + row * 0.75)


# The others, as DOOM-style sprites
func _build_others() -> void:
	# From above you see yourself
	if top_down:
		for i in players.size():
			var spr = _make_sprite(players[i].character, 1 << (1 + i))
			if spr:
				partner_sprites[i] = spr
	# AI teammates: alone, your 2nd, 3rd and 4th picks follow you
	var picks := [Test.charactertwo, Test.characterthree, Test.characterfour]
	var n := 0
	for k in picks.size():
		var name: String = picks[k]
		if name == "" or name == Test.characterone:
			continue
		var tm = _make_sprite(name, 1)
		if tm == null:
			continue
		n += 1
		tm.set_meta("lead", 0)
		tm.gap = 1.4 * n
		tm.global_position = players[0].global_position + Vector3(0.6 * (1 if n % 2 == 1 else -1), 0, -0.9)
		followers.append(tm)


func _make_sprite(character: String, layer: int):
	var spr = TEAMMATE.instantiate()
	if not spr.setup(character):
		spr.free()
		return null
	spr.layers = layer
	spr.min_light = 1.0 if top_down else character_brightness
	if top_down:
		spr.pixel_size *= top_down_character_scale
	add_child(spr)
	return spr


# What's only for looking at
var _was_dark := false
var _hushed: Array = []      # sounds paused while it's dark
var _hush_scan := 0.0


func _bracken_winding() -> bool:
	for m in monsters:
		if m.get_script() == BRACKEN and m.winding and m.visible:
			return true
	return false


# While a Bracken stalks you, its steps fall in behind yours
func echo_step(p) -> void:
	if not bracken_echo_steps or p.dead:
		return
	for m in monsters:
		if m.get_script() != BRACKEN or not m.visible or m.state != m.STALK:
			continue
		var at: Vector3 = m.global_position
		var d := at.distance_to(p.global_position)
		if d > bracken_echo_range:
			continue
		var w = watchers.get("local%d" % players.find(p))
		if w and m._sees_me(w):
			continue
		var dread = get_node_or_null("Dread")
		if dread == null or dread_steps.is_empty():
			return
		var vol := clampf(1.0 - d / bracken_echo_range, 0.15, 1.0) * 0.8
		get_tree().create_timer(randf_range(0.12, 0.2)).timeout.connect(func():
			if is_instance_valid(m) and m.visible:
				dread._at(dread_steps[randi() % dread_steps.size()], m.global_position + Vector3(0, 0.2, 0), vol, randf_range(0.9, 1.0)))
		return


func _hush(dark: bool, delta: float) -> void:
	if not dark:
		if not _hushed.is_empty():
			for snd in _hushed:
				if is_instance_valid(snd):
					snd.stream_paused = false
			_hushed.clear()
		return
	_hush_scan -= delta
	if _hush_scan > 0.0:
		return
	_hush_scan = 0.25
	var steps: Array = []
	for p in players:
		steps.append(p.get("step_player"))
	for snd in find_children("*", "AudioStreamPlayer", true, false) + find_children("*", "AudioStreamPlayer3D", true, false):
		if steps.has(snd) or snd.has_meta("keep_in_dark") or snd.stream_paused or not snd.playing:
			continue
		snd.stream_paused = true
		_hushed.append(snd)


func _process(delta: float) -> void:
	_spin_emerald()
	_check_alarm_start()
	var dark := _blackout or _alarm_pending != null or _all_dark()
	_hush(dark or _bracken_winding(), delta)   # and the silence before a Bracken charges
	if dark != _was_dark:
		_was_dark = dark
		for m in mats.values():
			if m is ShaderMaterial:
				if dark:
					m.set_meta("glow_before", m.get_shader_parameter("player_glow"))
					m.set_shader_parameter("player_glow", 0.0)
				elif m.has_meta("glow_before"):
					m.set_shader_parameter("player_glow", m.get_meta("glow_before"))
	_update_alarm(delta)
	if players.is_empty():
		return
	_update_lamps(delta)
	_update_rings()
	_update_items()
	_update_signs()
	_update_deck()
	_update_maps()
	for card in ragdoll_cards:
		if is_instance_valid(card):
			var l := maxf(_light_at(card.global_position), 1.0 if top_down else character_brightness)
			(card.material_override as ShaderMaterial).set_shader_parameter("tint", Color(l, l, l))


func _physics_process(delta: float) -> void:
	if players.is_empty():
		return
	time += delta
	_update_knockdowns(delta)
	_update_crushers(delta)
	_update_mirrors(delta)
	for p in players:
		p.physics(delta)
	var cam: Camera3D = player.cam
	for tm in followers:
		var lead = players[mini(int(tm.get_meta("lead", 0)), players.size() - 1)]
		tm.follow(lead.global_position, cam, _light_at(tm.global_position + Vector3(0, 0.6, 0)), delta)
	_update_mikus(cam, delta)
	for i in partner_sprites:
		var spr = partner_sprites[i]
		var who = players[i]
		spr.visible = not who.escaped and not is_instance_valid(who.knocked)   # a knocked-down body is its own sprite
		var viewer: Camera3D = who.cam if top_down else players[1 - i].cam
		spr.drive(who.global_position, viewer, _light_at(who.global_position + Vector3(0, 0.6, 0)), delta, who.anim_state())
	_update_fog(delta)
	_update_hunters(delta)
	for card in ragdoll_cards:
		if is_instance_valid(card):
			var mat: ShaderMaterial = card.material_override
			# Spins as fast as the body tumbles, settling as it comes to rest
			var body: RigidBody3D = card.get_parent()
			var turn: float = card.get_meta("spin") + card.get_meta("way") * body.angular_velocity.length() * ragdoll_card_spin * delta
			card.set_meta("spin", turn)
			mat.set_shader_parameter("spin", turn)
	_update_shadows()


# Everyone who gets a shadow right now
func _shadow_casters() -> Array:
	var out := []
	for p in players:
		if not p.dead and not p.escaped:
			out.append([p, 1])
	for tm in followers:
		if is_instance_valid(tm) and tm.is_visible_in_tree():
			out.append([tm, tm.layers])
	for mk in miku_list:
		if is_instance_valid(mk.sprite) and mk.sprite.is_visible_in_tree():
			out.append([mk.sprite, mk.sprite.layers])
	for m in monsters:
		if is_instance_valid(m) and m.is_visible_in_tree():
			out.append([m, m.layers])
	for card in ragdoll_cards:
		if is_instance_valid(card):
			out.append([card.get_parent(), card.layers])
	return out

func _update_shadows() -> void:
	var casters := _shadow_casters() if character_shadows else []
	var keep := {}
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for p in players:
		skip.append(p.get_rid())
	for c in casters:
		var node: Node3D = c[0]
		keep[node] = true
		var sh: MeshInstance3D = _shadows.get(node)
		if sh == null:
			sh = _make_shadow()
			_shadows[node] = sh
		var feet := node.global_position
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.4, feet + Vector3.DOWN * shadow_fade_height, 1, skip)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			sh.visible = false
			continue
		var floor_at: Vector3 = hit.position
		var up: Vector3 = hit.normal
		var fade := 1.0 - clampf((feet.y - floor_at.y) / shadow_fade_height, 0.0, 1.0)
		var away := _shadow_lean_at(floor_at + Vector3.UP)
		var side := Vector3.RIGHT if away.length() < 0.01 else away.normalized().cross(up).normalized()
		var along := up.cross(side).normalized()
		var mat: ShaderMaterial = sh.material_override
		sh.layers = c[1]
		sh.visible = fade > 0.0
		if hunter_outline_shadows and monsters.has(node) and node.texture:
			_lay_outline(sh, node, floor_at, up, away)
		else:
			var size := _shadow_width_of(node) * lerpf(0.6, 1.0, fade)
			var length := size * (1.0 + away.length() * shadow_lean)
			sh.global_transform = Transform3D(Basis(side * size, up, along * length),
				floor_at + up * 0.02 + along * (length - size) * 0.5)
			mat.set_shader_parameter("outline", false)
		mat.set_shader_parameter("strength", shadow_darkness * fade * (1.0 - fog_at(floor_at)))
	for node in _shadows.keys():
		if not keep.has(node):
			if is_instance_valid(_shadows[node]):
				_shadows[node].queue_free()
			_shadows.erase(node)


# A hunter's shadow
func _lay_outline(sh: MeshInstance3D, mon: Sprite3D, floor_at: Vector3, up: Vector3, away: Vector3) -> void:
	if away.length() < 0.05:
		away = _nearest_lamp_away(floor_at)
	var along := (away - up * away.dot(up)).normalized()
	var side := along.cross(up).normalized()
	var cells := Vector2(mon.hframes, mon.vframes)
	var size := Vector2(mon.texture.get_size()) / cells
	var corner := Vector2(mon.frame % mon.hframes, mon.frame / mon.hframes) * size
	if mon.region_enabled:
		size = mon.region_rect.size
		corner = mon.region_rect.position
	var width := size.x * mon.pixel_size
	var length := size.y * mon.pixel_size * lerpf(hunter_shadow_length.x, hunter_shadow_length.y, clampf(away.length(), 0.0, 1.0))
	sh.global_transform = Transform3D(Basis(side * width, up, along * length),
		floor_at + up * 0.02 + along * length * 0.5)
	var mat: ShaderMaterial = sh.material_override
	var tex_size := Vector2(mon.texture.get_size())
	mat.set_shader_parameter("outline", true)
	mat.set_shader_parameter("picture", mon.texture)
	mat.set_shader_parameter("region", Vector4(corner.x / tex_size.x, corner.y / tex_size.y, size.x / tex_size.x, size.y / tex_size.y))
	mat.set_shader_parameter("flip", mon.flip_h)


# Which way the nearest lamp throws a shadow along the floor
func _nearest_lamp_away(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for l in lamps:
		var d := p.distance_to(l)
		if d < best_d:
			best_d = d
			best = l
	var flat := p - best
	flat.y = 0.0
	return flat.normalized() * 0.05 if flat.length() > 0.01 else Vector3.FORWARD * 0.05


# How wide a shadow someone gets
func _shadow_width_of(node: Node3D) -> float:
	var spr := node as Sprite3D
	if spr == null or spr.texture == null:
		return shadow_size
	var drawn := spr.texture.get_width() / float(spr.hframes) * spr.pixel_size
	if spr.region_enabled:
		drawn = spr.region_rect.size.x * spr.pixel_size
	return clampf(drawn * shadow_width, shadow_size * 0.6, 2.4)


func _make_shadow() -> MeshInstance3D:
	var sh := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	sh.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	mat.render_priority = -1   # under the characters, never over them
	sh.material_override = mat
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sh)
	return sh


# Which way (on the floor) the light pushes a shadow, and how hard
func _shadow_lean_at(p: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var lights := []
	for i in lamps.size():
		var pw: float = lamp_power[i] if i < lamp_power.size() else 1.0
		var w := pow(clampf(1.0 - p.distance_to(lamps[i]) / 4.8, 0.0, 1.0), 2.2) * pw
		lights.append([lamps[i], w])
	if not top_down:
		for pl in players:
			if not pl.dead:
				var w := pow(clampf(1.0 - p.distance_to(pl.cam.global_position) / 5.0, 0.0, 1.0), 1.6) * 0.6
				lights.append([pl.cam.global_position, w])
	for l in lights:
		var flat: Vector3 = p - l[0]
		flat.y = 0.0
		var reach := flat.length()
		if reach > 0.05:
			push += flat / reach * l[1] * clampf(reach / 2.5, 0.0, 1.0)
	return push.limit_length(1.0)


# Each player's map
func _update_maps() -> void:
	for p in players:
		if p.map:
			p.map.track()
			if Input.is_action_just_pressed(p.actions + "map") and not menu_open():
				p.map.toggle()


# Light from the lamps alone
func lamp_light_at(p: Vector3) -> float:
	var l := 0.0
	for i in lamps.size():
		var pw: float = lamp_power[i] if i < lamp_power.size() else 1.0
		l += pow(clampf(1.0 - p.distance_to(lamps[i]) / 4.8, 0.0, 1.0), 2.2) * 0.9 * pw
	return clampf(l, 0.0, 1.0)


# How bright a point is
func _light_at(p: Vector3) -> float:
	if top_down:
		var near := p.distance_to(player.head.global_position)
		var lt := pow(clampf(1.0 - near / top_down_glow, 0.0, 1.0), 2.0) * top_down_brightness
		for i in lamps.size():
			var pw: float = lamp_power[i] if i < lamp_power.size() else 1.0
			lt += pow(clampf(1.0 - p.distance_to(lamps[i]) / 4.8, 0.0, 1.0), 2.2) * 0.9 * pw
		return clampf(lt + 0.01, 0.0, 1.0)
	var d := p.distance_to(player.cam.global_position)
	var l := pow(clampf(1.0 - d / 5.0, 0.0, 1.0), 1.6) * 0.55
	for i in lamps.size():
		var pw: float = lamp_power[i] if i < lamp_power.size() else 1.0
		l += pow(clampf(1.0 - p.distance_to(lamps[i]) / 4.8, 0.0, 1.0), 2.2) * 0.9 * pw
	return clampf(l * exp(-d * 0.02) + 0.01, 0.0, 1.0)


# Miku She waits in the far corners, waving
func _place_mikus() -> void:
	var looks: Array = miku_looks.filter(func(t): return t != null)
	if looks.is_empty():
		looks = Content.data().miku_looks.filter(func(t): return t != null)
	if looks.is_empty():
		looks = [load("res://Sprites/Obstacles/Miku/miku1.png")]
	var away: Array = [Vector3.ZERO, exit_car.global_position if exit_car else Vector3.ZERO]
	for node in item_nodes:
		away.append(node.global_position)
	for i in mikus:
		var c := far_cell_from(away, true)
		var at := _cell_center(c)
		away.append(at)
		var spr = TEAMMATE.instantiate()
		spr.height = miku_height
		spr.setup_strip(looks[rng.randi_range(0, looks.size() - 1)], miku_frames, miku_idle_frames, miku_idle_fps)
		spr.min_light = 1.0 if top_down else character_brightness
		if top_down:
			spr.pixel_size *= top_down_character_scale
		spr.state = "wave"
		add_child(spr)
		spr.global_position = at
		var body := StaticBody3D.new()
		body.collision_layer = 2   # the interact ray
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45
		cyl.height = miku_height + 0.3
		shape.shape = cyl
		shape.position.y = miku_height * 0.5
		body.add_child(shape)
		body.set_meta("miku", i)
		spr.add_child(body)
		miku_list.append({"sprite": spr, "body": body, "leader": null})


# Asked along: she follows this player
func take_miku(p, body: Node3D) -> void:
	var i: int = body.get_meta("miku")
	if i < 0 or i >= miku_list.size():
		return
	_miku_follows(miku_list[i], p)
func _miku_follows(mk: Dictionary, leader) -> void:
	mk.leader = leader
	mk.sprite.state = "wave"   # her idle, even on the move
	mk.sprite.path.clear()
	var ahead := 0   # walks behind your teammates
	if leader is Node and leader == player:
		ahead = followers.size()
	for other in miku_list:
		if other != mk and other.leader == leader:
			ahead += 1
	mk.sprite.gap = miku_gap * (ahead + 1)
	mk.body.collision_layer = 0
	for p in players:
		if p.looking_at == mk.body:
			p.looking_at = null


# Where her leader's feet are, or null if she's on her own again
func _miku_leader_at(mk: Dictionary, leaving := false):
	var l = mk.leader
	if l is Node:
		if is_instance_valid(l) and not l.dead and (leaving or not l.escaped):
			return l.global_position
	return null


func _update_mikus(cam: Camera3D, delta: float) -> void:
	for mk in miku_list:
		var spr = mk.sprite
		var light := _light_at(spr.global_position + Vector3(0, 0.6, 0))
		var view: Camera3D = mk.leader.cam if mk.leader is Node and is_instance_valid(mk.leader) else cam
		if mk.leader == null:
			spr.drive(spr.global_position, cam, light, delta, "wave")
			continue
		var at = _miku_leader_at(mk)
		if at == null:
			# Whoever she was with is gone
			mk.leader = null
			mk.body.collision_layer = 2
			continue
		spr.follow(at, view, light, delta)


# The doors have shut
func _count_mikus() -> void:
	var saved := 0
	for mk in miku_list:
		if mk.leader == null:
			continue
		var at = _miku_leader_at(mk, true)
		if in_escape(mk.sprite.global_position) or (at != null and in_escape(at)):
			saved += 1
	if saved == 0:
		return
	Test.mikus_saved += saved
	for p in players:
		if in_escape(p.global_position):
			p.prompt.text = "+%d" % (saved * Test.MIKU_SCORE)
			p.prompt.modulate = Color(0.55, 1.0, 0.95)


# Salvaging and escaping
func try_salvage(p, node: Node3D) -> void:
	var kind: Array = node.get_meta("item")
	if p.rings < kind[1]:
		return
	p.rings -= kind[1]
	p.carried.append(kind)
	_remove_item(node)
	p.add_item_icon(_item_texture(kind))


var items_taken := 0   # picked up this visit, by anyone
func slender_anger() -> float:
	return 1.0 + slender_anger_per_item * items_taken


func _remove_item(node: Node3D) -> void:
	if is_instance_valid(node) and not node.get_meta("taken", false):
		items_taken += 1
	if is_instance_valid(node):
		node.visible = false
		node.collision_layer = 0
		node.set_meta("taken", true)


# Someone pressed ESCAPE in the exit elevator
func press_escape(p) -> void:
	if departing or leaving or emerald_taken:
		return
	_depart(p.index + 1)


var _depart_tweens: Array = []
var _depart_go := 0   # which departure this is


func _depart(by: int) -> void:
	if departing:
		return
	departing = true
	_depart_go += 1
	var go := _depart_go
	_depart_tweens.clear()
	_show_depart_countdown(by)
	for d in exit_doors:
		d.set_meta("open_pos", d.position.x)
		var t := create_tween()
		t.tween_property(d, "position:x", d.get_meta("closed_x"), depart_time)
		_depart_tweens.append(t)
	for p in players:
		p.prompt.text = ""
	await get_tree().create_timer(depart_time).timeout
	if go != _depart_go or not departing:
		return   # called off: someone took the Chaos Emerald
	# Doors shut: whoever is inside gets out with their items
	for p in players:
		if p.dead:
			continue
		p.escaped = true
		p.prompt.text = ""
		if in_exit_car(p.global_position):
			_apply_upgrades(p)
	_count_mikus()
	_leave()


# Everyone sees how long until the doors shut
func _show_depart_countdown(by: int) -> void:
	var label := Label.new()
	label.name = "DepartCountdown"
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 40
	label.offset_bottom = 140
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", depart_countdown_size)
	label.add_theme_color_override("font_color", TAG_COLORS[(by - 1) % TAG_COLORS.size()] if by > 0 else Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	fade.get_parent().add_child(label)
	fade.get_parent().move_child(label, fade.get_index())   # under the fade out
	var t := create_tween()
	t.tween_method(func(left: float): label.text = str(maxi(ceili(left), 0)), depart_time, 0.0, depart_time)
	t.tween_callback(label.queue_free)
	_depart_tweens.append(t)
	_depart_label = label


var _depart_label: Label


# The Chaos Emerald was taken while the doors were closing
func _cancel_depart() -> void:
	if not departing or leaving or _chaos_escape:
		return
	departing = false
	_depart_go += 1
	for t in _depart_tweens:
		if t and t.is_valid():
			t.kill()
	_depart_tweens.clear()
	if is_instance_valid(_depart_label):
		_depart_label.queue_free()
	for d in exit_doors:
		create_tween().tween_property(d, "position:x", d.get_meta("open_pos", d.position.x), 0.6)


# Escaped with these
func _apply_upgrades(p) -> void:
	Test.salvage_items += p.carried.size()
	var skip := 0
	for kind in p.carried:
		var amount: int = kind[7] if kind.size() > 7 else 0
		match int(kind[2]):
			SalvageItem.Effect.RINGS:
				p.rings += amount
			SalvageItem.Effect.SKIP_FLOORS:
				skip += amount
			_:
				kind[9].give()   # the rest last the whole run
	p.carried.clear()
	if skip > 0:
		skip_floors += skip
func _leave() -> void:
	if leaving:
		return
	leaving = true
	for p in players:
		p.show_result(p.escaped and not p.dead)
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(fade, "color:a", 1.0, 1.0)
	t.tween_callback(_return_to_rest)


func _return_to_rest() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Test.salvage_danger = false
	# Rebuild the rest area when the level reloads
	var lg = load("res://Scripts/Level/level_generator.gd")
	lg.rest_done_level = -1
	if skip_floors > 0:
		Test.level = SalvageItem.skipped_to(Test.level, skip_floors)
	# Once per rest area, even the one a floor skip lands you in
	Test.salvage_done_level = Test.level
	Test.back_from_salvage = true
	get_tree().change_scene_to_file(RETURN_SCENE)

# Painted words are lit like the walls around them
func _update_signs() -> void:
	for entry in sign_labels:
		var l: Label3D = entry[0]
		var b := _light_at(l.global_position)
		l.modulate = entry[1] * (0.35 + 0.65 * b) * minf(b * 3.0, 1.0)
		l.modulate.a = 1.0
		l.outline_modulate = l.modulate


# Pick this visit's hunters
func _build_hunters() -> void:
	var pool: Array = []
	for i in 9:
		if hunters & (1 << i):
			pool.append(i)
	var count := 1 if Test.level >= hunters_from_floor or Test.level in hunter_floors else 0
	for f in more_hunters_at_floors:
		if Test.level >= f:
			count += 1
	if Test.salvage_danger:
		if count == 0:
			count = danger_early_hunters
		elif Test.level >= danger_extra_from_floor:
			count += danger_extra_hunters
	if Test.level < three_hunters_from_floor:
		count = mini(count, 2)
	if Test.level in no_hunter_floors:
		count = 0
	count = mini(count, pool.size())
	var chosen: Array = []
	for n in count:
		chosen.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	if slender_alone and chosen.has(1):
		chosen = [1]   # Slender Man hunts alone
	for kind in chosen:
		if kind != 6:
			_add_hunter(kind)
	if chosen.has(6):
		_add_clones(chosen.filter(func(k): return k != 6 and k != 1 and k != 7 and k != 8))


# The Clone's crowd
func _add_clones(real: Array) -> void:
	var looks: Array = real.duplicate()
	if looks.is_empty():
		for k in [0, 2, 3, 4, 5]:
			if hunters & (1 << k):
				looks.append(k)
	if looks.is_empty():
		looks = [0]
	var room := far_cell_from([_cell_center(Vector2i.ZERO), _cell_center(exit_cell)])
	var cells: Array = [room]
	var edge: Array = [room]
	for step in clone_spread:
		var next: Array = []
		for c in edge:
			for n in _neighbours(c):
				if not cells.has(n) and not stair.has(n) and not hazards.has(n):
					cells.append(n)
					next.append(n)
		edge = next
	for i in clone_count:
		var kind: int = looks[i % looks.size()] if i < looks.size() else looks[rng.randi_range(0, looks.size() - 1)]
		var c: Vector2i = room if i < maxi(clone_count / 2, 1) else cells[rng.randi_range(0, cells.size() - 1)]
		var at := _cell_center(c) + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
		at.y = _floor_at(c, at)
		var look := _hunter_look(kind)
		var mon = CLONE.new()
		mon.height = look[1]
		mon.sight_range = hunter_sight_range
		mon.view_dot = cos(deg_to_rad(hunter_view_angle))
		mon.kind_index = monsters.size()
		mon.spawn_after = 0.0
		add_child(mon)
		mon.setup(self, look[0] if look[0] else mon.placeholder())
		if top_down:
			mon.pixel_size *= top_down_character_scale if kind == 3 else top_down_hunter_scale
			mon.min_shade = top_down_hunter_brightness
		mon.global_position = at
		mon.visible = true
		mon.state = mon.STALK
		mon.set_meta("met", true)          # never put in your way
		mon.set_meta("put_in_way", true)
		mon.set_meta("copy_of", kind)
		monsters.append(mon)


# The Mimic got someone
var _next_mimic := ""

func mimic_caught(w: Dictionary) -> void:
	if not mimic_spreads:
		return
	var who: String = ""
	var id := -1
	if w.local:
		who = w.local.character
		w.local.set_meta("mimicked", true)
	if who == "":
		who = "Sonic"
	var local_i := players.find(w.local) if w.local else -1
	await get_tree().create_timer(mimic_rise_after).timeout
	if leaving or not is_inside_tree():
		return
	var at := _mimic_body_at(local_i, id)
	_mimic_rises(who, at, local_i, id)


# Where the body lies now
func _mimic_body_at(local_i: int, id: int) -> Vector3:
	var body: Node3D = null
	var at := Vector3.ZERO
	if local_i >= 0 and local_i < players.size():
		body = players[local_i].ragdoll if is_instance_valid(players[local_i].ragdoll) else null
		at = players[local_i].global_position
	if body:
		at = body.global_position
		body.visible = false
	return at


func _mimic_rises(who: String, at: Vector3, local_i: int, id: int) -> void:
	if local_i >= 0 and local_i < players.size():
		players[local_i].set_meta("mimicked", true)
	var c := Vector2i(roundi(at.x / cell_size), roundi(at.z / cell_size))
	at.y = _floor_at(clamp_cell(c), at)
	_next_mimic = who
	var mon = _add_hunter(7)
	_next_mimic = ""
	mon.spawn(at)
	mon.spawn_after = time - hunter_settle_time + 3.0   # it stands a moment, then hunts
	mon.set_meta("met", true)
	mon.set_meta("put_in_way", true)


# Where the Spider waits
func _spider_lairs() -> Array:
	var out: Array = []
	for c in hazards:
		if hazards[c] == pit_chunk:
			out.append(c)
	if out.is_empty():
		var straight: Array = []
		for x in range(maze_lo.x, maze_lo.x + maze_size.x):
			for z in range(maze_lo.y, maze_lo.y + maze_size.y):
				var c := Vector2i(x, z)
				if _neighbours(c).size() == 2 and not stair.has(c) and absi(c.x) + absi(c.y) > 2:
					straight.append(c)
		for i in mini(2, straight.size()):
			out.append(straight.pop_at(rng.randi_range(0, straight.size() - 1)))
	return out


# Who the Mimic copies
func _mimic_character() -> String:
	var names: Array = []
	for p in players:
		names.append(p.character)
	names = names.filter(func(n): return n != "")
	if names.size() < 2:
		names = Array(Content.character_ids())
	names.sort()
	return str(names[rng.randi_range(0, names.size() - 1)]) if not names.is_empty() else "Sonic"


# ROOM's jumpscare frames
var _room_frame_cache: Array = []

func _room_frames() -> Array:
	if not _room_frame_cache.is_empty() or room_scare_frames == "":
		return _room_frame_cache
	var names: Array = []
	for f in ResourceLoader.list_directory(room_scare_frames):
		if f.ends_with(".jpg") or f.ends_with(".png"):
			names.append(f)
	names.sort()
	for f in names:
		var tex = load(room_scare_frames.path_join(f))
		if tex is Texture2D:
			_room_frame_cache.append(tex)
	return _room_frame_cache


# What a kind of hunter looks like
func _hunter_look(kind: int) -> Array:
	match kind:
		0: return [bracken_texture, bracken_height]
		2: return [freddy_texture, freddy_height]
		3: return [tails_doll_texture, tails_doll_height]
		4: return [room_texture, room_height]
		5: return [mx_texture, mx_height]
	return [bracken_texture, bracken_height]


# One hunter of this kind
func _add_hunter(kind: int) -> Node3D:
	var mon: Sprite3D
	var tex: Texture2D
	match kind:
		0:
			mon = BRACKEN.new()
			mon.anger_time = bracken_anger_time
			mon.angry_time = bracken_angry_time
			mon.stalk_speed = bracken_stalk_speed
			mon.charge_speed = bracken_charge_speed
			mon.flee_speed = bracken_flee_speed
			mon.corner_distance = bracken_corner_distance
			mon.cool_rate = bracken_cool_rate
			mon.carry_time = bracken_carry_time
			mon.drag_to_den = bracken_drags_to_den
			mon.drag_speed = bracken_drag_speed
			mon.hush_time = bracken_hush_time
			mon.bold_max = bracken_bold_max
			mon.bold_step = bracken_bold_step
			mon.height = bracken_height
			tex = bracken_texture
			bracken = mon
		1:
			mon = SLENDER.new()
			mon.fill_time = slender_fill_time
			mon.teleport_every = slender_teleport_every
			mon.start_cells = slender_start_cells
			mon.vanish_time = slender_vanish_time
			mon.clear_rate = slender_clear_rate
			mon.near_range = slender_near_range
			mon.near_rate = slender_near_rate
			mon.static_strength = slender_static_strength
			mon.height = slender_height
			tex = slender_texture
		2:
			mon = FREDDY.new()
			mon.walk_speed = freddy_walk_speed
			mon.dark_speed = freddy_dark_speed
			mon.dark_level = freddy_dark_level
			mon.rest_time = freddy_rest_time
			mon.height = freddy_height
			tex = freddy_texture
		4:
			mon = ROOM.new()
			mon.chase_speed = room_speed
			mon.skip_every = room_skip_every
			mon.lunge_range = room_lunge_range
			mon.lunge_speed = room_lunge_speed
			mon.twitch = room_twitch
			mon.smear = room_smear
			mon.rest_time = room_rest_time
			mon.static_range = room_static_range
			mon.static_strength = room_static_strength
			mon.height = room_height
			tex = room_texture
		8:
			mon = SPIDER.new()
			mon.emerge_range = spider_emerge_range
			mon.emerge_chance = spider_emerge_chance
			mon.crawl_speed = spider_crawl_speed
			mon.return_after = spider_return_after
			mon.roam_speed = spider_roam_speed
			mon.rush_speed = spider_rush_speed
			mon.hear_range = spider_hear_range
			mon.quiet_speed = spider_quiet_speed
			mon.size = spider_size
			mon.body = spider_body
			mon.lairs = _spider_lairs()
			mon.lairs_all = mon.lairs.duplicate()
			mon.drag_speed = spider_drag_speed
			mon.drop_chance = spider_drop_chance
			mon.listen_time = spider_listen_time
			mon.set_meta("met", true)
			mon.set_meta("put_in_way", true)
			tex = spider_texture
		7:
			mon = MIMIC.new()
			mon.character = _next_mimic if _next_mimic != "" else _mimic_character()
			mon.walk_speed = mimic_walk_speed
			mon.lunge_speed = mimic_lunge_speed
			mon.lunge_range = mimic_lunge_range
			mon.spot_range = mimic_spot_range
			mon.lose_time = mimic_lose_time
			mon.rest_time = mimic_rest_time
			mon.string_range = mimic_string_range
			mon.stare_time = mimic_stare_time
			mon.ceiling = wall_height
		5:
			mon = MX.new()
			mon.mario_frames = mx_mario_frames
			mon.mario_height = mx_mario_height
			mon.mario_speed = mx_mario_speed
			mon.mx_texture = mx_texture
			mon.mx_chase_texture = mx_chase_texture
			mon.transform_after = mx_transform_after
			mon.transform_sound = mx_transform_sound
			mon.roam_speed = mx_roam_speed
			mon.chase_speed = mx_chase_speed
			mon.spot_range = mx_spot_range
			mon.spot_angle = mx_spot_angle
			mon.lose_time = mx_lose_time
			mon.voicelines = mx_voicelines
			mon.voice_time = mx_voice_time
			mon.rest_time = mx_rest_time
			mon.mx_height = mx_height
			mon.height = mx_height
			tex = mx_mario_frames[0] if not mx_mario_frames.is_empty() else null
		_:
			mon = TAILS_DOLL.new()
			mon.appear_every = tails_doll_appear_every
			mon.show_for = tails_doll_show_for
			mon.look_time = tails_doll_look_time
			mon.vanish_distance = tails_doll_vanish_distance
			mon.chase_speed = tails_doll_chase_speed
			mon.chase_time = tails_doll_chase_time
			mon.chase_chance = tails_doll_chase_chance
			mon.sightings_first = tails_doll_sightings
			mon.sightings_after = tails_doll_sightings_after
			mon.laugh_sound = tails_doll_laugh_sound
			mon.hover = tails_doll_hover
			mon.touch_distance = tails_doll_touch_distance
			mon.front_only = tails_doll_front_only
			mon.hallucinate = tails_doll_hallucinations
			mon.hallucinate_every = tails_doll_hallucinate_every
			mon.hallucination_speed = tails_doll_hallucination_speed
			mon.height = tails_doll_height
			tex = tails_doll_texture
	mon.sight_range = hunter_sight_range
	mon.view_dot = cos(deg_to_rad(hunter_view_angle))
	mon.hide_range = hidden_safe_distance
	mon.kill_distance = hunter_catch_distance
	mon.kind_index = monsters.size()
	mon.spawn_after = first_hunter_after + next_hunter_after * monsters.size()
	add_child(mon)
	mon.setup(self, tex if tex else mon.placeholder())
	if mon is SLENDER and slender_model:
		mon.use_model(slender_model)
	if top_down:
		mon.pixel_size *= top_down_character_scale if mon is TAILS_DOLL else top_down_hunter_scale   # the doll stays the size of a player
		mon.min_shade = top_down_hunter_brightness
	monsters.append(mon)
	return mon


func _update_hunters(delta: float) -> void:
	if monsters.is_empty() or leaving:
		return
	_update_watchers(delta)
	var list := watchers.values()
	for mon in monsters:
		mon.alarm_left -= delta
		if mon.stunned_left > 0.0:
			mon.stunned_left -= delta
			mon.modulate = stun_color if fmod(time, 0.2) < 0.13 else Color.WHITE
			continue   # frozen: no moving, no catching
		if mon is FREDDY:
			_freddy_steps(mon)
		elif mon is MX and not mon.disguised:
			_freddy_steps(mon, mx_stride, mx_stomp, mx_stomp_range, mx_step_pitch, mx_step_volume)
		# Each turns up a while in, once someone is down in the maze, far from everyone
		if not mon.visible and mon.state == mon.WAIT and time > mon.spawn_after:
			var down: Array = []
			for w in list:
				if w.alive and mon._in_maze(w.feet):
					down.append(w.feet)
			if not down.is_empty():
				if mon.get_script() == BRACKEN and bracken_from_behind:
					var them: Array = list.filter(func(w): return w.alive and mon._in_maze(w.feet))
					mon.spawn(_behind(mon, them[rng.randi_range(0, them.size() - 1)], list))
				else:
					mon.spawn(_cell_center(far_cell_from(down)))
		mon.update(delta, list)
	_meet_before_exit(list, delta)
	# Slender Man's static, on each local player's screen
	for i in players.size():
		var w = watchers.get("local%d" % i)
		if w:
			players[i].set_static(w.static)


# Somewhere a couple of corridors behind this player, out of everyone's sight
func _behind(mon: Node3D, w: Dictionary, list: Array) -> Vector3:
	var from: Vector2i = mon._cell(w.feet)
	var fwd := Vector2(w.forward.x, w.forward.z).normalized()
	var best := from
	var best_score := INF
	for steps in [bracken_behind_cells, bracken_behind_cells + 1, bracken_behind_cells - 1]:
		for c in mon._cells_at(from, maxi(steps, 1)):
			var at := _cell_center(c)
			var dir := Vector2(at.x - w.feet.x, at.z - w.feet.z).normalized()
			var score := fwd.dot(dir)   # -1 = straight behind
			mon.global_position = at
			if list.any(func(o): return o.alive and mon._sees_me(o)):
				score += 10.0   # someone would see it turn up
			if score < best_score:
				best_score = score
				best = c
		if best_score < -0.3:
			break
	return _cell_center(best)


# Nobody reaches the elevator without having met every hunter on the floor
var _meet_check := 0.0
func _meet_before_exit(list: Array, delta: float) -> void:
	if meet_before_exit <= 0 or departing:
		return
	for mon in monsters:
		if not mon.visible or mon.get_meta("met", false):
			continue
		for w in list:
			if w.alive and (mon._sees_me(w) or mon._flat_dist(w.feet) < 4.0):
				mon.set_meta("met", true)
				break
	_meet_check -= delta
	if _meet_check > 0.0:
		return
	_meet_check = 0.5
	for mon in monsters:
		if mon.get_meta("met", false) or mon.get_meta("put_in_way", false):
			continue
		for w in list:
			if not w.alive or not mon._in_maze(w.feet):
				continue
			var from: Vector2i = mon._cell(w.feet)
			var way: Array[Vector2i] = mon._route(from, exit_cell)
			if way.is_empty() or way.size() > meet_before_exit:
				continue
			if mon.visible and list.any(func(o): return o.alive and mon._sees_me(o)):
				continue   # never jumps while someone's looking
			var at := _cell_center(way[clampi(2, 0, maxi(way.size() - 2, 0))])
			if mon.get_script() == BRACKEN and bracken_from_behind:
				at = _behind(mon, w, list)   # the Bracken comes up behind you, not ahead
			mon.set_meta("put_in_way", true)
			if not mon.visible:
				mon.spawn_after = time   # turns up now, and wanders a while before it hunts
				mon.spawn(at)
			elif mon is TAILS_DOLL:
				mon.next_in = 0.0   # it shows itself to whoever it haunts, now
			else:
				mon.global_position = at
			break


# Freddy is heavy
func _freddy_steps(mon: Node3D, stride := -1.0, stomp := -1.0, stomp_range := -1.0, pitch := -1.0, volume := -1.0) -> void:
	# MX stomps too, with its own settings
	if stride < 0.0:
		stride = freddy_stride
		stomp = freddy_stomp
		stomp_range = freddy_stomp_range
		pitch = freddy_step_pitch
		volume = freddy_step_volume
	var at: Vector3 = mon.global_position
	var last: Vector3 = mon.get_meta("last_step_at", at)
	mon.set_meta("last_step_at", at)
	if not mon.visible or (stomp <= 0.0 and volume <= 0.0):
		return
	var walked: float = mon.get_meta("walked", 0.0) + Vector2(at.x - last.x, at.z - last.z).length()
	if walked > 3.0:
		walked = 0.0   # he appeared somewhere, he didn't walk there
	if walked < stride:
		mon.set_meta("walked", walked)
		return
	mon.set_meta("walked", 0.0)
	var loudest := 0.0
	for p in players:
		var near := clampf(1.0 - p.cam.global_position.distance_to(at) / stomp_range, 0.0, 1.0)
		if near > 0.0:
			loudest = maxf(loudest, lerpf(freddy_stomp_far, 1.0, near * near))
			if stomp > 0.0:
				p.add_shake(lerpf(freddy_stomp_far, 1.0, near * near) * stomp * camera_shake)
	var stomps := freddy_step_sounds.filter(func(s): return s != null)
	if loudest > 0.0 and volume > 0.0 and not stomps.is_empty():
		var snd := AudioStreamPlayer.new()
		snd.stream = stomps[randi() % stomps.size()]
		snd.bus = _blast_bus()
		snd.pitch_scale = pitch * randf_range(0.93, 1.07)
		snd.volume_db = linear_to_db(loudest * volume)
		add_child(snd)
		snd.play()
		snd.finished.connect(func(): get_tree().create_timer(2.0).timeout.connect(snd.queue_free))   # let the echo ring out


# Everyone the hunters deal with
func _update_watchers(delta: float) -> void:
	for i in players.size():
		var p = players[i]
		var key := "local%d" % i
		if not watchers.has(key):
			watchers[key] = {"key": key, "alive": true, "local": p, "id": 0, "feet": p.global_position, "speed": 0.0}
		var w: Dictionary = watchers[key]
		w.alive = not p.dead and not p.escaped and not in_exit_car(p.global_position)   # safe in the elevator
		w.sight = lerpf(64.0, fog_sight, fog_at(p.global_position))
		w.speed = lerpf(w.speed, Vector2(p.global_position.x - w.feet.x, p.global_position.z - w.feet.z).length() / maxf(delta, 0.001), clampf(delta * 6.0, 0.0, 1.0))
		w.static = 0.0
		w.feet = p.global_position
		w.eye = p.head.global_position
		w.forward = -p.head.global_transform.basis.z
		w.hidden = p.hidden
		w.sheltered = p.sheltered
# The maze cell furthest from all these points
func far_cell_from(points: Array, safe := false) -> Vector2i:
	var dist := {}
	var queue: Array[Vector2i] = []
	for pt in points:
		var c := clamp_cell(Vector2i(roundi(pt.x / cell_size), roundi(pt.z / cell_size)))
		dist[c] = 0
		queue.append(c)
	var far := queue[0] if not queue.is_empty() else Vector2i.ZERO
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] > dist[far] and c != exit_cell and not (safe and (hazards.has(c) or stair.has(c))):
			far = c
		for n in _neighbours(c):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return far


# Who a caught player can watch
func spectate_targets(viewer: Node3D) -> Array:
	var out := []
	if not spectate:
		return out
	for p in players:
		if p != viewer and not p.dead and not p.escaped:
			out.append(p)
	return out

# A hunter got someone
func monster_kill(w: Dictionary, mon: Node3D) -> void:
	if in_exit_car(w.feet):
		return   # nothing gets you in the elevator
	if in_narrow(w.feet):
		return   # ...or in a narrow corridor
	if mon.stunned_left > 0.0:
		return
	# The Survive item
	if w.local and Test.salvage_saves > 0:
		Test.salvage_saves -= 1
		_survived(w.local, mon)
		return
	var fling := _fling(mon.global_position, w.feet, hunter_fling)
	if w.local:
		var static_death: bool = jumpscares and slender_static_death and mon is SLENDER
		var doll_scare: bool = jumpscares and tails_doll_jumpscare != null and mon is TAILS_DOLL
		var room_scare: bool = jumpscares and room_jumpscare != null and mon is ROOM
		var snap: bool = jumpscares and bracken_neck_snap and mon.get_script() == BRACKEN
		if mon is SPIDER:
			# Pulled down its pit
			kill_player(w.local, Vector3(0, -3.0, 0), true)
			_check_all_out()
			return
		if snap:
			w.local.own_death = bracken_snap_black
		elif static_death:
			w.local.own_death = slender_death_fall + slender_death_thick
		elif doll_scare or room_scare:
			w.local.own_death = 0.0
		kill_player(w.local, fling, not (static_death or doll_scare or room_scare or snap))   # no watching yourself fly
		if snap:
			w.local.neck_snap(bracken_snap_sound, bracken_snap_black, mon.texture, bracken_snap_crack_at)
		elif static_death:
			w.local.slender_death(self)
		elif doll_scare:
			w.local.still_scare(tails_doll_jumpscare, jumpscare_sound, tails_doll_jumpscare_cut, tails_doll_jumpscare_hold, tails_doll_jumpscare_quiet)
		elif room_scare:
			var frames := _room_frames()
			if not frames.is_empty():
				w.local.anim_scare(frames, room_scare_fps, room_scare_sound, 0.0)   # the video: it rushes you, right into your face
			else:
				w.local.still_scare(room_jumpscare, room_theme.resource_path if room_theme else "", room_jumpscare_hold, room_jumpscare_hold, 0.0)   # its theme, loud
		else:
			_jumpscare(w.local, mon)
	_check_all_out()


# The Spider has hold of someone
func spider_hold(w: Dictionary, mon: Node3D, on: bool) -> void:
	if w.local:
		w.local.grabbed_by = mon if on else null
# Did a hunter's kill go through?
func watcher_dead(w: Dictionary) -> bool:
	if w.local:
		return w.local.dead
	return false


# Where a caught player's body lies
func body_of(w: Dictionary) -> RigidBody3D:
	if w.local:
		return w.local.ragdoll if is_instance_valid(w.local.ragdoll) else null
	return null


# Away from what killed them, and up
func _fling(from: Vector3, to: Vector3, strength: float) -> Vector3:
	var away := Vector3(to.x - from.x, 0, to.z - from.z)
	if away.length() < 0.05:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return away.normalized() * strength + Vector3.UP * strength * 0.6

func _jumpscare(p, mon: Node3D) -> void:
	if jumpscares and mon:
		var sound := jumpscare_sound
		if mon is FREDDY and freddy_jumpscare_sound != "":
			sound = freddy_jumpscare_sound
		p.jumpscare(mon.texture, sound, jumpscare_time, jumpscare_flash, jumpscare_linger, freddy_jumpscare_aim if mon is FREDDY else (tails_doll_jumpscare_aim if mon is TAILS_DOLL else 0.0))

# Everything a player was carrying spills out around where they died
var _drops := 0
func _drop_items(p) -> void:
	if p.carried.is_empty():
		return
	var at: Vector3 = p.global_position
	var spots := _drop_spots(at, p.carried.size())
	var sent := []
	for i in p.carried.size():
		var id := "d%d_%d" % [p.index, _drops]
		_drops += 1
		_spawn_drop(p.carried[i], at, spots[i], id)
		sent.append([p.carried[i][0], id, snappedf(spots[i].x, 0.01), snappedf(spots[i].y, 0.01), snappedf(spots[i].z, 0.01)])
	p.carried.clear()
	p.clear_item_icons()


# Where spilled items land
func _drop_spots(at: Vector3, count: int) -> Array:
	var c := clamp_cell(Vector2i(roundi(at.x / cell_size), roundi(at.z / cell_size)))
	var base := at
	if hazards.get(c) == pit_chunk or at.y < _floor_at(c, at) - 1.0:
		var ways := _neighbours(c)
		var to: Vector2i = ways[0] if not ways.is_empty() else c
		base = _cell_center(to)
		c = to
	var mid := _cell_center(c)
	var out := []
	for i in count:
		var ang := TAU * i / count + randf_range(-0.4, 0.4)
		var spot := base + Vector3(cos(ang), 0, sin(ang)) * randf_range(0.5, 1.3)
		spot.x = clampf(spot.x, mid.x - 1.5, mid.x + 1.5)
		spot.z = clampf(spot.z, mid.z - 1.5, mid.z + 1.5)
		if hazards.get(c) == spike_chunk:
			# not in among the spikes
			var ways := _neighbours(c)
			var along := Vector3(ways[0].x - c.x, 0, ways[0].y - c.y) if not ways.is_empty() else Vector3.FORWARD
			var off := (spot - mid).dot(along)
			if absf(off) < 0.9:
				spot += along * ((0.9 if off >= 0.0 else -0.9) - off)
		spot.y = _floor_at(c, spot)
		out.append(spot)
	return out


# A spilled item, flying out in an arc to where it lands
func _spawn_drop(kind: Array, from: Vector3, to: Vector3, id: String) -> void:
	var k := kind.duplicate()
	k[1] = 0
	var node := _make_item(k, from + Vector3(0, 0.8, 0), false)
	node.set_meta("id", id)
	item_nodes.append(node)
	var start := node.position
	var arc := randf_range(1.0, 1.8)
	var t := node.create_tween()
	t.tween_method(func(f: float):
		node.position = start.lerp(to, f) + Vector3.UP * sin(f * PI) * arc, 0.0, 1.0, 0.6)


# A dead character's sprite as a tumbling physics body
func _ragdoll_sprite(spr: Sprite3D, fling: Vector3, body: RigidBody3D = null) -> void:
	if not ragdolls:
		return
	if body == null:
		body = _ragdoll_body(spr.global_position + Vector3(0, 0.6, 0), fling, 0.3)
	body.collision_layer = 0
	# One card that always faces whoever's looking, spinning out of control
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	card.mesh = quad
	card.extra_cull_margin = 2.0   # the shader moves its corners
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.layers = spr.layers
	var mat := ShaderMaterial.new()
	mat.shader = RAGDOLL_CARD
	var cell := Vector2(spr.texture.get_size()) / Vector2(spr.hframes, spr.vframes)
	mat.set_shader_parameter("sheet", spr.texture)
	mat.set_shader_parameter("size", cell * spr.pixel_size)
	mat.set_shader_parameter("flip", spr.flip_h)
	card.material_override = mat
	card.set_meta("cells", Vector2i(spr.hframes, spr.vframes))
	card.set_meta("spin", randf() * TAU)
	card.set_meta("way", 1.0 if randf() < 0.5 else -1.0)
	body.add_child(card)
	_card_frame(card, spr.frame)
	ragdoll_cards.append(card)
	_play_hurt(card, spr)


func _card_frame(card: MeshInstance3D, frame: int) -> void:
	var cells: Vector2i = card.get_meta("cells")
	var at := Vector2(frame % cells.x, frame / cells.x) / Vector2(cells)
	(card.material_override as ShaderMaterial).set_shader_parameter("region", Vector4(at.x, at.y, 1.0 / cells.x, 1.0 / cells.y))


# A flung body plays the character's hurt animation, then holds its last frame
func _play_hurt(card: MeshInstance3D, from: Sprite3D) -> void:
	var anims = from.get("anims")
	if not (anims is Dictionary) or not anims.has("hurt"):
		return
	var frames: Array = anims["hurt"][0]
	var fps: float = anims["hurt"][1]
	_card_frame(card, frames[0])
	if frames.size() < 2:
		return
	var t := card.create_tween()
	for f in range(1, frames.size()):
		t.tween_interval(1.0 / maxf(fps, 1.0))
		t.tween_callback(_card_frame.bind(card, frames[f]))


func _ragdoll_body(at: Vector3, fling: Vector3, radius: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.linear_damp = 0.3
	body.angular_damp = 0.6
	var pm := PhysicsMaterial.new()
	pm.bounce = ragdoll_bounce
	pm.friction = 0.8
	body.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	body.linear_velocity = fling
	body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * ragdoll_spin
	return body


# It's charging at someone
func bracken_angry(_w: Dictionary) -> void:
	pass


func kill_player(p, fling := Vector3.ZERO, watch_body := true) -> void:
	if p.dead:
		return
	_end_knockdown(p, false)
	_drop_items(p)
	if p.get("has_emerald"):
		p.has_emerald = false
		var spot: Vector3 = _drop_spots(p.global_position, 1)[0]
		_drop_emerald(spot)
	p.die()
	if p.own_death != 0.0 and ResourceLoader.exists(ring_loss_sound):   # not in Tails Doll's silence
		var snd := AudioStreamPlayer.new()
		snd.stream = load(ring_loss_sound)
		snd.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
	if ragdolls:
		# Your body goes flying and your camera pulls back to watch it go
		var i := players.find(p)
		var own: int = 1 << (1 + i)   # the layer only your partner normally sees
		p.ragdoll = _ragdoll_body(p.global_position + Vector3(0, 0.6, 0), fling, 0.3)
		if partner_sprites.has(i) and is_instance_valid(partner_sprites[i]):
			_ragdoll_sprite(partner_sprites[i], fling, p.ragdoll)
		else:
			var me = _make_sprite(p.character, own)
			if me:
				me.global_position = p.global_position
				_ragdoll_sprite(me, fling, p.ragdoll)
				me.queue_free()
		if ragdoll_third_person and watch_body:
			p.cam.cull_mask |= own
			p.third_person(ragdoll_camera_distance)
	_check_all_out()


# Hit and lived
func knock_down(p, fling: Vector3) -> void:
	if p.dead or is_instance_valid(p.knocked):
		return
	if not (ragdolls and knockdowns):
		p.hurt(p.global_position - Vector3(fling.x, 0, fling.z), fling.length() * 0.7, 4.5)
		return
	var i := players.find(p)
	var own: int = 1 << (1 + i)
	var body := _ragdoll_body(p.global_position + Vector3(0, 0.6, 0), fling, 0.3)
	if partner_sprites.has(i) and is_instance_valid(partner_sprites[i]):
		_ragdoll_sprite(partner_sprites[i], fling, body)
	else:
		var me = _make_sprite(p.character, own)
		if me:
			me.global_position = p.global_position
			_ragdoll_sprite(me, fling, body)
			me.queue_free()
	if ragdoll_third_person:
		p.cam.cull_mask |= own
	p.knock_down(body, ragdoll_camera_distance if ragdoll_third_person else 0.0)
	p.hurt_left = knockdown_time + 1.0   # and a moment after getting up
	_knocked[p] = knockdown_time


func _update_knockdowns(delta: float) -> void:
	for p in _knocked.keys():
		_knocked[p] -= delta
		var body: RigidBody3D = p.knocked
		if not is_instance_valid(body):
			_knocked.erase(p)
			continue
		# Up once the time's passed and you've about stopped rolling
		if _knocked[p] <= 0.0 and (body.linear_velocity.length() < 1.2 or _knocked[p] < -1.5):
			_end_knockdown(p, true)


func _end_knockdown(p, stand_up: bool) -> void:
	_knocked.erase(p)
	if not is_instance_valid(p.knocked):
		return
	var body: RigidBody3D = p.knocked
	if stand_up:
		p.get_up()
	else:
		p.knocked = null
	if not top_down:
		p.cam.cull_mask &= ~(1 << (1 + players.find(p)))
	body.queue_free()


# When everyone has been caught, it's over
func _check_all_out() -> void:
	if _all_out or departing:
		return
	for p in players:
		if not p.dead:
			return
	_wipe_out()


# Everyone was caught
func _wipe_out() -> void:
	if _all_out:
		return
	_all_out = true
	for p in players:
		p.carried.clear()
		p.show_game_over()
	if wipe_out_loses_rings:
		for p in players:
			p.rings = 0
		Test.rings = 0
	if wipe_out_loses_items:
		Test.clear_upgrades()
	get_tree().create_timer(wipe_out_delay).timeout.connect(_leave)
