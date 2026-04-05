extends ParallaxBackground

@export var scroll_speed: float = 100

func _process(delta):
	if Test.level % 4 == 0:
		scroll_base_offset.x += scroll_speed * delta
