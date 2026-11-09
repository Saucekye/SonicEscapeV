extends Label

var time_passed := 0.0
var start = false

signal best

func _ready():
	await get_tree().create_timer(2.0).timeout
	start = true
	text = format_time(time_passed)
	GlobalSignals.game_over.connect(_on_game_over)

## Speedrun timer: times each floor and each boss fight, from the end of the floor
## intro until you touch the goal or the boss is beaten, then freezes on that split.
## It doesn't run in rest areas, while paused, or between floors. Every split is
## added to the run's total time (Test.elapsed_sesion_time, on the results screen).
func _process(delta):
	if not start or Test.in_rest_area or Test.floor_done:
		return
	time_passed += delta
	Test.elapsed_sesion_time += delta
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
	elif (time_passed < Test.bestTimeFloat) and time_passed > 0.0 and not Test.in_rest_area and not (Test.level-1) % 4 == 0:
		Test.bestTimeFloat = time_passed
		Test.bestTimeText = "BEST TIME: " + format_time(time_passed)

func _on_game_over():
	set_process(false)
