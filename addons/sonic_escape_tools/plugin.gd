@tool
extends EditorPlugin
## Adds the "Sonic Escape" panel below the Inspector.

var dock: EditorDock


func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.title = "Sonic Escape"
	dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	dock.layout_key = "SonicEscapeTools"
	var panel: Control = preload("res://addons/sonic_escape_tools/dock.gd").new()
	panel.name = "Panel"
	dock.add_child(panel)
	add_dock(dock)
	dock.open()


func _exit_tree() -> void:
	if dock:
		remove_dock(dock)
		dock.queue_free()
		dock = null
