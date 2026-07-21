extends Node2D

@onready var character1 = $CharacterBody2D
@onready var character2 = $CharacterBody2D2

func _ready():
	randomize()

	# Disable both first
	disable_character(character1)
	disable_character(character2)

	match randi() % 3:
		0:
			enable_character(character1)
		1:
			enable_character(character2)
		2:
			# Neither character is enabled
			pass

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
