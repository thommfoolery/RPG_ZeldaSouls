# scenes/ui/menus/TalkMenu.gd
extends CanvasLayer

@onready var title_label: Label = $Panel/TitleLabel
@onready var greeting_label: Label = $Panel/GreetingLabel
@onready var options_container: VBoxContainer = $Panel/OptionsContainer

@onready var buy_button: Button = $Panel/OptionsContainer/BuyButton
@onready var talk_button: Button = $Panel/OptionsContainer/TalkButton
@onready var leave_button: Button = $Panel/OptionsContainer/LeaveButton

var current_vendor_id: String = ""
var selected_index: int = 0
var buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	
	buttons = [buy_button, talk_button, leave_button]
	
	# Connect buttons as fallback
	buy_button.pressed.connect(_on_buy_pressed)
	talk_button.pressed.connect(_on_talk_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	_highlight_current()

func open_for_vendor(vendor_id: String) -> void:
	current_vendor_id = vendor_id
	var vendor = VendorManager._get_vendor(vendor_id)
	if not vendor:
		queue_free()
		return
	
	title_label.text = vendor.display_name
	greeting_label.text = vendor.greeting
	
	visible = true
	Global.is_in_menu = true
	InputManager.input_blocked = true
	
	# Prevent immediate back-step when opening from interaction
	Global.menu_close_cooldown_until = Time.get_ticks_msec() + 500
	
	selected_index = 0
	_highlight_current()
	
	print("[TalkMenu] Opened for vendor: ", vendor_id)

# ─── Navigation ─────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible: return
	
	# Eat ALL input while menu is open
	get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		_close_menu()
		return
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("cycle_item_up"):
		selected_index = wrapi(selected_index - 1, 0, buttons.size())
		_highlight_current()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("cycle_item_down"):
		selected_index = wrapi(selected_index + 1, 0, buttons.size())
		_highlight_current()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_execute_selected()

func _highlight_current() -> void:
	for i in buttons.size():
		if buttons[i]:
			buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == selected_index else Color(1.0, 1.0, 1.0)

func _execute_selected() -> void:
	match selected_index:
		0: _on_buy_pressed()
		1: _on_talk_pressed()
		2: _on_leave_pressed()

# ─── Button Actions ─────────────────────────────────────────────────────
func _on_buy_pressed() -> void:
	_close_menu()
	VendorManager.open_vendor(current_vendor_id)

func _on_talk_pressed() -> void:
	var vendor = VendorManager._get_vendor(current_vendor_id)
	if vendor:
		greeting_label.text = vendor.greeting + "\n\n(You chat for a while...)"

func _on_leave_pressed() -> void:
	_close_menu()

func _close_menu() -> void:
	Global.menu_close_cooldown_until = Time.get_ticks_msec() + 250
	
	visible = false
	Global.is_in_menu = false
	InputManager.input_blocked = false
	queue_free()
	print("[TalkMenu] Closed cleanly")
