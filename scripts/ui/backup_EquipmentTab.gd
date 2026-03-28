# scripts/ui/EquipmentTab.gd
extends Panel

@onready var slots_container = get_node_or_null("MainContainer/SlotsContainer")
@onready var selection_panel: Panel = get_node_or_null("SelectionPanel")
@onready var selection_grid: GridContainer = get_node_or_null("SelectionPanel/ScrollContainer/SelectionGrid")

var slots: Array[Button] = []
var selected_slot_index: int = 0
var in_selection_mode: bool = false
var selected_option_index: int = 0

func _ready() -> void:
	if selection_panel:
		selection_panel.visible = false
	
	if not EquipmentManager:
		push_error("[EquipmentTab] EquipmentManager missing!")
		return
	
	EquipmentManager.equipped_changed.connect(_on_equipped_changed)
	
	if slots_container:
		for child in slots_container.get_children():
			if child is Button:
				slots.append(child)
	
	if EquipmentManager.equipped.size() != 15:
		EquipmentManager.equipped.resize(15)
	
	_refresh_all_slot_visuals()
	print("[EquipmentTab] Ready — ", slots.size(), " slots connected")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_refresh_all_slot_visuals")


func _input(event: InputEvent) -> void:
	if not visible or not Global.is_in_menu:
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	
	if in_selection_mode:
		_handle_selection_input(event)
	else:
		_handle_slot_input(event)


func _handle_slot_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_item_up"):
		selected_slot_index = wrapi(selected_slot_index - 1, 0, slots.size())
		_refresh_all_slot_visuals()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down"):
		selected_slot_index = wrapi(selected_slot_index + 1, 0, slots.size())
		_refresh_all_slot_visuals()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if selected_slot_index < slots.size():
			_on_slot_pressed(selected_slot_index)
			get_viewport().set_input_as_handled()


func _handle_selection_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_item_up"):
		selected_option_index = wrapi(selected_option_index - 1, 0, selection_grid.get_child_count())
		_update_selection_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down"):
		selected_option_index = wrapi(selected_option_index + 1, 0, selection_grid.get_child_count())
		_update_selection_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_equip_selected_item()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_exit_selection_mode()
		get_viewport().set_input_as_handled()


func _on_slot_pressed(idx: int) -> void:
	selected_slot_index = idx
	in_selection_mode = true
	if selection_panel: 
		selection_panel.visible = true
	selected_option_index = 0
	_populate_selection_grid(idx)   # Pass slot index for filtering
	_update_selection_highlight()


# NEW: Filter items based on slot type
func _populate_selection_grid(slot_idx: int) -> void:
	if not selection_grid: return
	
	# Clear old buttons
	for child in selection_grid.get_children():
		child.queue_free()
	
	var allowed_category = get_allowed_category_for_slot(slot_idx)
	var items = []
	
	if allowed_category == "Ammo":
		items = PlayerInventory.inventory.get("Ammo", [])
	elif allowed_category == "Weapon":
		items = PlayerInventory.inventory.get("Weapons", [])
	
	for item in items:
		var btn = Button.new()
		btn.text = item.display_name + " x" + str(item.quantity)
		btn.custom_minimum_size = Vector2(200, 48)
		btn.set_meta("item", item)
		btn.pressed.connect(_on_selection_button_pressed.bind(item))
		selection_grid.add_child(btn)
	
	# Stronger guarantee that UI has updated before highlighting
	selected_option_index = 0
	get_tree().create_timer(0.02).timeout.connect(_force_first_item_highlight)


func _force_first_item_highlight() -> void:
	var buttons = selection_grid.get_children()
	if buttons.is_empty():
		return
	
	selected_option_index = 0
	for i in buttons.size():
		if buttons[i]:
			buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == 0 else Color.WHITE
			if i == 0:
				buttons[i].grab_focus()


func get_allowed_category_for_slot(slot_idx: int) -> String:
	if slot_idx in [8, 9]:           # Arrow1, Arrow2
		return "Ammo"
	elif slot_idx in [0, 1, 2, 3]:   # Weapon hands
		return "Weapon"
	elif slot_idx in [10,11,12,13,14]: # Use slots
		return "Consumables"
	else:                            # Armor slots
		return "Armor"


func _on_selection_button_pressed(item: GameItem) -> void:
	EquipmentManager.equip_to_slot(selected_slot_index, item)
	_exit_selection_mode()   # ← Make sure this also closes


func _equip_selected_item() -> void:
	if not selection_grid: return
	var buttons = selection_grid.get_children()
	if selected_option_index < 0 or selected_option_index >= buttons.size():
		return
	var item = buttons[selected_option_index].get_meta("item") as GameItem
	if item:
		EquipmentManager.equip_to_slot(selected_slot_index, item)
		_exit_selection_mode()   # ← This was missing


func _exit_selection_mode() -> void:
	in_selection_mode = false
	if selection_panel: 
		selection_panel.visible = false
	_refresh_all_slot_visuals()


func _refresh_all_slot_visuals() -> void:
	for i in slots.size():
		if slots[i]:
			var item = EquipmentManager.get_equipped_item(i)
			if item:
				slots[i].text = item.display_name + " x" + str(item.quantity)
				slots[i].modulate = Color(1.0, 0.9, 0.4) if i == selected_slot_index else Color.WHITE
			else:
				slots[i].text = slots[i].name
				slots[i].modulate = Color.WHITE if i == selected_slot_index else Color(0.8, 0.8, 0.8)
	
	if selected_slot_index < slots.size() and slots[selected_slot_index]:
		slots[selected_slot_index].grab_focus()


func _update_selection_highlight() -> void:
	if not selection_grid: return
	var buttons = selection_grid.get_children()
	for i in buttons.size():
		if buttons[i]:
			buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == selected_option_index else Color.WHITE
			if i == selected_option_index:
				buttons[i].grab_focus()   # This helps with visual feedback


func _on_equipped_changed(_slot_index: int, _new_item: GameItem) -> void:
	_refresh_all_slot_visuals()
