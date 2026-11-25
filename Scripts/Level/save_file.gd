class_name SaveFile
extends RefCounted
# Export / import the whole save

# The files that make up a save
const FILES := ["settings.cfg", "playlists.cfg"]
const DOWNLOAD_NAME := "sonic-escape-save.json"
const GAME_ID := "Sonic Escape"


# Everything in one piece of text
static func export_text() -> String:
	var files := {}
	for f in FILES:
		var path: String = "user://" + f
		if FileAccess.file_exists(path):
			files[f] = FileAccess.get_file_as_string(path)
	return JSON.stringify({"game": GAME_ID, "version": 1, "saved": Time.get_datetime_string_from_system(), "files": files}, "  ")


# Put a downloaded save back
static func import_text(text: String) -> String:
	var data = JSON.parse_string(text)
	if not (data is Dictionary) or str(data.get("game", "")) != GAME_ID or not (data.get("files") is Dictionary):
		return "That isn't a Sonic Escape save file."
	for f in data.files:
		if not f in FILES:
			continue   # only the game's own files, nothing else
		var check := ConfigFile.new()
		if check.parse(str(data.files[f])) != OK:
			return "That save file is damaged (%s)." % f
	for f in data.files:
		if f in FILES:
			var out := FileAccess.open("user://" + f, FileAccess.WRITE)
			if out == null:
				return "Couldn't write the save (%s)." % error_string(FileAccess.get_open_error())
			out.store_string(str(data.files[f]))
			out.close()
	return ""


# Save the file to the player's computer
static func download(done: Callable) -> void:
	var text := export_text()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), DOWNLOAD_NAME, "application/json")
		done.call("Downloaded %s. Load it on another browser or computer with Load Save." % DOWNLOAD_NAME)
		return
	var folder := _documents()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Save your Sonic Escape save", folder, DOWNLOAD_NAME, false,
				DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json ; Save file"]),
				func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
					if ok and not paths.is_empty():
						done.call(_write(paths[0], text))
					else:
						done.call(""))
	else:
		done.call(_write(folder.path_join(DOWNLOAD_NAME), text))


# The Documents folder
static func _documents() -> String:
	var folder := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return folder if folder != "" else OS.get_user_data_dir()


static func _write(path: String, text: String) -> String:
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return "Couldn't save to %s." % path
	out.store_string(text)
	out.close()
	return "Saved to %s" % path


# Ask the player for a save file and load it
static func upload(done: Callable) -> void:
	if OS.has_feature("web"):
		_web_pick(done)
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var path := _documents().path_join(DOWNLOAD_NAME)
		if FileAccess.file_exists(path):
			_loaded(FileAccess.get_file_as_string(path), done)
		else:
			done.call("Put %s in your Documents folder, then press Load Save again." % DOWNLOAD_NAME, false)
		return
	DisplayServer.file_dialog_show("Load a Sonic Escape save", _documents(), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json ; Save file"]),
			func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
				if ok and not paths.is_empty():
					_loaded(FileAccess.get_file_as_string(paths[0]), done)
				else:
					done.call("", false))


static func _loaded(text: String, done: Callable) -> void:
	var problem := import_text(text)
	if problem != "":
		done.call(problem, false)
	else:
		done.call("Save loaded! Restarting the game...", true)


# The browser's file picker
static var _js_callback: JavaScriptObject   # kept alive while the picker is open
static var _web_done: Callable


static func _web_pick(done: Callable) -> void:
	_web_done = done
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window := JavaScriptBridge.get_interface("window")
	window.sonicEscapeSaveLoaded = _js_callback
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) { return; }
				var reader = new FileReader();
				reader.onload = function () { window.sonicEscapeSaveLoaded(reader.result); };
				reader.readAsText(file);
			};
			input.click();
		})();
	""", true)


static func _on_web_file(args: Array) -> void:
	if args.is_empty():
		return
	_loaded(str(args[0]), _web_done)


# Start the game again so everything loaded takes effect
static func restart(tree: SceneTree) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.reload();")
	else:
		OS.set_restart_on_exit(true)
		tree.quit()
