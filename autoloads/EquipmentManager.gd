# autoload/EquipmentManager.gd
# ─── FUTURE-PROOF EQUIPMENT SYSTEM ───
extends Node

signal equipped_changed(slot_index: int, new_item: GameItem)

const SLOT_COUNT = 18   # UPDATED - supports 3 rings (indices 0-17)
var equipped: Array[GameItem] = []

func _ready() -> void:
	equipped.resize(SLOT_COUNT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EquipmentManager] Ready — ", SLOT_COUNT, " slots | anti-dupe + signals active")

# ─── PUBLIC API ─────────────────────────────────────────────────────
func equip_to_slot(slot_index: int, item: GameItem) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or not item:
		push_error("[EquipmentManager] Invalid equip request - slot ", slot_index, " out of bounds")
		return false

	# Anti-dupe only for stackable categories (Ammo / Consumables)
	if item.category in ["Ammo", "Consumables"]:
		for i in SLOT_COUNT:
			if equipped[i] and equipped[i].id == item.id and i != slot_index:
				equipped[i] = null
				equipped_changed.emit(i, null)

	equipped[slot_index] = item.duplicate(true)
	equipped_changed.emit(slot_index, equipped[slot_index])
	_save_equipped()
	print("[EquipmentManager] Equipped ", item.display_name, " → slot ", slot_index)
	return true

# Returns bool for clean UI feedback
func unequip_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if equipped[slot_index] == null:
		return false

	print("[EquipmentManager] Unequipping slot ", slot_index, " (", equipped[slot_index].display_name, ")")
	equipped[slot_index] = null
	equipped_changed.emit(slot_index, null)
	_save_equipped()
	return true

func get_equipped_item(slot_index: int) -> GameItem:
	if slot_index < 0 or slot_index >= equipped.size():
		return null
	return equipped[slot_index]

# ─── SAVE / LOAD ────────────────────────────────────────────────────
func to_save_dict() -> Array:
	var save_array = []
	for item in equipped:
		if item and item is GameItem:
			save_array.append({
				"id": item.id,
				"quantity": item.quantity
			})
		else:
			save_array.append(null)
	return save_array

func from_save_dict(data: Array) -> void:
	equipped.clear()
	equipped.resize(SLOT_COUNT)
	var restored_count := 0
	for i in data.size():
		if i >= SLOT_COUNT:
			break
		if data[i] == null:
			equipped[i] = null
			continue
		var item_id = data[i].get("id", "")
		var qty = data[i].get("quantity", 1)
		if item_id.is_empty():
			continue
		var path = "res://resources/items/" + item_id + ".tres"
		var real_item = load(path) as GameItem
		if real_item:
			var copy = real_item.duplicate(true)
			copy.quantity = qty
			equipped[i] = copy
			restored_count += 1
		else:
			push_warning("[EquipmentManager] Could not load equipped item: " + item_id)
	print("[EquipmentManager] Restored ", restored_count, " equipped items")
	for i in SLOT_COUNT:
		equipped_changed.emit(i, equipped[i])

func _save_equipped() -> void:
	# SaveManager will pull via to_save_dict() when it saves
	pass
