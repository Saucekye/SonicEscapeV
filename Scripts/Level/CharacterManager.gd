extends Node2D
class_name CharacterManager

var currently_hovered_character: SelectableCharacter = null
var selected_characters: Array = []
var characters: Array[Node] = []

const MAX_PICKS := 4
var highlights: Array[Node] = []   # the big picture behind each pick, in order

func _ready():
	find_and_setup_characters()
	# A 4th picture, made from the 3rd
	var h4 := $Highlight3.duplicate()
	h4.name = "Highlight4"
	add_child(h4)
	move_child(h4, $Highlight3.get_index() + 1)
	highlights = [$Highlight1, $Highlight2, $Highlight3, h4]
	for h in highlights:
		h.visible = false
		h.set_meta("home", h.position)
	print(characters)

func find_and_setup_characters():
	_add_missing_slots()
	characters = find_children("*", "SelectableCharacter", true, false)   # false: the slots added in code too
	for character in characters:
		character.sprite_hovered.connect(_on_character_hovered)
		character.sprite_unhovered.connect(_on_character_unhovered)
		character.sprite_selected.connect(_on_character_selected)
		character.sprite_deselected.connect(_on_character_deselected)

# Characters in game_content.tres without a slot on this screen get one
func _add_missing_slots() -> void:
	const SLOT_SCENE := preload("res://misc/Icons.tscn")
	const FIRST_SLOT := Vector2(-160, -139)
	const SLOT_STEP := Vector2(176, 148)
	const ROWS := 5
	var added := 0
	for entry in Content.characters():
		if has_node(NodePath(entry.id)):
			continue
		if entry.custom_dir != "":
			_add_custom_slot(entry)   # picked from the CUSTOM window, not this grid
			continue
		var slot: SelectableCharacter = SLOT_SCENE.instantiate()
		slot.name = entry.id
		if entry.select_icon:
			slot.set("texture", entry.select_icon)
		if entry.select_icon_active:
			slot.sprite2_texture = entry.select_icon_active
		slot.hover_color = entry.hover_color
		slot.position = FIRST_SLOT + Vector2(SLOT_STEP.x * (added / ROWS), SLOT_STEP.y * (added % ROWS))
		add_child(slot)
		added += 1


# A custom character's slot
func _add_custom_slot(entry: CharacterEntry) -> void:
	var holder := get_node_or_null("CustomSlots") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "CustomSlots"
		holder.visible = false
		holder.position = Vector2(-100000, -100000)   # and its clicks out of the way
		add_child(holder)
	var slot: SelectableCharacter = preload("res://misc/Icons.tscn").instantiate()
	slot.name = entry.id
	slot.sprite2_texture = entry.select_icon_active
	slot.hover_color = entry.hover_color
	holder.add_child(slot)


func _on_character_hovered(character: SelectableCharacter):
	if selected_characters.has(character) or selected_characters.size() >= MAX_PICKS:
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

	if selected_characters.size() >= 4:
		Test.characterfour = selected_characters[3].name
	else:
		Test.characterfour = ""
		
	print("Selected characters:")
	print("1:", Test.characterone)
	print("2:", Test.charactertwo)
	print("3:", Test.characterthree)
	print("4:", Test.characterfour)


func _on_character_selected(character: SelectableCharacter):
	if character in selected_characters:
		print("Character already selected: ", character.name)
	else:
		if selected_characters.size() >= MAX_PICKS:
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
	_place_highlights(selected_characters.size())
	for i in highlights.size():
		highlights[i].visible = false
		if i < selected_characters.size():
			update_highlight_for_node(highlights[i], selected_characters[i])


# Where the pictures sit
func _place_highlights(count: int) -> void:
	var first: Vector2 = highlights[0].get_meta("home")
	var third: Vector2 = highlights[2].get_meta("home")
	for i in highlights.size():
		var home: Vector2 = highlights[i].get_meta("home")
		highlights[i].position = first.lerp(third, i / 3.0) if count >= 4 else home


func update_highlight_for_node(highlight_node: Node, character: SelectableCharacter):
	highlight_node.visible = true

	var entry := Content.character(character.name)
	highlight_node.get_node("Texture").texture = entry.select_highlight if entry else null

func update_hover_highlight(character: SelectableCharacter):
	var n := selected_characters.size()
	if n < highlights.size():
		_place_highlights(n + 1)
		update_highlight_for_node(highlights[n], character)


func hide_hover_highlight():
	var n := selected_characters.size()
	if n < highlights.size():
		highlights[n].visible = false
		_place_highlights(n)
