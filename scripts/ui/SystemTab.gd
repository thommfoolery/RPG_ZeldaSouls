# scripts/ui/SystemTab.gd
extends Panel

@onready var buttons: Array[Button] = [
	$SystemVBox/ResumeButton,
	$SystemVBox/SaveButton,
	$SystemVBox/DebugPrintButton,
	$SystemVBox/DebugResetButton,
	$SystemVBox/QuitButton
]

@onready var confirmation_container: VBoxContainer = $SystemVBox/ConfirmationContainer
@onready var confirm_label: Label = $SystemVBox/ConfirmationContainer/ConfirmLabel
@onready var yes_button: Button = $SystemVBox/ConfirmationContainer/YesButton
@onready var no_button: Button = $SystemVBox/ConfirmationContainer/NoButton

@onready var feedback_label: Label = $SystemVBox/FeedbackLabel

var selected_index: int = 0
var in_confirmation: bool = false

func _ready() -> void:
	if feedback_label:
		feedback_label.visible = false
	if confirmation_container:
		confirmation_container.visible = false
	
	# Connect main buttons
	if buttons[0]: buttons[0].pressed.connect(_on_resume)
	if buttons[1]: buttons[1].pressed.connect(_on_save)
	if buttons[2]: buttons[2].pressed.connect(_on_debug_print)
	if buttons[3]: buttons[3].pressed.connect(_on_debug_reset)
	if buttons[4]: buttons[4].pressed.connect(_on_quit_pressed)
	
	# Connect confirmation buttons
	if yes_button: yes_button.pressed.connect(_on_confirm_quit)
	if no_button: no_button.pressed.connect(_cancel_confirmation)
	
	# Listen for menu being fully closed
	var menu_controller = get_parent().get_parent()
	if menu_controller and menu_controller.has_signal("menu_closed"):
		menu_controller.menu_closed.connect(_on_menu_closed)
	
	print("[SystemTab] Ready — Save & Quit with confirmation")
	_update_selection()


func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	
	if in_confirmation:
		_handle_confirmation_input(event)
	else:
		_handle_normal_input(event)


func _handle_normal_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_item_up"):
		selected_index = wrapi(selected_index - 1, 0, buttons.size())
		_update_selection()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("cycle_item_down"):
		selected_index = wrapi(selected_index + 1, 0, buttons.size())
		_update_selection()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if buttons[selected_index]:
			buttons[selected_index].pressed.emit()
			get_viewport().set_input_as_handled()


func _handle_confirmation_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_item_up") or event.is_action_pressed("cycle_item_down"):
		var is_yes = yes_button.modulate == Color(1.0, 0.9, 0.4)
		yes_button.modulate = Color(1.0, 0.9, 0.4) if not is_yes else Color(1.0, 1.0, 1.0)
		no_button.modulate = Color(1.0, 0.9, 0.4) if is_yes else Color(1.0, 1.0, 1.0)
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if yes_button.modulate == Color(1.0, 0.9, 0.4):
			_on_confirm_quit()
		else:
			_cancel_confirmation()
		get_viewport().set_input_as_handled()


func _update_selection() -> void:
	for i in buttons.size():
		var btn = buttons[i]
		if btn:
			btn.modulate = Color(1.0, 0.9, 0.4) if i == selected_index else Color(1.0, 1.0, 1.0)
	
	if buttons[selected_index]:
		buttons[selected_index].grab_focus()


func _on_quit_pressed() -> void:
	in_confirmation = true
	for btn in buttons:
		if btn: btn.visible = false
	confirmation_container.visible = true
	yes_button.modulate = Color(1.0, 0.9, 0.4)
	no_button.modulate = Color(1.0, 1.0, 1.0)


func _on_confirm_quit() -> void:
	if SaveManager:
		SaveManager.request_save()
	
	_show_feedback("Saving...", 1.2, Color(0.9, 0.9, 0.9))
	await get_tree().create_timer(1.3).timeout
	
	get_parent().get_parent()._on_menu_toggled()
	get_tree().change_scene_to_file("res://scenes/ui/man_menu.tscn")


func _cancel_confirmation() -> void:
	in_confirmation = false
	confirmation_container.visible = false
	for btn in buttons:
		if btn: btn.visible = true
	_update_selection()


func _on_menu_closed() -> void:
	in_confirmation = false
	if confirmation_container:
		confirmation_container.visible = false
	for btn in buttons:
		if btn: btn.visible = true
	_update_selection()


# ─── Other button functions ─────────────────────────────────────
func _on_resume() -> void:
	get_parent().get_parent()._on_menu_toggled()

func _on_save() -> void:
	if SaveManager:
		SaveManager.request_save()
		_show_feedback("Game Saved ✓", 1.5, Color(0.2, 1.0, 0.3))
	else:
		_show_feedback("SaveManager missing!", 2.0, Color.RED)

func _on_debug_print() -> void:
	if WorldStateManager:
		print("\n=== WORLD STATE DEBUG ===")
		for path in WorldStateManager.world_state:
			var s = WorldStateManager.world_state[path]
			print("Scene: ", path.get_file())
			print(" Regular dead: ", s.get("regular_dead_enemies", []))
			print(" Permanent: ", s.get("permanent", {}))
		_show_feedback("World state printed", 2.0)
	else:
		_show_feedback("WorldStateManager missing", 2.0, Color.RED)

func _on_debug_reset() -> void:
	if WorldStateManager:
		WorldStateManager.reset_all_regular_enemies()
		_show_feedback("Regular enemies reset", 2.0)
	else:
		_show_feedback("WorldStateManager missing", 2.0, Color.RED)

func _show_feedback(text: String, duration: float = 2.0, color: Color = Color(0.2, 1.0, 0.3)) -> void:
	if feedback_label:
		feedback_label.modulate = color
		feedback_label.text = text
		feedback_label.visible = true
		get_tree().create_timer(duration).timeout.connect(func():
			if feedback_label: feedback_label.visible = false
		)
