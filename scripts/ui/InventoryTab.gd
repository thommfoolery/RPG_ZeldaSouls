# scripts/ui/InventoryTab.gd
extends Panel

# Category & Grid
@onready var category_buttons: Array[Button] = [
	$CategoryBar/ConsumablesTab, $CategoryBar/KeysTab, $CategoryBar/MaterialsTab,
	$CategoryBar/SpellsTab, $CategoryBar/WeaponsTab, $CategoryBar/AmmoTab,
	$CategoryBar/ArmorTab, $CategoryBar/RingsTab, $CategoryBar/QuestTab
]

@onready var item_grid: GridContainer = $MainContainer/ItemScroll/ItemGrid

# Details Panel
@onready var details_icon: TextureRect = $MainContainer/DetailsPanel/Icon
@onready var details_name: Label = $MainContainer/DetailsPanel/NameLabel
@onready var details_description: Label = $MainContainer/DetailsPanel/DescriptionLabel

# Context Menu
@onready var context_menu: Control = $ContextMenu
@onready var context_use: Button = $ContextMenu/UseButton
@onready var context_drop: Button = $ContextMenu/DropButton
@onready var context_discard: Button = $ContextMenu/DiscardButton

# Quantity Selector
@onready var quantity_selector: Control = $QuantitySelector
@onready var qty_label: Label = $QuantitySelector/QTYLabel
@onready var qty_confirm: Button = $QuantitySelector/HBoxContainer/ConfirmButton
@onready var qty_cancel: Button = $QuantitySelector/HBoxContainer/CancelButton

var current_category_index: int = 0
var current_item_index: int = 0
var current_items: Array = []

var is_context_open: bool = false
var selected_context_index: int = 0

var _pending_item: GameItem = null
var _selected_qty: int = 1
var _qty_hold_timer: float = 0.0
var _qty_hold_direction: int = 0   # 1 = up, -1 = down

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	
	if not context_menu: push_warning("[InventoryTab] ContextMenu not found")
	if not quantity_selector: push_warning("[InventoryTab] QuantitySelector not found")
	
	# Category buttons
	for i in category_buttons.size():
		if category_buttons[i]:
			category_buttons[i].pressed.connect(_on_category_pressed.bind(i))
	
	# Context menu buttons
	if context_use: context_use.pressed.connect(_on_context_use)
	if context_drop: context_drop.pressed.connect(_on_context_drop)
	if context_discard: context_discard.pressed.connect(_on_context_discard)
	
	# Quantity selector
	if qty_confirm: qty_confirm.pressed.connect(_confirm_quantity)
	if qty_cancel: qty_cancel.pressed.connect(_cancel_quantity)
	
	if context_menu: context_menu.visible = false
	if quantity_selector: quantity_selector.visible = false
	
	PlayerInventory.inventory_changed.connect(_refresh_current_category)
	
	print("[InventoryTab] Ready — Context menu on A + quantity selector for Drop/Discard")
	_switch_category(current_category_index)

func _process(delta: float) -> void:
	if _qty_hold_direction != 0 and quantity_selector and quantity_selector.visible:
		_qty_hold_timer += delta
		if _qty_hold_timer > 0.12:   # accelerate while holding
			_change_quantity(_qty_hold_direction)
			_qty_hold_timer = 0.06

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	
	if is_context_open or (quantity_selector and quantity_selector.visible):
		_handle_menu_input(event)
		return
	
	# Normal inventory navigation
	if event.is_action_pressed("cycle_left_hand") or event.is_action_pressed("ui_left"):
		_switch_category(current_category_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_right_hand") or event.is_action_pressed("ui_right"):
		_switch_category(current_category_index + 1)
		get_viewport().set_input_as_handled()
	
	if current_items.is_empty(): return
	
	if event.is_action_pressed("cycle_item_up") or event.is_action_pressed("ui_up"):
		current_item_index = wrapi(current_item_index - 1, 0, current_items.size())
		_refresh_current_category()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down") or event.is_action_pressed("ui_down"):
		current_item_index = wrapi(current_item_index + 1, 0, current_items.size())
		_refresh_current_category()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_open_context_menu()
		get_viewport().set_input_as_handled()

func _handle_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel_quantity()
		_close_context_menu()
		get_viewport().set_input_as_handled()
		return
	
	if quantity_selector and quantity_selector.visible:
		_handle_quantity_input(event)
		return
	
	# Context menu navigation
	if event.is_action_pressed("cycle_item_up") or event.is_action_pressed("ui_up"):
		selected_context_index = wrapi(selected_context_index - 1, 0, 3)
		_highlight_context()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down") or event.is_action_pressed("ui_down"):
		selected_context_index = wrapi(selected_context_index + 1, 0, 3)
		_highlight_context()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_execute_context_action()
		get_viewport().set_input_as_handled()

func _handle_quantity_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_item_up") or event.is_action_pressed("ui_up"):
		_change_quantity(1)
		_qty_hold_direction = 1
		_qty_hold_timer = 0.0
	elif event.is_action_pressed("cycle_item_down") or event.is_action_pressed("ui_down"):
		_change_quantity(-1)
		_qty_hold_direction = -1
		_qty_hold_timer = 0.0
	elif event.is_action_released("cycle_item_up") or event.is_action_released("cycle_item_down"):
		_qty_hold_direction = 0

func _change_quantity(direction: int) -> void:
	if not _pending_item: return
	var max_q = _pending_item.quantity if "quantity" in _pending_item else 99
	if direction > 0:
		_selected_qty = wrapi(_selected_qty + 1, 1, max_q + 1)
	else:
		_selected_qty = wrapi(_selected_qty - 1, 1, max_q + 1)
	_update_quantity_display()

func _update_quantity_display() -> void:
	if not qty_label or not _pending_item: return
	var max_q = _pending_item.quantity if "quantity" in _pending_item else 99
	qty_label.text = "Quantity: " + str(_selected_qty) + " / " + str(max_q)

func _open_context_menu() -> void:
	if current_item_index >= current_items.size(): return
	var item = current_items[current_item_index]
	if not item: return
	
	is_context_open = true
	selected_context_index = 0
	if context_menu:
		context_menu.visible = true
		_update_context_button_states(item)
	_highlight_context()
	print("[InventoryTab] Context menu opened for ", item.display_name)

func _update_context_button_states(item: GameItem) -> void:
	if context_use:
		context_use.disabled = not item.can_use
		context_use.modulate = Color(0.6, 0.6, 0.6) if not item.can_use else Color(1,1,1)
	if context_drop:
		context_drop.disabled = not item.can_drop
		context_drop.modulate = Color(0.6, 0.6, 0.6) if not item.can_drop else Color(1,1,1)
	if context_discard:
		context_discard.disabled = not item.can_discard
		context_discard.modulate = Color(0.6, 0.6, 0.6) if not item.can_discard else Color(1,1,1)

func _close_context_menu() -> void:
	is_context_open = false
	if context_menu:
		context_menu.visible = false

func _highlight_context() -> void:
	var buttons = [context_use, context_drop, context_discard]
	for i in 3:
		if buttons[i]:
			buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == selected_context_index else Color(1.0, 1.0, 1.0)

func _execute_context_action() -> void:
	if current_item_index >= current_items.size(): return
	var item = current_items[current_item_index]
	if not item: return
	
	match selected_context_index:
		0: # Use
			if item.can_use:
				QuickUseHandler.use_item(item)
		1, 2: # Drop or Discard
			if (selected_context_index == 1 and item.can_drop) or (selected_context_index == 2 and item.can_discard):
				_pending_item = item
				_selected_qty = 1
				if quantity_selector:
					quantity_selector.visible = true
					_update_quantity_display()
					if qty_confirm: qty_confirm.grab_focus()
				else:
					if selected_context_index == 1:
						QuickUseHandler.drop_item(item, 1)
					else:
						QuickUseHandler.discard_item(item, 1)
	
	_close_context_menu()

func _confirm_quantity() -> void:
	if _pending_item:
		if selected_context_index == 1:   # Drop
			QuickUseHandler.drop_item(_pending_item, _selected_qty)
		else:   # Discard
			QuickUseHandler.discard_item(_pending_item, _selected_qty)
	_pending_item = null
	if quantity_selector:
		quantity_selector.visible = false

func _cancel_quantity() -> void:
	_pending_item = null
	if quantity_selector:
		quantity_selector.visible = false

# Context button fallback handlers
func _on_context_use() -> void:
	if current_item_index >= current_items.size(): return
	var item = current_items[current_item_index]
	if item and item.can_use:
		QuickUseHandler.use_item(item)
	_close_context_menu()

func _on_context_drop() -> void:
	if current_item_index >= current_items.size(): return
	var item = current_items[current_item_index]
	if item and item.can_drop:
		_pending_item = item
		_selected_qty = 1
		if quantity_selector:
			quantity_selector.visible = true
			_update_quantity_display()
			if qty_confirm: qty_confirm.grab_focus()
		else:
			QuickUseHandler.drop_item(item, 1)
	_close_context_menu()

func _on_context_discard() -> void:
	if current_item_index >= current_items.size(): return
	var item = current_items[current_item_index]
	if item and item.can_discard:
		_pending_item = item
		_selected_qty = 1
		if quantity_selector:
			quantity_selector.visible = true
			_update_quantity_display()
			if qty_confirm: qty_confirm.grab_focus()
		else:
			QuickUseHandler.discard_item(item, 1)
	_close_context_menu()

# Refresh logic
func _on_category_pressed(idx: int) -> void:
	_switch_category(idx)

func _switch_category(new_index: int) -> void:
	current_category_index = wrapi(new_index, 0, category_buttons.size())
	current_item_index = 0
	_refresh_current_category()

func _refresh_current_category() -> void:
	for i in category_buttons.size():
		if category_buttons[i]:
			category_buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == current_category_index else Color(0.65, 0.65, 0.65)
	
	for child in item_grid.get_children():
		child.queue_free()
	
	var category_name = category_buttons[current_category_index].name.replace("Tab", "")
	current_items = PlayerInventory.inventory.get(category_name, [])
	
	if current_items.is_empty():
		var lbl = Label.new()
		lbl.text = "No items in " + category_name
		item_grid.add_child(lbl)
		clear_details()
		return
	
	for i in current_items.size():
		var item = current_items[i]
		var btn = Button.new()
		var qty = item.quantity if item and "quantity" in item else 1
		var name_str = item.display_name if item and "display_name" in item else "Unknown"
		btn.text = name_str + " x" + str(qty)
		btn.custom_minimum_size = Vector2(220, 64)
		btn.add_theme_font_size_override("font_size", 22)
		item_grid.add_child(btn)
		
		if i == current_item_index:
			btn.modulate = Color(1.0, 0.9, 0.4)
			btn.grab_focus()
	
	_update_details(current_items[current_item_index] if current_item_index < current_items.size() else null)

func _update_details(item: GameItem) -> void:
	if not item:
		clear_details()
		return
	if details_icon: details_icon.texture = item.icon
	if details_name: details_name.text = item.display_name
	if details_description:
		details_description.text = item.description if item.description else "No description available."

func clear_details() -> void:
	if details_icon: details_icon.texture = null
	if details_name: details_name.text = ""
	if details_description: details_description.text = ""
