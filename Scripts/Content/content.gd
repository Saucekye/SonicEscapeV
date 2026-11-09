@tool
class_name Content
## Read access to game_content.tres from anywhere: Content.characters(), Content.bosses()...

const PATH := "res://game_content.tres"

static var _data: GameContent


static func data() -> GameContent:
	if _data == null:
		_data = load(PATH) as GameContent
	return _data


static func characters() -> Array[CharacterEntry]:
	return data().characters


static func character(id: String) -> CharacterEntry:
	for entry in data().characters:
		if entry.id == id:
			return entry
	return null


static func character_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in data().characters:
		ids.append(entry.id)
	return ids


static func character_scene(id: String) -> PackedScene:
	var entry := character(id)
	return entry.scene if entry else null


## Boss fights that are switched on, in list order
static func bosses() -> Array[BossEntry]:
	var out: Array[BossEntry] = []
	for entry in data().bosses:
		if entry.enabled and entry.arena:
			out.append(entry)
	return out


static func level_chunks() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	for scene in data().level_chunks:
		if scene:
			out.append(scene)
	return out
