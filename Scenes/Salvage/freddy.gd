extends "res://Scenes/Salvage/bracken.gd"
# Freddy: only moves while nobody is looking at him, faster in the dark

var rest_left := 0.0

# Set from the Salvage node's Freddy settings
var walk_speed := 7.2            # in the light
var dark_speed := 8.5            # in the dark
var dark_level := 0.2            # below this much lamp light he's in the dark
var rest_time := 4.0             # how long he stands still after catching someone


func update(delta: float, watchers: Array) -> void:
	if not visible:
		return
	_shade()
	if rest_left > 0.0:
		rest_left -= delta
		return
	var alive := _alive(watchers)
	var chest := global_position + Vector3(0, height * 0.6, 0)
	var lamp: float = game.lamp_light_at(chest)
	var in_dark := lamp < dark_level
	# Frozen while anyone at all is looking at him
	var frozen := false
	if not game.emerald_taken:
		for w in alive:
			if _sees_me(w):
				frozen = true
				break
	state = SPOTTED if frozen else STALK
	if not frozen:
		var t = _pick_target(alive)
		if t == null:
			_roam(delta)
		else:
			_chase(t, dark_speed if in_dark else walk_speed, delta)
			if _reach(t):
				_kill(t)


func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	rest_left = 0.0


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	w.alive = false
	path.clear()
	rest_left = rest_time


func placeholder() -> Texture2D:
	return blank_figure(50, 84, Color(0.48, 0.3, 0.17), 0.7, 0.15)   # a wide brown block
