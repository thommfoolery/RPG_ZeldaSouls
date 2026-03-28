# ui/menus/BonfireMenu.gd
extends CanvasLayer

signal bonfire_menu_closed

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var sub_content: Control = %SubContent
@onready var level_up_button: Button = %LevelUpButton
@onready var warp_button: Button = %WarpButton
@onready var attune_button: Button = %AttuneButton   # ← your new button

enum MenuState { MAIN, LEVEL_UP, WARP, ATTUNE }
var state: MenuState = MenuState.MAIN
var current_bonfire_id: String = ""
var level_up_instance: Node = null
var warp_instance: Node = null
var attune_instance: Node = null   # NEW

var selected_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	print("[BonfireMenu-DEBUG] Ready — full-screen integrated menu online")

	# Make sure the new button is visible and connected
	if attune_button:
		attune_button.visible = true

func show_menu(bonfire_id: String) -> void:
	current_bonfire_id = bonfire_id
	visible = true
	Global.is_in_menu = true
	InputManager.input_blocked = true
	state = MenuState.MAIN
	selected_index = 0

	var entry = BonfireManager.get_entry(bonfire_id)
	if entry:
		title_label.text = "Resting at " + entry.title
		subtitle_label.text = entry.subtitle if entry.subtitle else ""
	else:
		title_label.text = "Resting at Bonfire"
		subtitle_label.text = ""

	_show_main_options()
	print("[BonfireMenu-DEBUG] Opened for bonfire: ", bonfire_id)

func _show_main_options() -> void:
	print("[BonfireMenu-DEBUG] _show_main_options() - returning to main menu")
	for child in sub_content.get_children():
		child.queue_free()

	options_container.visible = true
	sub_content.visible = false

	_refresh_highlight()

func _refresh_highlight() -> void:
	if level_up_button:
		level_up_button.modulate = Color(1.0, 0.9, 0.4) if selected_index == 0 else Color.WHITE
	if warp_button:
		warp_button.modulate = Color(1.0, 0.9, 0.4) if selected_index == 1 else Color.WHITE
	if attune_button:
		attune_button.modulate = Color(1.0, 0.9, 0.4) if selected_index == 2 else Color.WHITE

func _input(event: InputEvent) -> void:
	if not visible: return

	# Block thumbstick completely
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return

	# B button (cancel / close)
	if event.is_action_pressed("ui_cancel"):
		Global.menu_close_cooldown_until = Time.get_ticks_msec() + 250
		get_viewport().set_input_as_handled()

		if state != MenuState.MAIN:
			_return_to_main()
		else:
			close_menu()
		return

	if state != MenuState.MAIN:
		return

	# Navigation
	if event.is_action_pressed("ui_down") or event.is_action_pressed("cycle_item_down"):
		selected_index = (selected_index + 1) % 3   # 3 options now
		_refresh_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("cycle_item_up"):
		selected_index = (selected_index - 1 + 3) % 3
		_refresh_highlight()
		get_viewport().set_input_as_handled()

	# Accept
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match selected_index:
			0: _open_level_up()
			1: _open_warp()
			2: _open_attune_menu()

func _return_to_main() -> void:
	if is_instance_valid(level_up_instance):
		level_up_instance.queue_free()
		level_up_instance = null
	if is_instance_valid(warp_instance):
		warp_instance.queue_free()
		warp_instance = null
	if is_instance_valid(attune_instance):
		attune_instance.queue_free()
		attune_instance = null

	_show_main_options()
	state = MenuState.MAIN

# ─── Attune Magic ───────────────────────────────────────────────────
func _open_attune_menu() -> void:
	print("[BonfireMenu-DEBUG] _open_attune_menu() called")
	state = MenuState.ATTUNE
	options_container.visible = false
	sub_content.visible = true

	for child in sub_content.get_children():
		child.queue_free()

	attune_instance = preload("res://scenes/ui/menus/AttuneMenu.tscn").instantiate()  # ← make sure path matches your scene
	sub_content.add_child(attune_instance)

	# Let AttuneMenu handle its own input priority
	if attune_instance.has_method("open_attune_menu"):
		attune_instance.open_attune_menu()

	print("[BonfireMenu-DEBUG] AttuneMenu instanced and opened")

# ─── Existing Level Up & Warp (kept unchanged) ─────────────────────
func _open_level_up() -> void:
	print("[BonfireMenu-DEBUG] _open_level_up() called")
	state = MenuState.LEVEL_UP
	options_container.visible = false
	sub_content.visible = true
	for child in sub_content.get_children():
		child.queue_free()

	level_up_instance = preload("res://scenes/ui/menus/LevelUpMenu.tscn").instantiate()
	sub_content.add_child(level_up_instance)

	var entry = BonfireManager.get_entry(current_bonfire_id)
	if entry and level_up_instance.has_method("set_bonfire_info"):
		level_up_instance.set_bonfire_info("Resting at " + entry.title, entry.subtitle if "subtitle" in entry else "")

	level_up_instance.menu_closed.connect(_on_level_up_closed, CONNECT_ONE_SHOT)

func _on_level_up_closed() -> void:
	print("[BonfireMenu-DEBUG] _on_level_up_closed() received")
	_return_to_main()

func _open_warp() -> void:
	print("[BonfireMenu-DEBUG] _open_warp() called")
	state = MenuState.WARP
	options_container.visible = false
	sub_content.visible = true
	for child in sub_content.get_children():
		child.queue_free()

	warp_instance = preload("res://scenes/ui/menus/WarpMenu.tscn").instantiate()
	sub_content.add_child(warp_instance)

	if warp_instance.has_method("set_current_bonfire"):
		warp_instance.set_current_bonfire(current_bonfire_id)

	warp_instance.warp_selected.connect(_on_warp_to_bonfire)
	warp_instance.menu_closed.connect(_on_warp_closed, CONNECT_ONE_SHOT)

func _on_warp_to_bonfire(bonfire_id: String) -> void:
	print("[BonfireMenu-DEBUG] Warp selected → ", bonfire_id)
	close_menu()
	AreaTransitionService.warp_to_bonfire(bonfire_id)

func _on_warp_closed() -> void:
	print("[BonfireMenu-DEBUG] Warp menu closed - returning to main")
	_return_to_main()

# ─── Close Menu ─────────────────────────────────────────────────────
func close_menu() -> void:
	Global.menu_close_cooldown_until = Time.get_ticks_msec() + 250
	print("[BONFIREMENU-DEBUG] Top-level close triggered — performing rest + save")

	if PlayerStats and PlayerStats.has_method("rest_at_bonfire"):
		PlayerStats.rest_at_bonfire(current_bonfire_id)
		print("[BONFIREMENU-DEBUG] Called PlayerStats.rest_at_bonfire()")
	else:
		push_error("[BONFIREMENU-DEBUG] PlayerStats.rest_at_bonfire() not found!")

	if SaveManager:
		SaveManager.request_save()

	visible = false
	Global.is_in_menu = false
	InputManager.input_blocked = false

	_return_to_main()   # clean up any sub-instances

	bonfire_menu_closed.emit()
	queue_free()
	print("[BonfireMenu] BonfireMenu fully closed and cleaned up")
