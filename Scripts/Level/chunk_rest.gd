extends Node2D

@onready var character1 = $CharacterBody2D
@onready var character2 = $CharacterBody2D2

func _ready():
	randomize()

	# Disable both first
	disable_character(character1)
	disable_character(character2)

	# Keep both disabled on levels 0, 20, and 24
	if Test.level == 0 or Test.level == 20 or Test.level == 24:
		return

	# Character 2 is ALWAYS enabled on every other floor
	enable_character(character2)

	# Character 1 has a 50% chance to also be enabled
	if randi() % 2 == 0:
		enable_character(character1)


func disable_character(character: CharacterBody2D):
	character.visible = false
	character.process_mode = Node.PROCESS_MODE_DISABLED

	var collision = character.get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = true


func enable_character(character: CharacterBody2D):
	character.visible = true
	character.process_mode = Node.PROCESS_MODE_INHERIT

	var collision = character.get_node_or_null("CollisionShape2D")
	if collision:
		collision.disabled = false
