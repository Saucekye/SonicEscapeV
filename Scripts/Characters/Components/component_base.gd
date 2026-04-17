@abstract
class_name Components_Action extends Node

var player: Player

func _ready() -> void:
	player = self.get_parent()

@abstract
func action() -> void
