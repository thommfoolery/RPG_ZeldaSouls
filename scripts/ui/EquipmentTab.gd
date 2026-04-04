# scripts/ui/tabs/EquipmentTab.gd
extends Control

signal item_selected(slot_index: int, item: GameItem)

# ─── Sort System ─────────────────────────────────────────────────────
enum SortMode { DEFAULT, LAST_ADDED, ALPHABETICAL }
var current_sort_mode: SortMode = SortMode.DEFAULT

# ─── Node references ────────────────────────────────────────────────
@onready var main_grid: GridContainer = $MainContainer/GridContainer
@onready var category_label: Label = $BottomDescription/CategoryLabel
@onready var item_name_label: Label = $BottomDescription/ItemNameLabel

# ─── Assign Menu ────────────────────────────────────────────────────
@onready var assign_menu: Control = $AssignMenu
@onready var title_label: Label = $AssignMenu/Panel/TitleLabel
@onready var item_list: ItemList = $AssignMenu/Panel/ItemList
@onready var sort_label: Label = $AssignMenu/%SortLabel   # ← NEW

# All interactive slots (golden order)
@onready var slots: Array[TextureRect] = [
	$MainContainer/GridContainer/RightHand1, $MainContainer/GridContainer/RightHand2,
	$MainContainer/GridContainer/Quick1, $MainContainer/GridContainer/Quick2,
	$MainContainer/GridContainer/Quick3, $MainContainer/GridContainer/Quick4,
	$MainContainer/GridContainer/Quick5,
	$MainContainer/GridContainer/LeftHand1, $MainContainer/GridContainer/LeftHand2,
	$MainContainer/GridContainer/Ammo1, $MainContainer/GridContainer/Ammo2,
	$MainContainer/GridContainer/Head, $MainContainer/GridContainer/Body,
	$MainContainer/GridContainer/Arms, $MainContainer/GridContainer/Legs,
	$MainContainer/GridContainer/Ring1, $MainContainer/GridContainer/Ring2,
	$MainContainer/GridContainer/Ring3,
]

# ─── UNIQUE QTY LABELS ───
@onready var qty_labels: Array[Label] = [
	null, null,
	$MainContainer/GridContainer/Quick1/Quick1Qty,
	$MainContainer/GridContainer/Quick2/Quick2Qty,
	$MainContainer/GridContainer/Quick3/Quick3Qty,
	$MainContainer/GridContainer/Quick4/Quick4Qty,
	$MainContainer/GridContainer/Quick5/Quick5Qty,
	null, null,
	$MainContainer/GridContainer/Ammo1/Ammo1Qty,
	$MainContainer/GridContainer/Ammo2/Ammo2Qty,
	null, null, null, null,
	null, null, null
]

# YOUR EXACT GOLDEN NEIGHBOR MAP
const NEIGHBORS = {
	0: {"left": 17, "right": 1, "up": 11, "down": 7},
	1: {"left": 0, "right": 2, "up": 12, "down": 8},
	2: {"left": 1, "right": 3, "up": -1, "down": 9},
	3: {"left": 2, "right": 4, "up": -1, "down": 10},
	4: {"left": 3, "right": 5, "up": 15, "down": 10},
	5: {"left": 4, "right": 6, "up": 16, "down": 16},
	6: {"left": 5, "right": 7, "up": 17, "down": 17},
	7: {"left": 6, "right": 8, "up": 0, "down": 11},
	8: {"left": 7, "right": 9, "up": 1, "down": 12},
	9: {"left": 8, "right": 10, "up": 2, "down": 14},
	10: {"left": 9, "right": 11, "up": 3, "down": 15},
	11: {"left": 10, "right": 12, "up": 7, "down": 0},
	12: {"left": 11, "right": 13, "up": 8, "down": 1},
	13: {"left": 12, "right": 14, "up": 9, "down": 1},
	14: {"left": 13, "right": 15, "up": 9, "down": 2},
	15: {"left": 14, "right": 16, "up": 10, "down": 4},
	16: {"left": 15, "right": 17, "up": 5, "down": 5},
	17: {"left": 16, "right": 0, "up": 6, "down": 6},
}

var current_index: int = 0
var is_assign_menu_open: bool = false

func _ready() -> void:
	print("[EQUIP-TAB] Golden navigation + Assign Menu + X Unequip + QTY labels + Sorting")
	EquipmentManager.equipped_changed.connect(_on_equipped_changed)
	_update_all_slots()
	_update_description()
	_highlight_current_slot()

	if item_list:
		item_list.item_selected.connect(_on_item_list_selected)
		item_list.item_activated.connect(_on_item_list_activated)
		print("[EQUIP-TAB] ItemList signals connected")

func _input(event: InputEvent) -> void:
	if not visible or Global.is_in_menu == false:
		return

	# ─── ASSIGN MENU OPEN ───
	if is_assign_menu_open:
		# Y button = cycle sort
		if event.is_action_pressed("two_hand_toggle"):
			current_sort_mode = (current_sort_mode + 1) % 3
			_refresh_assign_menu()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("cycle_item_up"):
			if item_list.item_count == 0: 
				get_viewport().set_input_as_handled()
				return
			var idx = item_list.get_selected_items()[0] if item_list.get_selected_items().size() > 0 else 0
			idx = (idx - 1 + item_list.item_count) % item_list.item_count
			item_list.select(idx)
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("cycle_item_down"):
			if item_list.item_count == 0: 
				get_viewport().set_input_as_handled()
				return
			var idx = item_list.get_selected_items()[0] if item_list.get_selected_items().size() > 0 else 0
			idx = (idx + 1) % item_list.item_count
			item_list.select(idx)
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("ui_cancel"):
			_close_assign_menu()
			get_viewport().set_input_as_handled()
			return

		return

	# ─── NORMAL GOLDEN NAVIGATION ───
	var dir = ""
	if event.is_action_pressed("cycle_right_hand"): dir = "right"
	elif event.is_action_pressed("cycle_left_hand"): dir = "left"
	elif event.is_action_pressed("cycle_item_down"): dir = "down"
	elif event.is_action_pressed("cycle_item_up"): dir = "up"

	if dir != "" and NEIGHBORS.has(current_index):
		var target = NEIGHBORS[current_index][dir]
		if target != -1 and target < slots.size():
			current_index = target
			get_viewport().set_input_as_handled()
			_highlight_current_slot()
			_update_description()
			return

	# A = open assign menu
	if event.is_action_pressed("ui_accept"):
		_open_assign_menu()
		get_viewport().set_input_as_handled()
		return

	# X = unequip
	if event.is_action_pressed("equipment_unequip"):
		_unequip_current_slot()
		get_viewport().set_input_as_handled()

# ─── NEW: Refresh assign menu with current sort ─────────────────────
func _refresh_assign_menu() -> void:
	if not assign_menu.visible: return
	_open_assign_menu()  # rebuilds the list with new sort

# ─── The rest of your functions (only minimal changes) ───────────────
func _open_assign_menu() -> void:
	var display_name = _get_category_name(current_index)
	var category = _get_category_for_slot(current_index)

	if category == "Armor":
		var armor_type = _get_armor_type_for_slot(current_index)
		if armor_type != "":
			display_name = "Armor - " + armor_type

	is_assign_menu_open = true
	assign_menu.visible = true

	if title_label:
		title_label.text = "Assign to " + display_name

	# Update sort prompt
	if sort_label:
		match current_sort_mode:
			SortMode.DEFAULT:      sort_label.text = "Y: Sort (Default)"
			SortMode.LAST_ADDED:   sort_label.text = "Y: Sort (Last Added)"
			SortMode.ALPHABETICAL: sort_label.text = "Y: Sort (Alphabetical)"

	item_list.clear()
	var available = _get_sorted_items(category)   # ← now uses sorted version

	for item in available:
		var text = item.display_name
		if item.quantity > 1:
			text += " x" + str(item.quantity)
		item_list.add_item(text, item.icon)

	if item_list.item_count > 0:
		item_list.select(0)
		item_list.call_deferred("grab_focus")

func _get_sorted_items(category: String) -> Array[GameItem]:
	var items = _get_available_items_for_category(category)
	
	match current_sort_mode:
		SortMode.DEFAULT:
			return items
		SortMode.LAST_ADDED:
			var reversed = items.duplicate()
			reversed.reverse()
			return reversed
		SortMode.ALPHABETICAL:
			var sorted = items.duplicate()
			sorted.sort_custom(func(a, b): return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
			return sorted
	
	return items

# ─── Rest of your original code (unchanged) ─────────────────────────
func _close_assign_menu() -> void:
	print("[EQUIP-TAB] [MENU-DEBUG] Closing assign menu")
	is_assign_menu_open = false
	assign_menu.visible = false
	_highlight_current_slot()

func _on_item_list_selected(index: int) -> void:
	print("[EQUIP-TAB] [MENU-DEBUG] ItemList highlighted index ", index)

func _on_item_list_activated(index: int) -> void:
	print("[EQUIP-TAB] [MENU-DEBUG] A activated on list item ", index)
	var category = _get_category_for_slot(current_index)
	var available = _get_sorted_items(category)
	if index < available.size():
		var chosen = available[index]
		if equip_item(current_index, chosen):
			print("[EQUIP-TAB] Equipped ", chosen.display_name, " to slot ", current_index)
		else:
			print("[EQUIP-TAB] Equip blocked")
	_close_assign_menu()

func _unequip_current_slot() -> void:
	var success = EquipmentManager.unequip_slot(current_index)
	if success:
		print("[EQUIP-TAB] Unequipped slot ", current_index)
		_update_all_slots()
		_update_description()
	else:
		print("[EQUIP-TAB] Nothing to unequip in slot ", current_index)

# ── Helpers (unchanged) ─────────────────────────────────────────────────────────
func _get_category_for_slot(slot_idx: int) -> String:
	if slot_idx <= 1: return "Weapons"
	if slot_idx <= 6: return "Consumables"
	if slot_idx <= 8: return "Weapons"
	if slot_idx <= 10: return "Ammo"
	if slot_idx <= 14: return "Armor"
	return "Rings"

func _get_armor_type_for_slot(slot_idx: int) -> String:
	match slot_idx:
		11: return "Head"
		12: return "Body"
		13: return "Arms"
		14: return "Legs"
		_: return ""

func _get_available_items_for_category(category: String) -> Array[GameItem]:
	var filtered: Array[GameItem] = []
	for cat in PlayerInventory.inventory:
		if cat.to_lower() == category.to_lower():
			for item in PlayerInventory.inventory[cat]:
				if category == "Armor":
					var required_type = _get_armor_type_for_slot(current_index)
					if item.armor_slot == required_type:
						filtered.append(item)
				else:
					filtered.append(item)
	return filtered

func _update_all_slots() -> void:
	for i in slots.size():
		var slot = slots[i]
		if not slot: continue
		var item = EquipmentManager.get_equipped_item(i)
		slot.texture = item.icon if item else preload("res://art/objects/items/item_ui/EmptySlot.png")

		var qty_label = qty_labels[i]
		if qty_label:
			if item and (item.category in ["Consumables", "Ammo"]) and item.quantity > 1:
				qty_label.text = "x" + str(item.quantity)
				qty_label.visible = true
			else:
				qty_label.visible = false

func _highlight_current_slot() -> void:
	for i in slots.size():
		if slots[i]:
			slots[i].modulate = Color(1.4, 1.4, 0.719, 0.839) if i == current_index else Color.WHITE

func _update_description() -> void:
	var item = EquipmentManager.get_equipped_item(current_index)
	category_label.text = _get_category_name(current_index)
	item_name_label.text = item.display_name if item else "Empty"

func _get_category_name(index: int) -> String:
	if index <= 1: return "Right Hand"
	if index <= 6: return "Quick Use"
	if index <= 8: return "Left Hand"
	if index <= 10: return "Ammo"
	if index <= 14: return "Armor"
	return "Rings"

func _on_equipped_changed(slot_index: int, _new_item: GameItem) -> void:
	_update_all_slots()
	_update_description()

func equip_item(slot_index: int, new_item: GameItem) -> bool:
	if not new_item: return false

	if new_item.category == "Armor" and new_item.armor_slot != "":
		var required = _get_armor_type_for_slot(slot_index)
		if required != "" and new_item.armor_slot != required:
			print("[EQUIP-TAB] Armor slot mismatch - ", new_item.display_name, " belongs in ", new_item.armor_slot)
			return false

	for i in EquipmentManager.SLOT_COUNT:
		if i != slot_index and EquipmentManager.get_equipped_item(i) and \
		   EquipmentManager.get_equipped_item(i).id == new_item.id:
			print("[EQUIP-TAB] Moving item from old slot ", i, " to new slot ", slot_index)
			EquipmentManager.unequip_slot(i)

	return EquipmentManager.equip_to_slot(slot_index, new_item)
