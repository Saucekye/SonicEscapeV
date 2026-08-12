extends Node

signal game_over		## emitted from the playable character to notify scenes that the player ghave game over'd

signal switch_new_active_player(new_player : Player)

signal set_teto_display(enabled : bool)

signal set_teto_animation(animation_name : String)

signal disable_music_player(disabled : bool)

signal disable_boss_ui(disabled : bool)
