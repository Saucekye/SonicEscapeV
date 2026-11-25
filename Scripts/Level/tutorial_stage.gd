extends Node2D
# Level 1 training stage

## Only there for characters that can't wall jump, climb or fly
@export var helper_spring: Node2D

var signs := {}          # move -> sign
var done := {}           # move -> true
var _was_spinning := false
var _was_on_wall := false
var _player: CharacterBody2D


# Tracking which moves the player has done
func _ready() -> void:
	process_physics_priority = 1000   # run after the characters have moved this frame
	for s in find_children("*", "Node2D", true, false):
		if s.get_script() == preload("res://Scripts/Level/tutorial_sign.gd"):
			signs[s.move] = s
	if GlobalSignals.has_signal("switch_new_active_player"):
		GlobalSignals.switch_new_active_player.connect(func(_p): _mark("switch"))


func _mark(move: String) -> void:
	if done.has(move) or not signs.has(move):
		return
	done[move] = true
	signs[move].mark_clear()


func _physics_process(_delta: float) -> void:
	_player = get_tree().get_first_node_in_group("active_player") as CharacterBody2D
	if _player == null:
		var all := get_tree().get_nodes_in_group("all_characters")
		if all.is_empty():
			return
		_player = all[0]
	var p := _player
	var on_floor := p.is_on_floor()

	if on_floor and abs(p.velocity.x) > 500.0:
		_mark("run")
	if not on_floor and p.get("has_jumped") and p.velocity.y < -250.0:
		_mark("jump")
	var spinning: bool = p.get("is_spinningdash") == true
	if _was_spinning and not spinning and p.get("ball") == true:
		_mark("spindash")
	_was_spinning = spinning
	var on_wall: bool = p.get("hanging_on_wall") == true
	if _was_on_wall and not on_wall and abs(float(p.get("motion").x)) >= 900.0 and float(p.get("motion").y) < 0.0:
		_mark("walljump")
	_was_on_wall = on_wall
	if not on_floor and GlobalCanvasLayer.get("tricks") and int(GlobalCanvasLayer.tricks) > 0:
		_mark("trick")
	if p.get("next_bounce") == true and p.get("falling") == true:
		_mark("stomp")
	var ap = p.get("ap")
	if ap and ap.current_animation == "airspin":
		_mark("airspin")
	for c in get_tree().get_nodes_in_group("all_characters"):
		if c.get("hang") == true or c.get("held_item") != null:
			_mark("pickup")

	_update_ability_notes(p)


func _update_ability_notes(p: Node) -> void:
	# Signs say when the current character can't do a move
	for move in signs:
		var s = signs[move]
		if s.note == null:
			continue
		var can: bool = s.needs.is_empty()
		for n in s.needs:
			if p.has_node(n):
				can = true
		s.note.visible = not can and not done.has(move)
		if s.note.visible:
			s.note.text = "This character can't do this. Switch with " + s.key_name("switch") + "."
	# The shaft's helper spring is only there for characters that can't climb it
	var can_climb := p.has_node("WallJump") or p.has_node("WallClimb") or p.has_node("Fly")
	if helper_spring:
		helper_spring.visible = not can_climb
		helper_spring.process_mode = Node.PROCESS_MODE_DISABLED if can_climb else Node.PROCESS_MODE_INHERIT
