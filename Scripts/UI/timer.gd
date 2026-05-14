extends Label

var time_passed := 0.0
var start = false

signal best

func _ready():
	await get_tree().create_timer(2.0).timeout
	start = true
	text = format_time(time_passed)
	GlobalSignals.game_over.connect(_on_game_over)

func _process(delta):
	if not start:
		return
	if not Test.level % 4 == 0:
		time_passed += delta
		text = format_time(time_passed)

func format_time(t: float) -> String:
	# total centiseconds since start
	var total_cs := int(t * 100)
	# centiseconds remainder
	var cs := total_cs % 100
	# total whole seconds
	var total_s := total_cs / 100
	# seconds and minutes
	var s := total_s % 60
	var m := total_s / 60
	# format as M:SS:CC with zero padding
	return "%d:%02d:%02d" % [int(m), int(s), int(cs)]

func _on_restartflash_goal() -> void:
	if Test.fail == true:
		Test.bestTimeText = "BEST TIME: 666:66:66"
	elif (time_passed < Test.bestTimeFloat) and not (Test.level-1) % 4 == 0:
		Test.bestTimeFloat = time_passed
		Test.bestTimeText = "BEST TIME: " + format_time(time_passed)

func _on_game_over():
	set_process(false)
