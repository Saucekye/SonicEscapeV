extends "res://Scenes/Salvage/bracken.gd"
# Tails Doll, haunting like the ghost girl

enum { HIDDEN, SHOWING, CHASING }

const HAUNT_LAYER_BIT := 12      # + local player index

var haunt = null                 # the watcher it's after
var mode := HIDDEN
var mode_left := 0.0             # seconds left showing, or chasing
var next_in := 0.0               # seconds until it turns up again
var looked_at := 0.0             # seconds the haunted player has been looking at it
var chase_odds := 0.0
var bob := 0.0
var _blink := 0.0
var _was_chasing := false
var _laugh: AudioStreamPlayer

# Set from the Salvage node's Tails Doll settings
var hover := 0.2                 # how high it floats
var touch_distance := 0.9        # how close it has to get to catch you
var front_only := true           # only catches you from the front
var appear_every := Vector2(7.0, 15.0)   # seconds between showings
var show_for := 6.0              # how long it stays if nobody looks
var look_time := 0.6             # seconds of looking at it before it vanishes
var vanish_distance := 3.0       # walk this close and it vanishes
var chase_speed := 5.4           # you walk at 4.2 and run faster
var chase_time := 9.0            # how long it keeps after you before giving up
var chase_chance := 0.15         # chance a showing is a chase
var sightings_first := 3         # times the haunted player has to see it before it can come for them
var sightings_after := 1         # and again after each chase it gives up on
var sightings_left := 0          # still to go before it can chase
var seen := false                # the haunted player has seen it this showing
var laugh_sound := ""
var hallucinate := true          # while it haunts you, you see other hunters fly at you
var hallucinate_every := Vector2(8.0, 16.0)
var hallucination_speed := 8.0
var _fake_in := 6.0
var _fakes: Array = []           # [{"node", "life"}]
var _seen_at := -99.0            # when the haunted player last saw it coming


func spawn(at: Vector3) -> void:
	super.spawn(at)
	global_position.y += hover
	_hide()
	next_in = randf_range(appear_every.x, appear_every.y) * 0.5
	chase_odds = chase_chance
	if laugh_sound != "" and ResourceLoader.exists(laugh_sound):
		_laugh = AudioStreamPlayer.new()
		_laugh.stream = load(laugh_sound)
		add_child(_laugh)


func update(delta: float, watchers: Array) -> void:
	if not visible:
		return
	_shade()
	bob += delta * 2.2
	var alive := _alive(watchers)
	if haunt == null or not haunt.alive or not alive.has(haunt):
		_pick_haunt(alive)
	if haunt == null:
		_hide()
		return
	match mode:
		HIDDEN:
			next_in -= delta
			if next_in <= 0.0:
				if sightings_left <= 0 and not settling() and randf() < chase_odds:
					_start_chase()
				else:
					_appear()
		SHOWING:
			mode_left -= delta
			var sees := _sees_me(haunt)
			seen = seen or sees
			looked_at = looked_at + delta if sees else maxf(looked_at - delta, 0.0)
			if looked_at >= look_time or _flat_dist(haunt.feet) < vanish_distance or mode_left <= 0.0:
				if seen:
					sightings_left -= 1   # one it showed up for but they never saw doesn't count
				_hide()
		CHASING:
			mode_left -= delta
			repath -= delta
			if front_only and _flat_dist(haunt.feet) < 2.5 and not _in_front(haunt):
				# Up behind them
				var fwd := Vector3(haunt.forward.x, 0, haunt.forward.z).normalized()
				_step_toward(haunt.feet + fwd * touch_distance * 0.7, chase_speed, delta)
			else:
				_chase(haunt, chase_speed, delta)
			if _sees_me(haunt):
				_seen_at = game.time
			# It only gets you if you see it coming, from the front
			if _reach_haunt() and (not front_only or _in_front(haunt)) and game.time - _seen_at < 1.2:
				_kill(haunt)
			elif mode_left <= 0.0:
				sightings_left = sightings_after
				_hide()   # it gave up, this time
	_float(delta)
	_show_to_local(delta)


# The alarm: it haunts whoever took the Chaos Emerald, and comes for them now
func alarm(w, for_time: float) -> void:
	super.alarm(w, for_time)
	if w == null:
		return
	haunt = w
	sightings_left = 0
	_start_chase()


func _pick_haunt(alive: Array) -> void:
	haunt = alive[randi() % alive.size()] if not alive.is_empty() else null
	sightings_left = sightings_first   # a new player to haunt
	chase_odds = chase_chance
	_hide()


# Somewhere down the corridor from them, a few turns away, where they could see it
func _appear() -> void:
	var c := _cell_near(haunt.feet, 2, 4, true)
	global_position = game._cell_center(c)
	global_position.y = game._floor_at(c, global_position) + hover
	mode = SHOWING
	mode_left = show_for
	looked_at = 0.0
	seen = false
	if sightings_left <= 0:
		chase_odds = minf(chase_odds + chase_chance, 0.9)


func _start_chase() -> void:
	var c := _cell_near(haunt.feet, 3, 5, false)
	global_position = game._cell_center(c)
	global_position.y = game._floor_at(c, global_position) + hover
	path.clear()
	repath = 0.0
	mode = CHASING
	mode_left = chase_time
	chase_odds = chase_chance


func _hide() -> void:
	mode = HIDDEN
	next_in = randf_range(appear_every.x, appear_every.y)


# A maze cell this many steps away along the corridors
func _cell_near(feet: Vector3, near: int, far: int, in_sight: bool) -> Vector2i:
	var start := _cell(feet)
	if not game.in_maze(start):
		return start
	var steps := {start: 0}
	var queue: Array[Vector2i] = [start]
	var ring: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if steps[c] >= near:
			ring.append(c)
		if steps[c] >= far:
			continue
		for n in game._neighbours(c):
			if not steps.has(n):
				steps[n] = steps[c] + 1
				queue.append(n)
	if ring.is_empty():
		return start
	if in_sight and haunt:
		var seen := ring.filter(func(c): return _clear(haunt.eye, game._cell_center(c) + Vector3(0, 0.6, 0)))
		if not seen.is_empty():
			ring = seen
	return ring[randi() % ring.size()]


# In front of them
func _in_front(w) -> bool:
	var fwd := Vector2(w.forward.x, w.forward.z).normalized()
	var to := Vector2(global_position.x - w.feet.x, global_position.z - w.feet.z).normalized()
	return fwd.dot(to) > 0.5


func _reach_haunt() -> bool:
	return _flat_dist(haunt.feet) < touch_distance and absf(haunt.feet.y - global_position.y) < 1.5


func _float(delta: float) -> void:
	var ground: float = game._floor_at(_cell(global_position), global_position)
	var want := ground + hover + sin(bob) * 0.12
	global_position.y = lerpf(global_position.y, want, clampf(delta * 3.0, 0.0, 1.0))


# Drawn only in the haunted player's own view, and only while it's out
func _show_to_local(delta: float) -> void:
	var who := -1
	if haunt and haunt.local:
		who = game.players.find(haunt.local)
	var chasing := mode == CHASING
	var out := mode != HIDDEN
	if chasing:
		_blink -= delta
		if _blink <= -0.12:
			_blink = randf_range(0.25, 0.9)
		out = _blink > 0.0
	layers = (1 << (HAUNT_LAYER_BIT + who)) if who >= 0 and out else 0
	if chasing and not _was_chasing and who >= 0 and _laugh:
		_laugh.play()
	_was_chasing = chasing
	_hallucinations(delta, who)


# Haunting you, it makes you see things
func _hallucinations(delta: float, who: int) -> void:
	for f in _fakes.duplicate():
		var node: Sprite3D = f.node
		f.life -= delta
		var me = game.players[who] if who >= 0 and who < game.players.size() else null
		if not is_instance_valid(node) or me == null or f.life <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_fakes.erase(f)
			continue
		var to: Vector3 = me.head.global_position - Vector3(0, 0.9, 0) - node.global_position
		if to.length() < 0.8:
			node.queue_free()
			_fakes.erase(f)
			continue
		node.global_position += to.normalized() * minf(hallucination_speed * delta, to.length())
		var lit: float = maxf(game._light_at(node.global_position + Vector3(0, 1.0, 0)), game.hunter_glow_at(node.global_position))
		node.modulate = Color(Color.WHITE * (min_shade + (1.0 - min_shade) * lit), 1.0)
	if not hallucinate or who < 0 or haunt == null:
		return
	_fake_in -= delta
	if _fake_in > 0.0:
		return
	_fake_in = randf_range(hallucinate_every.x, hallucinate_every.y)
	var looks: Array = []
	for k in [0, 1, 2, 4, 5]:
		var l: Array = game._hunter_look(k) if k != 1 else [game.slender_texture, game.slender_height]
		if l[0] != null:
			looks.append(l)
	if looks.is_empty():
		return
	var look: Array = looks[randi() % looks.size()]
	var c := _cell_near(haunt.feet, 2, 4, true)
	var node := Sprite3D.new()
	node.texture = look[0]
	node.pixel_size = float(look[1]) / float(look[0].get_height())
	node.offset = Vector2(0, look[0].get_height() * 0.5)
	node.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.shaded = false
	node.layers = 1 << (HAUNT_LAYER_BIT + who)   # only you
	game.add_child(node)
	node.global_position = game._cell_center(c) + Vector3(0, 0.3, 0)
	_fakes.append({"node": node, "life": 6.0})


func _kill(w) -> void:
	if not w.alive:
		return
	game.monster_kill(w, self)
	w.alive = false
	haunt = null
	_hide()

func placeholder() -> Texture2D:
	return blank_figure(30, 38, Color(0.92, 0.66, 0.2), 1.0, 0.0)   # a small orange blob
