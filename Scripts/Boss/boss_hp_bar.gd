extends CanvasLayer

@onready var boss_ui_container: HBoxContainer = $BossUIContainer
@onready var label: Label = $BossUIContainer/Label
@onready var health_bar: TextureProgressBar = $BossUIContainer/ProgressBar

@export var boss: Node2D
@export var boss_name : String

const HEALTH_BAR_MAX : int = 100

signal set_new_boss(new_boss : Node2D, new_boss_name : String)

func _ready() -> void:
	GlobalSignals.disable_boss_ui.connect(_display_boss_hp)
	label.text = boss_name
	boss_ui_container.visible = false
	
func _display_boss_hp(display_hp : bool):
	boss_ui_container.visible = !display_hp

func _on_node_2d_update_health_bar(boss_health: int, boss_max_health: int) -> void:
	print(boss_health)
	var duration : float = 0.1
	health_bar.material.set_shader_parameter("flash_amount", 1.0)
	health_bar.value = HEALTH_BAR_MAX * float(boss_health) / boss_max_health
	await get_tree().create_timer(duration).timeout
	health_bar.material.set_shader_parameter("flash_amount", 0.0)
	
func _set_new_boss(new_boss : Node2D, new_name : String):
	boss = new_boss
	boss_name = new_name
	label.text = boss_name
	boss_ui_container.visible = true
	health_bar.value = HEALTH_BAR_MAX
	
	
