extends Node2D

var balloon
var new_dialogue: DialogueResource = load("res://dialogue/2.dialogue")
signal next

func _ready():
	balloon = $ExampleBalloon
	balloon.dialogue_resource = new_dialogue
	balloon.start(new_dialogue, "start")
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		emit_signal("next")
