extends "res://Scenes/Salvage/bracken.gd"
# Slender Man

var meters := {}                 # watcher key -> 0..1
var target = null
var closeness := 6               # how many cells away from the target he lands next
var tp_left := 6.0
var vanish_left := 0.0

# Set from the Salvage node's Slender Man settings
var fill_time := 4.0             # seconds of looking at him
var teleport_every := 7.0        # seconds between jumps
var start_cells := 6             # how far off he starts each hunt
var vanish_time := 12.0          # how long he's gone after taking someone
var clear_rate := 0.12           # how fast the static clears when you look away
var near_range := 3.0            # this close, the static builds even when you're not looking
var near_rate := 0.3             # how fast it builds then, right beside him
var static_strength := 1.0       # how thick the static looks


func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	target = w
	closeness = 2
	tp_left = 0.5
	vanish_left = minf(vanish_left, 0.5)


func spawn(at: Vector3) -> void:
	super.spawn(at)
	closeness = start_cells
	tp_left = teleport_every


func update(delta: float, watchers: Array) -> void:
	if not visible:
		# Gone after taking someone
		if vanish_left > 0.0:
			vanish_left -= delta
			if vanish_left <= 0.0:
				var alive := _alive(watchers)
				if not alive.is_empty():
					spawn(game._cell_center(game.far_cell_from(alive.map(func(w): return w.feet))))
		return
	_shade()
	var alive := _alive(watchers)
	_fill(delta, alive, true)
	if not visible:
		return
	# Who he's after
	var t = _pick_target(alive)
	if not is_same(t, target):
		target = t
		closeness = start_cells
	# Teleport while nobody's looking
	tp_left -= delta
	if tp_left <= 0.0 and alive.filter(func(w): return _sees_me(w)).is_empty():
		tp_left = teleport_every / game.slender_anger() / game.hunter_speed() * randf_range(0.7, 1.3)   # sooner the more items have been taken
		var from := _cell(target.feet) if target else _cell(global_position)
		var cells := _cells_at(from, closeness if target else 4)
		if not cells.is_empty():
			var c: Vector2i = cells[randi() % cells.size()]
			global_position = game._cell_center(c)
			if target:
				closeness = maxi(closeness - 1, 1)


# Static: looking at him builds it, being right beside him builds it too
func _fill(delta: float, list: Array, can_kill: bool) -> void:
	for w in list:
		if not w.alive:
			continue
		var m: float = meters.get(w.key, 0.0)
		var rate := 0.0
		if visible:
			var d: float = w.eye.distance_to(global_position + Vector3(0, height * 0.6, 0))
			if _sees_me(w):
				rate += lerpf(2.2, 0.5, clampf(d / 20.0, 0.0, 1.0)) / fill_time * game.slender_anger()
			if d < near_range and not w.hidden:
				rate += (1.0 - d / near_range) * near_rate
		if rate > 0.0:
			m = minf(m + rate * delta, 1.0)
		else:
			m = maxf(m - delta * clear_rate, 0.0)
		meters[w.key] = m
		w.static = maxf(w.get("static", 0.0), m * static_strength)
		if settling():
			m = minf(m, 0.85)
			meters[w.key] = m
		if can_kill and m >= 1.0 and not settling():
			_kill(w)


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	w.alive = false
	meters.clear()
	target = null
	# Gone for a while
	visible = false
	vanish_left = vanish_time


func placeholder() -> Texture2D:
	return blank_figure(22, 104, Color(0.62, 0.64, 0.7), 1.0, 0.0)   # a tall grey column
