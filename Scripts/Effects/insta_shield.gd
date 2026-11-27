extends Sprite2D
# The insta shield flash

const SHEET := preload("res://Sprites/Effects/Shield/insta_shield.png")   # eight frames across
var radius := 60.0     # (set by the player) how big round you it is
var time := 0.25       # how long the animation takes
var _t := 0.0

func _ready() -> void:
	texture = SHEET
	hframes = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := float(SHEET.get_width()) / hframes
	scale = Vector2.ONE * (radius * 2.0 / size)

func _process(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	frame = mini(int(_t / time * hframes), hframes - 1)
