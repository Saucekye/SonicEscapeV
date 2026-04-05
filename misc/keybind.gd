extends Control

var waiting_for_rebind = false
var action_to_rebind = ""
var button_being_rebound = null

# Dictionary to store original default bindings: {action_name: [events]}
var default_bindings = {}

func _ready() -> void:
	# Assign metadata and connect all buttons
	$ForJump/Button.set_meta("action_name", "ui_accept")
	$forDash/Button.set_meta("action_name", "airspin")
	$forDash2/Button.set_meta("action_name", "airup")
	$forTricks/Button.set_meta("action_name", "trick")
	$Left/Button.set_meta("action_name", "ui_left")
	$Right/Button.set_meta("action_name", "ui_right")
	$Up/Button.set_meta("action_name", "ui_up")
	$Down/Button.set_meta("action_name", "ui_down")
	
	for button in [
		$ForJump/Button,
		$forDash/Button,
		$forDash2/Button,  # FIXED: Added missing button
		$forTricks/Button,
		$Left/Button,
		$Right/Button,
		$Up/Button,
		$Down/Button
	]:
		button.focus_mode = Control.FOCUS_ALL
		button.connect("pressed", Callable(self, "_on_bind_button_pressed").bind(button))
	
	# Store initial bindings as defaults
	_backup_default_bindings()
	
	_update_button_texts()

func _backup_default_bindings() -> void:
	# FIXED: Added "airup" to the action list
	for action in ["ui_accept", "airspin", "airup", "trick", "ui_left", "ui_right", "ui_up", "ui_down"]:
		if InputMap.has_action(action):
			var events = InputMap.action_get_events(action)
			default_bindings[action] = []
			
			# Create DEEP COPIES of each event
			for event in events:
				var copied_event = _duplicate_event(event)
				if copied_event:
					default_bindings[action].append(copied_event)
					print("Backed up ", action, ": ", copied_event.as_text())
		else:
			print("WARNING: Action '", action, "' does not exist in InputMap!")

func _duplicate_event(event: InputEvent) -> InputEvent:
	# Create a proper deep copy of an InputEvent
	if event is InputEventKey:
		var new_event = InputEventKey.new()
		new_event.keycode = event.keycode
		new_event.physical_keycode = event.physical_keycode
		new_event.unicode = event.unicode
		new_event.pressed = event.pressed
		return new_event
		
	elif event is InputEventJoypadButton:
		var new_event = InputEventJoypadButton.new()
		new_event.button_index = event.button_index
		new_event.pressed = event.pressed
		return new_event
		
	elif event is InputEventJoypadMotion:
		var new_event = InputEventJoypadMotion.new()
		new_event.axis = event.axis
		new_event.axis_value = event.axis_value
		return new_event
	
	return null

func _on_bind_button_pressed(button: Button) -> void:
	action_to_rebind = button.get_meta("action_name")
	button_being_rebound = button
	waiting_for_rebind = true
	button.text = "Press a key or button..."
	button.grab_focus()
	print("Waiting for input for ", action_to_rebind)
	
	await get_tree().process_frame

func _input(event: InputEvent) -> void:
	if waiting_for_rebind:
		var should_rebind = false
		var new_event = null
		
		# Accept keyboard keys (but ignore Escape)
		if event is InputEventKey and event.pressed and event.keycode != KEY_ESCAPE:
			should_rebind = true
			new_event = event
		
		# Accept controller buttons
		elif event is InputEventJoypadButton and event.pressed:
			should_rebind = true
			new_event = event
		
		# Accept controller axes (analog sticks, triggers)
		elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
			should_rebind = true
			new_event = event
		
		if should_rebind and new_event:
			rebind_action(action_to_rebind, new_event)
			waiting_for_rebind = false
			button_being_rebound = null
			_update_button_texts()
			print("Bound ", action_to_rebind, " to ", new_event.as_text())
			get_viewport().set_input_as_handled()

func rebind_action(action_name: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action_name):
		print("ERROR: Action '", action_name, "' does not exist in InputMap!")
		return
	
	# Check if this input is already bound to another action
	var conflicting_action = _find_action_with_event(new_event, action_name)
	
	if conflicting_action != "":
		var current_events = InputMap.action_get_events(action_name)
		
		print("Swapping bindings between '", action_name, "' and '", conflicting_action, "'")
		
		# Remove the conflicting event from the other action
		InputMap.action_erase_events(conflicting_action)
		
		# Give the conflicting action our old binding (if we had one)
		if current_events.size() > 0:
			var copied_event = _duplicate_event(current_events[0])
			if copied_event:
				InputMap.action_add_event(conflicting_action, copied_event)
	
	# Set the new binding for this action
	InputMap.action_erase_events(action_name)
	var copied_new_event = _duplicate_event(new_event)
	if copied_new_event:
		InputMap.action_add_event(action_name, copied_new_event)
	
	print("Bound '", action_name, "' to ", new_event.as_text())

func _find_action_with_event(event: InputEvent, exclude_action: String) -> String:
	# FIXED: Added "airup" to the action list
	for action in ["ui_accept", "airspin", "airup", "trick", "ui_left", "ui_right", "ui_up", "ui_down"]:
		if not InputMap.has_action(action):
			continue
		if action == exclude_action:
			continue
		
		for bound_event in InputMap.action_get_events(action):
			if _events_match(event, bound_event):
				return action
	
	return ""

func _events_match(event1: InputEvent, event2: InputEvent) -> bool:
	if event1.get_class() != event2.get_class():
		return false
	
	if event1 is InputEventKey:
		return event1.keycode == event2.keycode
	elif event1 is InputEventJoypadButton:
		return event1.button_index == event2.button_index
	elif event1 is InputEventJoypadMotion:
		return event1.axis == event2.axis and sign(event1.axis_value) == sign(event2.axis_value)
	
	return false

func restore_all_bindings() -> void:
	print("=== RESTORING TO DEFAULTS ===")
	
	# Restore all actions to their default state using DEEP COPIES
	for action_name in default_bindings.keys():
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
			
			for event in default_bindings[action_name]:
				var copied_event = _duplicate_event(event)
				if copied_event:
					InputMap.action_add_event(action_name, copied_event)
					print("Restored ", action_name, " to: ", copied_event.as_text())
	
	print("All bindings restored to defaults")
	_update_button_texts()

func _update_button_texts() -> void:
	# FIXED: Added missing button
	for button in [
		$ForJump/Button,
		$forDash/Button,
		$forDash2/Button,
		$forTricks/Button,
		$Left/Button,
		$Right/Button,
		$Up/Button,
		$Down/Button
	]:
		var action = button.get_meta("action_name")
		
		if not InputMap.has_action(action):
			button.text = "ACTION NOT FOUND"
			continue
			
		var events = InputMap.action_get_events(action)
		
		if events.size() > 0:
			button.text = events[0].as_text()
		else:
			button.text = "Unbound"

func _on_button_2_pressed() -> void:
	restore_all_bindings()
