extends "res://Scenes/Salvage/bracken.gd"
# A Clone: a copy of one of the other hunters

var copies := 6   # just for the Salvage node's bookkeeping


func update(_delta: float, _watchers: Array) -> void:
	if visible:
		_shade()


func alarm(_w, _for_time: float) -> void:
	pass


func _kill(_w) -> void:
	pass


func placeholder() -> Texture2D:
	return blank_figure(30, 90, Color(0.1, 0.1, 0.1), 1.0, 0.3)
