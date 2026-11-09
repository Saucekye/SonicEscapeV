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
	_add_missing_slots()
	characters = find_children("*", "SelectableCharacter")
	for character in characters:
		character.sprite_hovered.connect(_on_character_hovered)
		character.sprite_unhovered.connect(_on_character_unhovered)
		character.sprite_selected.connect(_on_character_selected)
		character.sprite_deselected.connect(_on_character_deselected)

## Characters in game_content.tres without a slot on this screen get one, in a
## new column to the right of the hand-placed ones.
func _add_missing_slots() -> void:
	const SLOT_SCENE := preload("res://misc/Icons.tscn")
	const FIRST_SLOT := Vector2(-160, -139)
	const SLOT_STEP := Vector2(176, 148)
	const ROWS := 5
	var added := 0
	for entry in Content.characters():
		if has_node(NodePath(entry.id)):
			continue
		var slot: SelectableCharacter = SLOT_SCENE.instantiate()
		slot.name = entry.id
		if entry.select_icon:
			slot.set("texture", entry.select_icon)   # (the slot scene's root is a Sprite2D)
		if entry.select_icon_active:
			slot.sprite2_texture = entry.select_icon_active
		slot.hover_color = entry.hover_color
		slot.position = FIRST_SLOT + Vector2(SLOT_STEP.x * (added / ROWS), SLOT_STEP.y * (added % ROWS))
		add_child(slot)
		added += 1


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

	var entry := Content.character(character.name)
	highlight_node.get_node("Texture").texture = entry.select_highlight if entry else null

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
