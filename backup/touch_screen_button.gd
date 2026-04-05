extends Control

func _ready() -> void:
	if Test.mobile == true:
		visible = true
	else:
		visible = false
