extends Node3D
# Landmine for Salvage

var game: Node3D                 # salvage.gd
var index := 0
var armed := true
var _on := 0                     # players standing on it
var _blink := 0.0

@onready var light: Node3D = $Light
@onready var trigger: Area3D = $Trigger


func _ready() -> void:
	trigger.body_entered.connect(_stepped_on)
	trigger.body_exited.connect(_stepped_off)


func _stepped_on(body: Node3D) -> void:
	if armed and game and game.players.has(body) and not body.dead:
		_on += 1
		game.mine_click(self, body)


func _stepped_off(body: Node3D) -> void:
	if armed and game and game.players.has(body):
		_on = maxi(_on - 1, 0)
		if _on == 0:
			game.mine_trip(self)


func _process(delta: float) -> void:
	if not armed:
		return
	# Slow blink while it waits, solid once someone's on it
	_blink += delta
	light.visible = _on > 0 or fmod(_blink, 1.2) < 0.15
