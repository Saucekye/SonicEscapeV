extends TextureButton

@export var simulate_key_input: bool = true
@export var simulated_key: int = KEY_SPACE
@export var debug_prints: bool = false

var is_holding_space: bool = false
var active_touch_index: int = -1

signal space_button_pressed
signal space_button_released

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Enable processing to check for global mouse release
	set_process_input(true)

func _on_mouse_entered() -> void:
	# If mouse enters while a button is being held down, activate this button
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_holding_space:
		if debug_prints:
			print(name, ": Mouse entered while pressed - activating")
		is_holding_space = true
		if simulate_key_input:
			_simulate_key_press(true)
		else:
			space_button_pressed.emit()

func _on_mouse_exited() -> void:
	# If mouse leaves while this button is active, deactivate it
	if is_holding_space and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if debug_prints:
			print(name, ": Mouse exited while pressed - deactivating")
		_force_release()

func _on_gui_input(event: InputEvent) -> void:
	# Handle touch press
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index == -1:
			active_touch_index = event.index
			_on_press(event.position)
		elif not event.pressed and active_touch_index == event.index:
			active_touch_index = -1
			_force_release()
	
	# Handle mouse press (for desktop testing)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and active_touch_index == -1:
				active_touch_index = 0
				_on_press(event.position)
			elif not event.pressed and active_touch_index == 0:
				active_touch_index = -1
				_force_release()

func _on_press(position: Vector2) -> void:
	is_holding_space = true
	
	if simulate_key_input:
		_simulate_key_press(true)
	else:
		space_button_pressed.emit()
	
	if debug_prints:
		print(name, ": Button pressed with touch: ", active_touch_index)

func _force_release() -> void:
	if is_holding_space:
		is_holding_space = false
		
		if simulate_key_input:
			_simulate_key_press(false)
		else:
			space_button_released.emit()
		
		if debug_prints:
			print(name, ": Button released")

func _simulate_key_press(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = simulated_key
	event.pressed = pressed
	Input.parse_input_event(event)
	
	if debug_prints:
		print(name, ": Simulated key ", simulated_key, " pressed: ", pressed)

func _input(event: InputEvent) -> void:
	# Catch global mouse release to ensure buttons always release
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_holding_space:
				if debug_prints:
					print(name, ": Global mouse release detected - forcing release")
				_force_release()
	
	# Debug key presses
	if event is InputEventKey and event.pressed:
		print(event.keycode, " ", event.as_text())
