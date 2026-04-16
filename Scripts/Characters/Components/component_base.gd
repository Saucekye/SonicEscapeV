@abstract
class_name Components_Action extends Node

var player: CharacterBody2D

func _ready() -> void:
	player = self.get_parent()

@abstract
func action() -> void
