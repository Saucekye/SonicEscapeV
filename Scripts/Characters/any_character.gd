extends Player
## A character script that needs no code: every ability under the character
## works by itself. To add an ability, drag one in from
## Scenes/Characters/Components/ (Air Actions, Ground Actions or Wall Mechanics);
## to remove one, delete its node. The folder it comes from decides when it runs:
## in the air, on the ground, or against a wall.

## Ability nodes to leave switched off (their node names), without deleting them.
@export var skip_abilities: Array[String] = []

var _air: Array[Node] = []
var _ground: Array[Node] = []
var _wall: Array[Node] = []
var _homing: Node = null


func _ready() -> void:
	super._ready()
	for child in get_children():
		if child.name in skip_abilities or not child.has_method("action"):
			continue
		var from := child.scene_file_path
		if from.contains("/Air Actions/"):
			if child.has_method("has_target"):
				_homing = child   # the homing attack goes first, see below
			else:
				_air.append(child)
			if from.ends_with("swipe_attack.tscn"):
				_ground.append(child)   # a swipe works on the ground too
		elif from.contains("/Ground Actions/"):
			_ground.append(child)
		elif from.contains("/Wall Mechanics/"):
			_wall.append(child)


func handle_air_actions(_is_grounded) -> void:
	# Jump near an enemy: homing attack (unless Down is held too)
	if _homing and inp_just_pressed("ui_accept") and not inp_pressed("ui_down") and _homing.has_target():
		_homing.action()
		return
	for ability in _air:
		ability.action()


func handle_ground_action() -> void:
	for ability in _ground:
		ability.action()


func handle_wall_mechanics() -> void:
	for ability in _wall:
		ability.action()


func _on_boost_animation_finished() -> void:
	if has_node("Boost"):
		$Boost.play("default")
