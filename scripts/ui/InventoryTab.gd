# scripts/ui/InventoryTab.gd
extends Panel

@onready var category_buttons: Array[Button] = [
	$CategoryBar/ConsumablesTab, $CategoryBar/KeysTab, $CategoryBar/MaterialsTab,
	$CategoryBar/SpellsTab, $CategoryBar/WeaponsTab, $CategoryBar/AmmoTab,
	$CategoryBar/ArmorTab, $CategoryBar/RingsTab, $CategoryBar/QuestTab
]

@onready var item_grid: GridContainer = $MainContainer/ItemScroll/ItemGrid

# Details Panel
var details_icon: TextureRect
var details_name: Label
var details_description: Label

var current_category_index: int = 0
var current_item_index: int = 0

func _ready() -> void:
	for i in category_buttons.size():
		if category_buttons[i]:
			category_buttons[i].pressed.connect(_on_category_pressed.bind(i))
	
	var dp = get_node_or_null("MainContainer/DetailsPanel")
	if dp:
		details_icon = dp.get_node_or_null("Icon")
		details_name = dp.get_node_or_null("NameLabel")
		details_description = dp.get_node_or_null("DescriptionLabel")
	
	PlayerInventory.inventory_changed.connect(_refresh_current_category)
	
	print("[InventoryTab] Ready — Bigger buttons + D-pad navigation")
	_switch_category(current_category_index)


func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	
	# Left/Right = Category
	if event.is_action_pressed("cycle_left_hand") or event.is_action_pressed("ui_left"):
		_switch_category(current_category_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_right_hand") or event.is_action_pressed("ui_right"):
		_switch_category(current_category_index + 1)
		get_viewport().set_input_as_handled()
	
	# Up/Down = Item navigation
	var items = PlayerInventory.inventory.get(
		category_buttons[current_category_index].name.replace("Tab", ""), []
	)
	if items.is_empty(): return
	
	if event.is_action_pressed("cycle_item_up") or event.is_action_pressed("ui_up"):
		current_item_index = wrapi(current_item_index - 1, 0, items.size())
		_refresh_current_category()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down") or event.is_action_pressed("ui_down"):
		current_item_index = wrapi(current_item_index + 1, 0, items.size())
		_refresh_current_category()
		get_viewport().set_input_as_handled()


func _on_category_pressed(idx: int) -> void:
	_switch_category(idx)


func _switch_category(new_index: int) -> void:
	current_category_index = wrapi(new_index, 0, category_buttons.size())
	current_item_index = 0
	_refresh_current_category()


func _refresh_current_category() -> void:
	# Highlight category tabs
	for i in category_buttons.size():
		if category_buttons[i]:
			category_buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == current_category_index else Color(0.65, 0.65, 0.65)
	
	# Clear grid
	for child in item_grid.get_children():
		child.queue_free()
	
	var category_name = category_buttons[current_category_index].name.replace("Tab", "")
	var items = PlayerInventory.inventory.get(category_name, [])
	
	if items.is_empty():
		var lbl = Label.new()
		lbl.text = "No items in " + category_name
		item_grid.add_child(lbl)
		clear_details()
		return
	
	# Create bigger, nicer buttons
	for i in items.size():
		var item = items[i]
		var btn = Button.new()
		var qty = item.quantity if item and "quantity" in item else 1
		btn.text = (item.display_name if item and "display_name" in item else "Unknown") + "  x" + str(qty)
		btn.custom_minimum_size = Vector2(220, 64)   # Bigger buttons
		btn.add_theme_font_size_override("font_size", 22)
		item_grid.add_child(btn)
		
		if i == current_item_index:
			btn.modulate = Color(1.0, 0.9, 0.4)
			btn.grab_focus()
	
	_update_details(items[current_item_index] if current_item_index < items.size() else null)


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
