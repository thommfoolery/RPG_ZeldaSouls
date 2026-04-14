# autoload/EquipmentManager.gd
# ─── FUTURE-PROOF EQUIPMENT SYSTEM ───
extends Node
signal equipped_changed(slot_index: int, new_item: GameItem)
const SLOT_COUNT = 18
var equipped: Array[GameItem] = []
var _is_loading_save: bool = false

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
	if _is_loading_save:
		return false
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
	if _is_loading_save:
		return
	print("[EquipmentManager] reapply_dynamic_components() called after scene load/warp")
	for i in SLOT_COUNT:
		var item = equipped[i]
		if item and _is_lamp_item(item):
			_instantiate_lamp_component(i, item)
			break
	refresh_buff_hud()

# ─── NEW: Re-apply ALL permanent buffs after player is ready ───
func reapply_all_buffs() -> void:
	if _is_loading_save:
		return
	print("[EquipmentManager] Re-applying all permanent buffs after player ready")
	for i in SLOT_COUNT:
		var item = equipped[i]
		if item and not item.permanent_modifiers.is_empty():
			_handle_item_buff(item, true)
	refresh_buff_hud()

# ─── GENERAL EQUIPMENT BUFF SYSTEM ───
func get_all_buff_icons() -> void:
	# This is just to trigger BuffHUD rebuild if needed
	pass # BuffHUD already listens to equipped_changed

func _handle_item_buff(item: GameItem, equipped: bool) -> void:
	if not item or item.permanent_modifiers.is_empty():
		return
	
	for modifier in item.permanent_modifiers:
		if equipped:
			StatCalculator.add_modifier(modifier)
		else:
			StatCalculator.remove_modifier(modifier)

# ─── LAMP HELPERS (simple & reliable) ─────────────────────────────
func _is_lamp_item(item: GameItem) -> bool:
	if not item: return false
	return item.id.begins_with("lamp_") or \
		   item.display_name.to_lower().contains("lantern") or \
		   item.display_name.to_lower().contains("lamp")

func _instantiate_lamp_component(slot_index: int, item: GameItem) -> void:
	var player = PlayerManager.current_player
	if not player: return
	_remove_lamp_component() # safety
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
	if not new_player:
		return
	print("[EquipmentManager] New player detected → scheduling buff re-apply")
	call_deferred("_reapply_all_buffs_deferred")

# ─── SAVE / LOAD ────────────────────────────────────────────────────
func to_save_dict() -> Array:
	var save_array = []
	for item in equipped:
		if item and item is GameItem:
			save_array.append({"id": item.id, "quantity": item.quantity})
		else:
			save_array.append(null)
	return save_array
	# refresh_buff_hud() was incorrectly here - removed it

func from_save_dict(data: Array) -> void:
	_is_loading_save = true
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
	
	# Re-apply lamp(s) — this must happen before final stat refresh
	for i in SLOT_COUNT:
		if equipped[i] and _is_lamp_item(equipped[i]):
			_instantiate_lamp_component(i, equipped[i])
			break  # only one lamp
	
	# IMPORTANT: Do NOT apply buffs or refresh stats here.
	# Let the Orchestrator do one clean final refresh after the player is fully ready.
	# We only mark that loading is done.
	_is_loading_save = false
	
	# Trigger a deferred full re-apply + refresh from the orchestrator side instead
	call_deferred("_reapply_all_buffs_deferred")

func _save_equipped() -> void:
	# SaveManager will call to_save_dict() when needed
	pass

# ─── PUBLIC: Force BuffHUD refresh after scene load or save ───
func refresh_buff_hud() -> void:
	equipped_changed.emit(-1, null) # dummy emit to trigger rebuild safely

func _reapply_all_buffs_deferred() -> void:
	if _is_loading_save:
		return
	
	print("[EquipmentManager] _reapply_all_buffs_deferred() — re-applying all permanent buffs after player is fully ready")
	
	# Disable refreshes while we rebuild the modifier list to prevent partial resets
	StatCalculator.set_refresh_enabled(false)
	
	StatCalculator.clear_all_modifiers()
	
	var applied_count := 0
	for i in SLOT_COUNT:
		var item = equipped[i]
		if item and not item.permanent_modifiers.is_empty():
			for mod in item.permanent_modifiers:
				StatCalculator.add_modifier(mod)
				applied_count += 1
	
	print("[EquipmentManager] Re-applied ", applied_count, " modifiers from equipped items")
	
	# Re-enable and do the single final refresh
	StatCalculator.set_refresh_enabled(true)
	
	refresh_buff_hud()
	
