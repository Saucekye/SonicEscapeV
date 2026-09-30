extends ColorRect

func _process(delta: float) -> void:
	if GlobalCanvasLayer.boost == true:
		visible = true
	else:
		visible = false
