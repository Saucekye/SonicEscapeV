extends Node
## Online boss fights, the same for every player (created by net.gd).
##
## The host's game runs the boss: its AI, its attacks and its health. About 12
## times a second it sends a snapshot of the fight:
##   - each boss (any node in the arena with "health" and "max_health", like
##     chunk_boss.gd finds them): where it is, its health, what every
##     AnimationPlayer in it is playing and how far in, and every sprite's frame,
##     flip and position (so dashes, flips and effects match)
##   - every attack out right now: anything spawned during the fight that's in an
##     enemy / attack group (projectiles, the Fun Gang's heart...): which scene,
##     where, how it's turned
## The other players' games don't run the boss's AI. They show the host's boss
## and copies of its attacks, which keep their hitboxes, so attacks hurt
## everyone. When one of them hits the boss, their game tells the host, which
## takes the health off; the next snapshot shows the new health to everyone.
## When the host's boss runs out of health, everyone's boss plays its own death
## and the floor ends together (the host decides, as before).

const RATE := 12.0                 # snapshots a second
const HIT_GRACE := 0.8             # seconds a local hit isn't undone by an older snapshot
const ATTACK_GROUPS := ["EnemyProjectile", "Enemy", "enemyattack"]

var net: Node
var _arena: Node = null
var _bosses: Array = []            # boss nodes (with health)
var _one_hit: Array = []           # bosses beaten by a single hit (Caine): a "death" flag, no health
var _one_hit_sent := {}            # client: path -> we told the host we hit it
var _timer := 0.0
# Host: attacks spawned during the fight
var _attacks := {}                 # id -> Node2D
var _next_id := 1
# Clients
var _mirrors := {}                 # attack id -> {"node", "target_xf"}
var _boss_state := {}              # boss path -> {"target", "health", "hit_at", "dead"}
var _connected := false


func setup(net_node: Node) -> void:
	net = net_node


func _scene() -> Node:
	return get_tree().current_scene


## Called every frame by net.gd while online in a level
func update(delta: float) -> void:
	var arena := _find_arena()
	if arena != _arena:
		_start(arena)
	if _arena == null:
		return
	if net.is_host:
		_timer -= delta
		if _timer <= 0.0:
			_timer = 1.0 / RATE
			_send_snapshot()
	else:
		_client_frame(delta)


func _find_arena() -> Node:
	var cs := _scene()
	if cs == null:
		return null
	for a in get_tree().get_nodes_in_group("boss_arena"):
		# (the minimap keeps a still copy of each chunk, on the screen layer: not that one)
		if is_instance_valid(a) and cs.is_ancestor_of(a) and not _on_screen_layer(a):
			return a
	return null


func _on_screen_layer(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false


func _start(arena: Node) -> void:
	_arena = arena
	_bosses.clear()
	_attacks.clear()
	_mirrors.clear()
	_boss_state.clear()
	_next_id = 1
	if not _connected:
		get_tree().node_added.connect(_on_node_added)
		_connected = true
	if _arena == null:
		return
	_find_bosses()
	if not net.is_host:
		for b in _bosses:
			_set_brain(b, false)
	print("[Net] boss fight: %d boss(es), %s" % [_bosses.size(), "running them (host)" if net.is_host else "showing the host's"])


func _find_bosses() -> void:
	_bosses.clear()
	_one_hit.clear()
	for n in _arena.find_children("*", "", true, false):
		if "health" in n and "max_health" in n and not n.is_queued_for_deletion():
			_bosses.append(n)
		elif "death" in n and "max_health" in n and n.has_method("net_hit"):
			_one_hit.append(n)   # a boss beaten in one hit (Caine)


## Turn a boss's own AI on or off (its scripts and its timers; its animations
## keep running, driven by the host's snapshots)
func _set_brain(boss: Node, on: bool) -> void:
	boss.set_process(on)
	boss.set_physics_process(on)
	for t in boss.find_children("*", "Timer", true, false):
		(t as Timer).paused = not on


# ── Attacks: what counts, and keeping track ───────────────────────────────────
func _is_attack(n: Node) -> bool:
	if not (n is Node2D) or n.scene_file_path == "" or n.has_meta("net_mirror"):
		return false
	if "health" in n and "max_health" in n:
		return false   # a boss, not an attack
	for g in ATTACK_GROUPS:
		if n.is_in_group(g):
			return true
	for c in n.find_children("*", "Area2D", true, false):
		for g in ATTACK_GROUPS:
			if c.is_in_group(g):
				return true
	return false


func _on_node_added(n: Node) -> void:
	if _arena == null or not net.online:
		return
	_check_added.call_deferred(n)   # (its children and groups are ready then)


func _check_added(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree() or _arena == null:
		return
	if "health" in n and "max_health" in n and _arena.is_ancestor_of(n):
		# A boss arriving mid-fight (one boss handing over to the next)
		if not net.is_host:
			_set_brain(n, false)
		return
	if not _is_attack(n):
		return
	if not _scene().is_ancestor_of(n):
		return
	if net.is_host:
		var id := _next_id
		_next_id += 1
		_attacks[id] = n
	else:
		# The host's attacks arrive as copies; one made by this game's boss is a stray
		n.queue_free()


# ── Host: sending ─────────────────────────────────────────────────────────────
func _send_snapshot() -> void:
	_find_bosses()
	var bosses: Array = []
	for b in _bosses:
		if not is_instance_valid(b):
			continue
		var anims: Array = []
		for ap in b.find_children("*", "AnimationPlayer", true, false):
			var a := ap as AnimationPlayer
			anims.append([str(b.get_path_to(a)), str(a.current_animation), snappedf(a.current_animation_position, 0.01), a.is_playing()])
		var sprites: Array = []
		for s in b.find_children("*", "", true, false):
			if s is Sprite2D or s is AnimatedSprite2D:
				var ci := s as Node2D
				sprites.append([str(b.get_path_to(ci)), int(ci.frame), ci.flip_h, ci.flip_v, ci.visible,
						snappedf(ci.position.x, 0.01), snappedf(ci.position.y, 0.01), snappedf(ci.rotation, 0.01),
						str(ci.animation) if ci is AnimatedSprite2D else ""])
		var n2 := b as Node2D
		bosses.append({"p": str(_arena.get_path_to(b)), "h": float(b.health), "m": float(b.max_health),
				"bg": bool(b.get("begin")) if "begin" in b else true,
				"on": b.process_mode != Node.PROCESS_MODE_DISABLED,
				"x": snappedf(n2.global_position.x, 0.1), "y": snappedf(n2.global_position.y, 0.1),
				"r": snappedf(n2.global_rotation, 0.01), "v": n2.visible, "a": anims, "s": sprites})
	var atk: Array = []
	for id in _attacks.keys():
		var n = _attacks[id]
		if not is_instance_valid(n) or not n.is_inside_tree():
			_attacks.erase(id)
			continue
		var n2 := n as Node2D
		var spr = _first_sprite(n2)
		atk.append([id, n2.scene_file_path, snappedf(n2.global_position.x, 0.1), snappedf(n2.global_position.y, 0.1),
				snappedf(n2.global_rotation, 0.01), snappedf(n2.global_scale.x, 0.01), snappedf(n2.global_scale.y, 0.01),
				n2.visible, int(spr.frame) if spr else 0, spr.flip_h if spr else false])
	var once: Array = []
	for c in _one_hit:
		if is_instance_valid(c):
			once.append([str(_arena.get_path_to(c)), bool(c.get("death")) or c.has_meta("net_beaten")])
	net.send({"t": "boss", "b": bosses, "k": atk, "c": once})


func _first_sprite(n: Node) -> Node2D:
	if n is Sprite2D or n is AnimatedSprite2D:
		return n
	for c in n.find_children("*", "", true, false):
		if c is Sprite2D or c is AnimatedSprite2D:
			return c
	return null


## Host: another player hit a boss
func on_hit(m: Dictionary) -> void:
	if not net.is_host or _arena == null:
		return
	var b := _arena.get_node_or_null(NodePath(str(m.get("p", ""))))
	if b and m.get("c", false):
		_beat_one_hit(b)
		return
	if b == null or not ("health" in b) or float(b.health) <= 0.0:
		return
	var amount := float(m.get("n", 1))
	if b.has_method("take_damage"):
		b.take_damage(int(amount) if typeof(b.health) == TYPE_INT else amount)   # (also starts its death)
	else:
		b.health = b.health - (int(amount) if typeof(b.health) == TYPE_INT else amount)
		if b.has_signal("update_health_bar"):
			b.emit_signal("update_health_bar", b.health, b.max_health)
		_start_death(b)


## A one-hit boss (Caine) was hit on some player's screen: it goes down here too
func _beat_one_hit(c: Node) -> void:
	if c.has_meta("net_beaten") or bool(c.get("death")):
		c.set_meta("net_beaten", true)
		return
	c.set_meta("net_beaten", true)
	c.net_hit()


## Some bosses only start dying inside their own hit code
func _start_death(b: Node) -> void:
	if float(b.health) <= 0.0 and b.has_method("start_death") and not bool(b.get("dying")):
		b.start_death()


# ── Clients: showing the host's fight ─────────────────────────────────────────
func on_snapshot(m: Dictionary) -> void:
	if net.is_host or _arena == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for cd in m.get("c", []):
		var c := _arena.get_node_or_null(NodePath(str(cd[0])))
		if c and bool(cd[1]):
			_beat_one_hit(c)   # beaten on the host's game
	for bd in m.get("b", []):
		var path := str(bd.p)
		var b := _arena.get_node_or_null(NodePath(path))
		if b == null:
			continue
		var st: Dictionary = _boss_state.get(path, {"health": float(bd.h), "hit_at": -10.0, "dead": false})
		_boss_state[path] = st
		if st.dead:
			continue
		var n2 := b as Node2D
		# The fight has started on the host's game: wake ours up too (bosses sleep
		# until a player walks in; its own AI stays off here)
		if bool(bd.get("on", true)) and b.process_mode == Node.PROCESS_MODE_DISABLED:
			b.process_mode = Node.PROCESS_MODE_INHERIT
			_set_brain(b, false)
		if not st.has("brain_off"):
			st["brain_off"] = true
			_set_brain(b, false)
		st["target"] = Vector2(float(bd.x), float(bd.y))
		n2.global_rotation = float(bd.r)
		n2.visible = bool(bd.v)
		# Health: the host's, unless one of our own hits is still on its way to them
		_check_our_hits(path, b, st)   # (a hit since the last frame, before it's overwritten)
		if st.dead:
			continue
		var host_h := float(bd.h)
		if now - float(st.hit_at) > HIT_GRACE or host_h < float(b.health):
			if not is_equal_approx(float(b.health), host_h):
				b.health = int(host_h) if typeof(b.health) == TYPE_INT else host_h
				if b.has_signal("update_health_bar"):
					b.emit_signal("update_health_bar", b.health, b.max_health)
			st.health = host_h
		if host_h <= 0.0:
			# The host's boss is beaten: let ours play its own death
			b.health = 0 if typeof(b.health) == TYPE_INT else 0.0
			_die(path, b)
			continue
		# Its intro is over on the host's game: it can be hit here too
		if "begin" in b and bool(bd.get("bg", true)) and not bool(b.get("begin")):
			b.set("begin", true)
		# ...and its health bar shows here too (bosses show it at the end of their
		# own intro, which may not have run on this screen)
		if bool(bd.get("on", true)) and bool(bd.get("bg", true)) and not st.has("ui"):
			st["ui"] = true
			GlobalSignals.disable_boss_ui.emit(false)
			if b.has_signal("update_health_bar"):
				b.emit_signal("update_health_bar", b.health, b.max_health)
		for a in bd.get("a", []):
			var ap := b.get_node_or_null(NodePath(str(a[0]))) as AnimationPlayer
			if ap == null:
				continue
			var anim_name := str(a[1])
			if anim_name == "" or not bool(a[3]):
				if ap.is_playing():
					ap.pause()
				continue
			if not ap.has_animation(anim_name):
				continue
			if ap.current_animation != anim_name or not ap.is_playing():
				ap.play(anim_name)
			if absf(ap.current_animation_position - float(a[2])) > 0.15:
				ap.seek(float(a[2]), true)
		for s in bd.get("s", []):
			var spr := b.get_node_or_null(NodePath(str(s[0]))) as Node2D
			if spr == null:
				continue
			if spr is AnimatedSprite2D and str(s[8]) != "" and (spr as AnimatedSprite2D).sprite_frames \
					and (spr as AnimatedSprite2D).sprite_frames.has_animation(str(s[8])) and str((spr as AnimatedSprite2D).animation) != str(s[8]):
				(spr as AnimatedSprite2D).animation = str(s[8])
			spr.set("frame", int(s[1]))
			spr.set("flip_h", bool(s[2]))
			spr.set("flip_v", bool(s[3]))
			spr.visible = bool(s[4])
			spr.position = Vector2(float(s[5]), float(s[6]))
			spr.rotation = float(s[7])
	if _all_dead():
		return   # the fight's over here: no more attacks
	# Attacks: make, move and remove the copies
	var seen := {}
	for k in m.get("k", []):
		var id := int(k[0])
		seen[id] = true
		var xf := Transform2D(float(k[4]), Vector2(float(k[5]), float(k[6])), 0.0, Vector2(float(k[2]), float(k[3])))
		if not _mirrors.has(id):
			var copy := _make_copy(str(k[1]))
			if copy == null:
				continue
			copy.global_transform = xf
			_mirrors[id] = {"node": copy, "target_xf": xf}
		var mi: Dictionary = _mirrors[id]
		mi.target_xf = xf
		var node: Node2D = mi.node
		if is_instance_valid(node):
			node.visible = bool(k[7])
			var spr = _first_sprite(node)
			if spr:
				spr.set("frame", int(k[8]))
				spr.set("flip_h", bool(k[9]))
	for id in _mirrors.keys():
		if not seen.has(id):
			var node = _mirrors[id].node
			if is_instance_valid(node):
				node.queue_free()
			_mirrors.erase(id)


## Our hits: tell the host (the boss's own hit code already took the health off here)
func _check_our_hits(path: String, b: Node, st: Dictionary) -> void:
	if st.dead:
		return
	if float(b.health) < float(st.health) - 0.001:
		var amount := float(st.health) - float(b.health)
		net.send({"t": "bhit", "p": path, "n": amount})
		st.health = float(b.health)
		st.hit_at = Time.get_ticks_msec() / 1000.0
	if float(b.health) <= 0.0:
		_die(path, b)   # we landed the last hit: the host's game will follow


func _all_dead() -> bool:
	if _boss_state.is_empty():
		return false
	for path in _boss_state:
		if not _boss_state[path].dead:
			return false
	return true


func _die(path: String, b: Node) -> void:
	var st: Dictionary = _boss_state[path]
	if st.dead:
		return
	st.dead = true
	_set_brain(b, true)
	_start_death(b)
	for id in _mirrors:   # its attacks go with it
		if is_instance_valid(_mirrors[id].node):
			_mirrors[id].node.queue_free()
	_mirrors.clear()


func _make_copy(scene_path: String) -> Node2D:
	if not ResourceLoader.exists(scene_path):
		return null
	var copy := (load(scene_path) as PackedScene).instantiate() as Node2D
	if copy == null:
		return null
	copy.set_meta("net_mirror", true)
	# Just a copy: its own script doesn't run (the host moves it), but its hitboxes stay
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	var cos: Array = copy.find_children("*", "CollisionObject2D", true, false)
	if copy is CollisionObject2D:
		cos.append(copy)
	for co in cos:
		(co as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	_scene().add_child(copy)
	return copy


func _client_frame(delta: float) -> void:
	var k := clampf(delta * 14.0, 0.0, 1.0)
	# A one-hit boss we beat here: tell the host
	for c in _one_hit:
		if is_instance_valid(c) and bool(c.get("death")) and not c.has_meta("net_beaten"):
			c.set_meta("net_beaten", true)
			net.send({"t": "bhit", "p": str(_arena.get_path_to(c)), "c": true})
	for path in _boss_state:
		var st: Dictionary = _boss_state[path]
		if st.dead or not st.has("target"):
			continue
		var b := _arena.get_node_or_null(NodePath(path)) as Node2D
		if b == null:
			continue
		var target: Vector2 = st.target
		b.global_position = target if b.global_position.distance_to(target) > 800.0 else b.global_position.lerp(target, k)
		_check_our_hits(path, b, st)
	for id in _mirrors:
		var mi: Dictionary = _mirrors[id]
		var node = mi.node
		if is_instance_valid(node):
			var xf: Transform2D = mi.target_xf
			if node.global_position.distance_to(xf.origin) > 600.0:
				node.global_transform = xf
			else:
				node.global_transform = node.global_transform.interpolate_with(xf, k)
