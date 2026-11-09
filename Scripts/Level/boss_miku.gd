extends Node
## Boss floors after level 8: the first time a boss is down to half health, a
## Miku (rarely an OC) drops into the arena. If she's still in the arena when the
## boss is beaten (carried or not), she counts as saved: the points pop up and
## she's added to the run's score (miku_saved.gd). If she's knocked off
## by an attack first (miku.gd), she's lost and no other Miku drops.
## Added by level_generator.gd for each boss chunk.

const SAVED := preload("res://Scripts/Effects/miku_saved.gd")

var generator: Node2D
var chunk: Node
var bosses: Array = []
var miku: Node2D = null
var dropped := false   # only one Miku per fight, even if she gets knocked off
var done := false


func setup(level_generator: Node2D, boss_chunk: Node) -> void:
	generator = level_generator
	chunk = boss_chunk


func _ready() -> void:
	# Every node in the chunk that keeps health (the two-boss fights have two)
	for n in chunk.find_children("*", "", true, false):
		if "health" in n and "max_health" in n:
			bosses.append(n)
			if n.has_signal("end"):
				n.connect("end", _on_boss_beaten)


func _process(_delta: float) -> void:
	if done or bosses.is_empty():
		return
	if not dropped and _any_at_half():
		_drop_miku()
	elif dropped and _all_beaten():
		_on_boss_beaten()


func _any_at_half() -> bool:
	for b in bosses:
		if not is_instance_valid(b):
			continue
		var mx := float(b.max_health)
		if mx > 0.0 and float(b.health) <= mx * 0.5 and float(b.health) > 0.0:
			return true
	return false


func _all_beaten() -> bool:
	for b in bosses:
		if is_instance_valid(b) and float(b.max_health) > 0.0 and float(b.health) > 0.0:
			return false
	return true


func _drop_miku() -> void:
	dropped = true
	miku = SAVED.rescue_scene(generator.miku_scene, Net.shared_rng("boss_miku")).instantiate()   # rarely an OC instead (the same for everyone online)
	generator.add_child(miku)
	miku.scale = Vector2(125, 125)   # same as level_generator's ground Miku
	miku.global_position = _drop_point()


func _drop_point() -> Vector2:
	# Upper middle of the arena (the terrain layer's open space), else above the player
	var layer := chunk.find_child("TileMapLayer", true, false) as TileMapLayer
	if layer:
		var r := layer.get_used_rect()
		return layer.to_global(layer.map_to_local(Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2 - 3)))
	var ps := get_tree().get_nodes_in_group("active_player")
	if not ps.is_empty():
		return ps[0].global_position + Vector2(0, -300)
	return chunk.global_position


func _on_boss_beaten() -> void:
	if done:
		return
	done = true
	if is_instance_valid(miku) and miku.is_inside_tree() and not miku.has_meta("lost"):
		SAVED.save(miku)
