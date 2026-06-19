extends Node2D
class_name CharacterManager

var currently_hovered_character: SelectableCharacter = null
var selected_characters: Array = []
var characters: Array[Node] = []

func _ready():
	find_and_setup_characters()
	$Highlight1.visible = false
	$Highlight2.visible = false
	$Highlight3.visible = false
	print(characters)

func find_and_setup_characters():
	characters = find_children("*", "SelectableCharacter")
	for character in characters:
		character.sprite_hovered.connect(_on_character_hovered)
		character.sprite_unhovered.connect(_on_character_unhovered)
		character.sprite_selected.connect(_on_character_selected)
		character.sprite_deselected.connect(_on_character_deselected)

func _on_character_hovered(character: SelectableCharacter):
	if selected_characters.has(character) or selected_characters.size() >= 3:
		return

	if currently_hovered_character and currently_hovered_character != character:
		currently_hovered_character.force_unhover()

	currently_hovered_character = character
	update_hover_highlight(character)

func _on_character_unhovered(character: SelectableCharacter):
	if currently_hovered_character == character:
		currently_hovered_character = null
		hide_hover_highlight()
		
func update_select_globals():
	if selected_characters.size() >= 1:
		Test.characterone = selected_characters[0].name
	else:
		Test.characterone = ""

	if selected_characters.size() >= 2:
		Test.charactertwo = selected_characters[1].name
	else:
		Test.charactertwo = ""

	if selected_characters.size() >= 3:
		Test.characterthree = selected_characters[2].name
	else:
		Test.characterthree = ""
		
	print("Selected characters:")
	print("1:", Test.characterone)
	print("2:", Test.charactertwo)
	print("3:", Test.characterthree)


func _on_character_selected(character: SelectableCharacter):
	if character in selected_characters:
		print("Character already selected: ", character.name)
	else:
		if selected_characters.size() >= 3:
			var removed = selected_characters.pop_front()
			print("Replacing oldest selection: ", removed.name)
			removed.force_deselect()

		selected_characters.append(character)
		print("Selected: ", character.name)

	update_selection_highlight()
	hide_hover_highlight()
	update_select_globals()

func _on_character_deselected(character: SelectableCharacter):
	if character in selected_characters:
		selected_characters.erase(character)
		print("Deselected: ", character.name)
	else:
		print("Character not selected but got deselect signal: ", character.name)

	update_selection_highlight()
	update_select_globals()


func update_selection_highlight():
	$Highlight1.visible = false
	$Highlight2.visible = false
	$Highlight3.visible = false

	if selected_characters.size() >= 1:
		update_highlight_for_node($Highlight1, selected_characters[0])
	if selected_characters.size() >= 2:
		update_highlight_for_node($Highlight2, selected_characters[1])
	if selected_characters.size() == 3:
		update_highlight_for_node($Highlight3, selected_characters[2])


func update_highlight_for_node(highlight_node: Node, character: SelectableCharacter):
	highlight_node.visible = true

	match character.name:
		"Sonic":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Sonic/Sonichighlight.png")
		"Tails":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Tails/highlight.png")
		"Knuckles":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Knuckles/knuckleshighlight.png")
		"Amy":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Amy/Amyhighlight.png")
		"Rouge":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Rouge/rougehighlight.png")
		"Blaze":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Blaze/blazehighlight.png")
		"Cream":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Cream/creamhighlight.png")
		"MetalSonic":
			highlight_node.get_node("Texture").texture = load("res://Scenes/Characters/Metal Sonic/metalhighlight1.png")
		"Silver2":
			highlight_node.get_node("Texture").texture = load("res://Sprites/Characters/Silver/highlight.png")
		_:
			highlight_node.get_node("Texture").texture = null

func update_hover_highlight(character: SelectableCharacter):
	match selected_characters.size():
		0:
			update_highlight_for_node($Highlight1, character)
		1:
			update_highlight_for_node($Highlight2, character)
		2:
			update_highlight_for_node($Highlight3, character)


func hide_hover_highlight():
	match selected_characters.size():
		0:
			$Highlight1.visible = false
		1:
			$Highlight2.visible = false
		2:
			$Highlight3.visible = false
