class_name BossTargets
# Who a boss goes after


# The player, if they can be gone after
static func everyone(tree: SceneTree) -> Array:
	var out: Array = []
	for p in tree.get_nodes_in_group("Player"):
		if is_instance_valid(p) and p.get("is_player") == true \
				and not p.get("is_player_dead") and ((p as CanvasItem).visible or _riding(p)):
			out.append(p)
	return out


# Hidden inside something they ride
static func _riding(p) -> bool:
	var v = p.get("tornado")
	return v != null and is_instance_valid(v)


static func pick(asker: Node) -> Node2D:
	var list := everyone(asker.get_tree())
	return list[0] if not list.is_empty() else null


# A boss's pull on the player, towards where it is
static func pull_everyone(tree: SceneTree, toward: Vector2, strength: float, delta: float) -> void:
	for p in everyone(tree):
		var dir: Vector2 = (toward - p.global_position).normalized()
		p.global_position += dir * strength * delta
