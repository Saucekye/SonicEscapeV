extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = "VX: " + str(get_parent().motion.x) + "" + " Rings: " + str(get_parent().rings) + "" + " Bounce: " + str(get_parent().bounce) +"\nTIME: " + str(get_parent().time_elpased) + "" + " SLOPE: " + str(get_parent().slopefactor) + "" + " ANGLE: " + str(get_parent().slopeangle) + "" + " LOCK: " + str(get_parent().control_lock) + "can_dash: " + str(get_parent().can_dash)
