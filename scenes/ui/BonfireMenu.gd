# ui/menus/BonfireMenu.gd
extends CanvasLayer

signal bonfire_menu_closed

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var sub_content: Control = %SubContent

@onready var level_up_button: Button = %LevelUpButton
@onready var warp_button: Button = %WarpButton
@onready var attune_button: Button = %AttuneButton
@onready var upgrade_estus_button: Button = %UpgradeEstusButton   # ← NEW for Estus upgrades

enum MenuState { MAIN, LEVEL_UP, WARP, ATTUNE, UPGRADE_ESTUS }
var state: MenuState = MenuState.MAIN

var current_bonfire_id: String = ""
var level_up_instance: Node = null
var warp_instance: Node = null
var attune_instance: Node = null
var upgrade_estus_instance: Node = null   # Holds the upgrade sub-panel

var selected_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	print("[BonfireMenu-DEBUG] Ready — full-screen integrated menu online")

	# Make sure the new Upgrade Estus button is visible
	if upgrade_estus_button:
		upgrade_estus_button.visible = true

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
	if upgrade_estus_button:
		upgrade_estus_button.modulate = Color(1.0, 0.9, 0.4) if selected_index == 3 else Color.WHITE

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

	# Navigation - now 4 options
	if event.is_action_pressed("ui_down") or event.is_action_pressed("cycle_item_down"):
		selected_index = (selected_index + 1) % 4
		_refresh_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("cycle_item_up"):
		selected_index = (selected_index - 1 + 4) % 4
		_refresh_highlight()
		get_viewport().set_input_as_handled()

	# Accept
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match selected_index:
			0: _open_level_up()
			1: _open_warp()
			2: _open_attune_menu()
			3: _open_upgrade_estus_menu()

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
	if is_instance_valid(upgrade_estus_instance):
		upgrade_estus_instance.queue_free()
		upgrade_estus_instance = null

	_show_main_options()
	state = MenuState.MAIN

# ─── NEW: Upgrade Estus Menu (two separate options) ─────────────────────
func _open_upgrade_estus_menu() -> void:
	print("[BonfireMenu-DEBUG] === _open_upgrade_estus_menu() START ===")
	state = MenuState.UPGRADE_ESTUS
	options_container.visible = false
	sub_content.visible = true

	for child in sub_content.get_children():
		child.queue_free()

	# Create panel and center it
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(280, 350)

	sub_content.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 32)
	panel.add_child(vbox)

	print("[BonfireMenu-DEBUG] Panel and VBox created and centered")

	# Title
	var title = Label.new()
	title.text = "Upgrade Estus"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# === CAPACITY BUTTON ===
	var cap_btn = Button.new()
	cap_btn.name = "CapacityButton"
	cap_btn.custom_minimum_size = Vector2(0, 110)
	cap_btn.add_theme_font_size_override("font_size", 24)
	
	
	var has_capacity = PlayerInventory.has_enough("estus_capacity", 1) if PlayerInventory else false
	var at_cap_max = PlayerStats.estus_max_charges_level >= PlayerStats.MAX_UPGRADE_LEVEL
	
	if has_capacity and not at_cap_max:
		cap_btn.text = "Upgrade Capacity\n(+1 maximum charge)\nCost: 1 Estus Capacity"
		cap_btn.pressed.connect(_try_upgrade_capacity)
		print("[BonfireMenu-DEBUG] Capacity button ENABLED")
	else:
		cap_btn.text = "Upgrade Capacity\n" + ("MAXIMUM REACHED" if at_cap_max else "No Estus Capacity found")
		cap_btn.disabled = true
		cap_btn.modulate = Color(0.55, 0.55, 0.55, 1.0)
		print("[BonfireMenu-DEBUG] Capacity button DISABLED - has_item:", has_capacity, " at_max:", at_cap_max)
	vbox.add_child(cap_btn)

	# === POTENCY BUTTON ===
	var pot_btn = Button.new()
	pot_btn.name = "PotencyButton"
	pot_btn.custom_minimum_size = Vector2(0, 110)
	pot_btn.add_theme_font_size_override("font_size", 24)
	
	var has_potency = PlayerInventory.has_enough("estus_potency", 1) if PlayerInventory else false
	var at_pot_max = PlayerStats.estus_heal_level >= PlayerStats.MAX_UPGRADE_LEVEL
	
	if has_potency and not at_pot_max:
		pot_btn.text = "Upgrade Potency\n(increased heal amount)\nCost: 1 Estus Potency"
		pot_btn.pressed.connect(_try_upgrade_potency)
		print("[BonfireMenu-DEBUG] Potency button ENABLED")
	else:
		pot_btn.text = "Upgrade Potency\n" + ("MAXIMUM REACHED" if at_pot_max else "No Estus Potency found")
		pot_btn.disabled = true
		pot_btn.modulate = Color(0.55, 0.55, 0.55, 1.0)
		print("[BonfireMenu-DEBUG] Potency button DISABLED - has_item:", has_potency, " at_max:", at_pot_max)
	vbox.add_child(pot_btn)

	# Success feedback label
	var success_label = Label.new()
	success_label.name = "SuccessLabel"
	success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_label.add_theme_font_size_override("font_size", 28)
	success_label.modulate.a = 0.0
	vbox.add_child(success_label)

	# Back hint
	var back = Label.new()
	back.text = "A : Confirm Upgrade"
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(back)

	upgrade_estus_instance = panel

	# CRITICAL: Setup focus chain + grab focus
	cap_btn.focus_neighbor_bottom = pot_btn.get_path()
	pot_btn.focus_neighbor_top = cap_btn.get_path()
	
	if not cap_btn.disabled:
		cap_btn.grab_focus()
		print("[BonfireMenu-DEBUG] Focus given to CapacityButton")
	elif not pot_btn.disabled:
		pot_btn.grab_focus()
		print("[BonfireMenu-DEBUG] Focus given to PotencyButton (capacity was disabled)")
	else:
		print("[BonfireMenu-DEBUG] WARNING: Both buttons disabled - no focus given")

	print("[BonfireMenu-DEBUG] === _open_upgrade_estus_menu() FINISHED ===")

func _try_upgrade_capacity() -> void:
	print("[BonfireMenu-DEBUG] _try_upgrade_capacity() called")
	if PlayerStats.upgrade_estus_capacity():
		_show_upgrade_success("ESTUS CAPACITY UPGRADED", "+1 maximum charge")
	else:
		print("[BonfireMenu-DEBUG] Capacity upgrade failed")

func _try_upgrade_potency() -> void:
	print("[BonfireMenu-DEBUG] _try_upgrade_potency() called")
	if PlayerStats.upgrade_estus_potency():
		_show_upgrade_success("ESTUS POTENCY UPGRADED", "Heal amount increased")
	else:
		print("[BonfireMenu-DEBUG] Potency upgrade failed")

# Helper to show nice feedback
func _show_upgrade_success(main_text: String, subtitle: String) -> void:
	var success_label = upgrade_estus_instance.get_node_or_null("SuccessLabel") as Label
	if success_label:
		success_label.text = main_text + "\n" + subtitle
		success_label.modulate = Color(0.95, 0.85, 0.4, 1.0)
	
	# Also show a nice title card (like area discovery)
	TitleCardManager.show_title(main_text, subtitle, 3.0, true, false)
	
	# Refresh the menu so buttons update (gray out if now maxed)
	await get_tree().create_timer(0.6).timeout
	_open_upgrade_estus_menu()  # re-open to refresh disabled state
# ─── Existing functions (unchanged) ─────────────────────────────────────
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

func _open_attune_menu() -> void:
	print("[BonfireMenu-DEBUG] _open_attune_menu() called")
	state = MenuState.ATTUNE
	options_container.visible = false
	sub_content.visible = true
	for child in sub_content.get_children():
		child.queue_free()

	attune_instance = preload("res://scenes/ui/menus/AttuneMenu.tscn").instantiate()
	sub_content.add_child(attune_instance)

	if attune_instance.has_method("open_attune_menu"):
		attune_instance.open_attune_menu()
	print("[BonfireMenu-DEBUG] AttuneMenu instanced and opened")

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
