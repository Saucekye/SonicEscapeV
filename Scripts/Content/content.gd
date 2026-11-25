@tool
class_name Content
# Read access to game_content.tres from anywhere

const PATH := "res://game_content.tres"

static var _data: GameContent


static func data() -> GameContent:
	if _data == null:
		_data = load(PATH) as GameContent
		if not Engine.is_editor_hint():
			CustomCharacters.load_all(_data)   # and the ones in the characters folder
	return _data


# Read the characters folder again
static func reload_custom() -> void:
	if _data and not Engine.is_editor_hint():
		CustomCharacters.load_all(_data)


static func characters() -> Array[CharacterEntry]:
	return data().characters


static func character(id: String) -> CharacterEntry:
	for entry in data().characters:
		if entry.id == id:
			return entry
	return null


# The name to show for a character
static func display_name(id: String) -> String:
	for entry in data().characters:
		if entry.id == id:
			return entry.display_name if entry.display_name != "" else entry.id
	return id.get_slice("~", 0)


# Characters you can pick
static func selectable_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in data().characters:
		ids.append(entry.id)
	return ids


static func character_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in data().characters:
		ids.append(entry.id)
	return ids


static func character_scene(id: String) -> PackedScene:
	var entry := character(id)
	return entry.scene if entry else null


# Boss fights that are switched on, in list order
static func bosses() -> Array[BossEntry]:
	var out: Array[BossEntry] = []
	for entry in data().bosses:
		if entry.enabled and entry.arena:
			out.append(entry)
	return out


static func enemies() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for scene in data().enemies:
		if scene:
			out.append(scene)
	return out


static func level_chunks() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for scene in data().level_chunks:
		if scene:
			out.append(scene)
	return out
