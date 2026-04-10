# autoload/EquipmentManager.gd
# ─── FUTURE-PROOF EQUIPMENT SYSTEM ───
extends Node

signal equipped_changed(slot_index: int, new_item: GameItem)

const SLOT_COUNT = 18

var equipped: Array[GameItem] = []

func _ready() -> void:
	equipped.resize(SLOT_COUNT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EquipmentManager] Ready — ", SLOT_COUNT, " slots | anti-dupe + signals active")
	
	# Re-apply special items (like lamps) when a new player is created after scene change
	if PlayerManager:
		PlayerManager.player_changed.connect(_on_player_changed)


# ─── PUBLIC API ─────────────────────────────────────────────────────
func equip_to_slot(slot_index: int, item: GameItem) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or not item:
		push_error("[EquipmentManager] Invalid equip request - slot ", slot_index, " out of bounds")
		return false

	# Anti-dupe only for stackable categories
	if item.category in ["Ammo", "Consumables"]:
		for i in SLOT_COUNT:
			if equipped[i] and equipped[i].id == item.id and i != slot_index:
				equipped[i] = null
				equipped_changed.emit(i, null)

	# Actually equip
	equipped[slot_index] = item.duplicate(true)
	equipped_changed.emit(slot_index, equipped[slot_index])
	
	_handle_item_buff(item, true)

	# ─── SIMPLE LAMP SYSTEM ─────────────────────────────
	if _is_lamp_item(item):
		_instantiate_lamp_component(slot_index, item)

	_save_equipped()
	print("[EquipmentManager] Equipped ", item.display_name, " → slot ", slot_index)
	return true


func unequip_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if equipped[slot_index] == null:
		return false

	var item = equipped[slot_index]

	if item:
		_handle_item_buff(item, false)

	# Clean up lamp if this was one
	if _is_lamp_item(item):
		_remove_lamp_component()

	print("[EquipmentManager] Unequipping slot ", slot_index, " (", item.display_name, ")")
	equipped[slot_index] = null
	equipped_changed.emit(slot_index, null)
	_save_equipped()
	return true


func get_equipped_item(slot_index: int) -> GameItem:
	if slot_index < 0 or slot_index >= equipped.size():
		return null
	return equipped[slot_index]

# ─── PUBLIC: Re-apply dynamic components after scene change / warp ───
func reapply_dynamic_components() -> void:
	print("[EquipmentManager] reapply_dynamic_components() called after scene load/warp")
	
	for i in SLOT_COUNT:
		var item = equipped[i]
		if item and _is_lamp_item(item):
			print("[EquipmentManager] Re-instantiating lamp from slot ", i, " → ", item.display_name)
			_instantiate_lamp_component(i, item)
			return  # only one lamp at a time

# ─── GENERAL EQUIPMENT BUFF SYSTEM ───
func _handle_item_buff(item: GameItem, equipped: bool) -> void:
	if not item or item.buff_effect_id.is_empty():
		return
	
	var buff_effect = load("res://resources/statuseffect/" + item.buff_effect_id + ".tres") as StatusEffect
	if not buff_effect:
		push_warning("[EquipmentManager] Could not load buff effect: " + item.buff_effect_id)
		return
	
	if equipped:
		StatusEffectManager.apply_effect(buff_effect, null)  # null source = permanent equipment buff
		print("[EquipmentManager] Applied buff from item: ", item.display_name, " → ", buff_effect.display_name)
	else:
		# Remove the buff when unequipped
		for i in range(StatusEffectManager.active_effects.size() - 1, -1, -1):
			if StatusEffectManager.active_effects[i].effect.id == buff_effect.id:
				StatusEffectManager.active_effects.remove_at(i)
				StatusEffectManager.effect_removed.emit(buff_effect.id)
				print("[EquipmentManager] Removed buff from item: ", item.display_name)
				break

# ─── LAMP HELPERS (simple & reliable) ─────────────────────────────
func _is_lamp_item(item: GameItem) -> bool:
	if not item: return false
	return item.id.begins_with("lamp_") or \
		   item.display_name.to_lower().contains("lantern") or \
		   item.display_name.to_lower().contains("lamp")


func _instantiate_lamp_component(slot_index: int, item: GameItem) -> void:
	var player = PlayerManager.current_player
	if not player: return

	_remove_lamp_component()  # safety

	var lamp_comp = load("res://scripts/components/LampComponent.gd").new()
	lamp_comp.name = "LampComponent"
	player.add_child(lamp_comp)
	lamp_comp._on_equipped()

	print("[EquipmentManager] Lamp equipped in slot ", slot_index, " → light ON")


func _remove_lamp_component() -> void:
	var player = PlayerManager.current_player
	if not player: return

	var old = player.get_node_or_null("LampComponent")
	if old:
		old._on_unequipped()
		old.queue_free()
		print("[EquipmentManager] Old LampComponent removed")


# ─── NEW: Re-apply lamp after scene change / new player ─────────────────────
func _on_player_changed(new_player: Node) -> void:
	if not new_player: return
	print("[EquipmentManager] New player detected → checking for active lamp")
	
	for i in SLOT_COUNT:
		if equipped[i] and _is_lamp_item(equipped[i]):
			_instantiate_lamp_component(i, equipped[i])
			break  # only one lamp at a time


# ─── SAVE / LOAD ────────────────────────────────────────────────────
func to_save_dict() -> Array:
	var save_array = []
	for item in equipped:
		if item and item is GameItem:
			save_array.append({"id": item.id, "quantity": item.quantity})
		else:
			save_array.append(null)
	return save_array


func from_save_dict(data: Array) -> void:
	equipped.clear()
	equipped.resize(SLOT_COUNT)
	var restored_count := 0

	for i in data.size():
		if i >= SLOT_COUNT: break
		if data[i] == null:
			equipped[i] = null
			continue

		var item_id = data[i].get("id", "")
		var qty = data[i].get("quantity", 1)
		if item_id.is_empty(): continue

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

	# Re-apply lamp if one was equipped after load
	for i in SLOT_COUNT:
		if equipped[i] and _is_lamp_item(equipped[i]):
			_instantiate_lamp_component(i, equipped[i])
		equipped_changed.emit(i, equipped[i])


func _save_equipped() -> void:
	# SaveManager will call to_save_dict() when needed
	pass
