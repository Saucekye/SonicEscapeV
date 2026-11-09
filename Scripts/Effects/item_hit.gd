class_name ItemHit
extends RefCounted
## What happens when a carriable item (a Miku, an OC, any "item") touches a boss.
## Used by every boss's hitbox code.
##   - A THROWN item (spinning) hits the boss: the boss takes the hit, and the item
##     bounces away off screen.
##   - An item that's only standing or lying there doesn't hurt the boss. If the
##     boss runs into her, she's knocked away with the same bounce.
##   - During her spawn invincibility (miku.gd) nothing happens at all.


## True if this contact should damage the boss. Knocks a resting item away if not.
static func counts(area: Area2D, boss: Node2D) -> bool:
	if not is_instance_valid(area):
		return false
	var item := area.get_parent()
	if not is_instance_valid(item):
		return false
	if item.get("knocked_off") == true or _invincible(item):
		return false
	if not ("is_spinning" in item):
		return true   # some other kind of item: as before
	if item.is_spinning:
		if item.has_meta("net_remote_throw"):
			# Online: thrown by another player; the hit counts on their screen (and
			# reaches everyone from there), so here she only bounces off (without
			# telling the others: their screens have her own throw to finish)
			Net.applying_remote = true
			knock_away(item, boss)
			Net.applying_remote = false
			return false
		return true
	if item.get("is_being_held") != true:
		knock_away(item, boss)
	return false


## After a thrown item has hit the boss: it bounces away off screen.
static func consume(item: Node, boss: Node2D) -> void:
	if not is_instance_valid(item) or item.get("knocked_off") == true:
		return
	knock_away(item, boss)


static func knock_away(item: Node, boss: Node2D) -> void:
	if not is_instance_valid(item) or _invincible(item):
		return
	var dir := 1.0
	if item is Node2D and is_instance_valid(boss):
		dir = signf((item as Node2D).global_position.x - boss.global_position.x)
	if item.has_method("knock_off"):
		item.knock_off(dir)
	else:
		_generic_knock(item, dir)


static func _invincible(item: Node) -> bool:
	return float(item.get("spawn_safe") if item.get("spawn_safe") != null else 0.0) > 0.0


## For items without their own knock_off (the OCs): the same pop up, spin and fall
static func _generic_knock(item: Node, dir: float) -> void:
	if not (item is Node2D) or item.has_meta("lost"):
		return
	var n := item as Node2D
	n.set_meta("lost", true)
	n.set("knocked_off", true)
	if n is CollisionObject2D:
		(n as CollisionObject2D).collision_layer = 0
		(n as CollisionObject2D).collision_mask = 0
	n.set_physics_process(false)
	for a in n.find_children("*", "Area2D", true, false):
		a.set_deferred("monitoring", false)
		a.set_deferred("monitorable", false)
	n.remove_from_group("item")
	n.z_index = 60
	if dir == 0.0:
		dir = [-1.0, 1.0].pick_random()
	var t := n.create_tween().set_parallel(true)
	var start := n.global_position
	# Up and away, then down off the bottom of the screen, tumbling
	t.tween_method(func(k: float):
		if is_instance_valid(n):
			n.global_position = start + Vector2(dir * 260.0 * k * 1.6, -560.0 * k * 1.6 + 0.5 * 1300.0 * pow(k * 1.6, 2.0)),
		0.0, 1.0, 1.6)
	t.tween_property(n, "rotation", n.rotation + dir * 14.0 * 1.6, 1.6)
	t.chain().tween_callback(n.queue_free)
	GlobalSignals.emit_signal("camerashake")
