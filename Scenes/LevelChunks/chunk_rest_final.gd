extends Node2D

func _ready() -> void:
	GlobalSignals.emit_signal("black")
