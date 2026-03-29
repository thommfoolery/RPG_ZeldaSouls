# autoload/SaveManager.gd
extends Node
const SAVE_PATH = "user://souls_like_save.dat"

func _ready() -> void:
	print("[SaveManager] Ready — position + checkpoint + bloodstain persistence v1.7+ (scene path added)")
	if EventBus:
		EventBus.bloodstain_collected.connect(_on_bloodstain_collected)
		print("[SaveManager] Subscribed to EventBus.bloodstain_collected")
	load_game()

func save_game() -> void:
	var player = PlayerManager.current_player if PlayerManager else null
	var current_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	
	# ─── Update per-scene saved position before saving ───
	Global.saved_positions_per_scene[current_scene_path] = player.global_position if player else Vector2.ZERO

	var save_data := {
		"current_scene_path": current_scene_path,
		"version": 1.9,
		"player_stats": PlayerStats.to_save_dict() if PlayerStats else {},
		"discovered_bonfires": PlayerStats.discovered_bonfires if PlayerStats else {},
		"last_checkpoint": {
			"bonfire_id": CheckpointManager.current_bonfire_id if CheckpointManager else "",
			"scene_path": CheckpointManager.current_scene_path if CheckpointManager else "",
			"spawn_pos_x": CheckpointManager.current_spawn_position.x if CheckpointManager else 0.0,
			"spawn_pos_y": CheckpointManager.current_spawn_position.y if CheckpointManager else 0.0
		},
		"inventory": PlayerInventory.to_save_dict() if PlayerInventory else {},
		"equipped_items": EquipmentManager.to_save_dict() if EquipmentManager else [],   # ← New proper call
		"last_saved_scene": current_scene_path,
		"saved_positions_per_scene": Global.saved_positions_per_scene,
		"world_state": WorldStateManager.world_state if WorldStateManager else {},
		"has_pending_bloodstain": Global.has_pending_bloodstain,
		"dropped_souls": Global.dropped_souls,
		"last_death_pos_x": Global.last_death_pos.x,
		"last_death_pos_y": Global.last_death_pos.y,
		"last_death_scene": Global.last_death_scene,
		"locked_death_pos_x": Global.locked_death_pos.x,
		"locked_death_pos_y": Global.locked_death_pos.y,
		"is_death_respawn": Global.is_death_respawn,
		"death_timestamp": Global.death_timestamp if Global.death_timestamp > 0 else 0,
		"death_scene_path": Global.death_scene_path,
		"death_locked_pos_x": Global.death_locked_pos.x,
		"death_locked_pos_y": Global.death_locked_pos.y,
		"current_health": Global.current_health,
		"current_stamina": Global.current_stamina,
		"current_estus": PlayerStats.current_estus if PlayerStats else 3,
		"world_time": Global.world_time if Global else 0.0
	}

	Global.last_saved_scene_path = current_scene_path
	print("!!! SAVE_GAME CALLED !!!")
	if player and is_instance_valid(player):
		print(" └─ Player global_position at save time: ", player.global_position.round())
		print(" └─ Saving per-scene pos for ", current_scene_path.get_file(), ": ", Global.saved_positions_per_scene[current_scene_path].round())
	else:
		print(" └─ WARNING: No valid player at save time → saving (0,0)")
	print(" └─ Current scene: ", current_scene_path.get_file() if current_scene_path else "[none]")

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print("[SaveManager] SAVED → scene: ", current_scene_path.get_file() if current_scene_path else "[none]",
			  " | health: ", Global.current_health, " | stamina: ", Global.current_stamina,
			  " | estus: ", save_data.get("current_estus", 3),
			  " | death_respawn: ", Global.is_death_respawn)
	else:
		push_error("[SaveManager] Failed to write save file!")

func request_save() -> void:
	var hud_node = get_tree().get_first_node_in_group("hud")
	if hud_node and hud_node.has_method("show_saving_icon"):
		hud_node.show_saving_icon()
	print("[SaveManager] request_save() called — saving now")
	save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No save file — fresh start")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = file.get_var()
	file.close()

	print("!!! LOAD_GAME CALLED !!!")
	print(" └─ Loaded scene path: ", data.get("last_saved_scene", "[none]").get_file() if data.has("last_saved_scene") else "[none]")

	# World state
	if WorldStateManager and data.has("world_state"):
		WorldStateManager.world_state = data.world_state.duplicate(true)
		print("[SaveManager] Loaded world_state with ", WorldStateManager.world_state.size(), " scenes")

	# Inventory
	if PlayerInventory and data.has("inventory"):
		PlayerInventory.from_save_dict(data.inventory)

	# NEW: Equipment
	if EquipmentManager and data.has("equipped_items"):
		EquipmentManager.from_save_dict(data.equipped_items)
		print("[SaveManager] Loaded equipped items from save")

	if PlayerStats:
		PlayerStats.from_save_dict(data.get("player_stats", {}))
		PlayerStats.discovered_bonfires = data.get("discovered_bonfires", {})

	if CheckpointManager and data.has("last_checkpoint"):
		var cp = data.last_checkpoint
		CheckpointManager.set_checkpoint(
			cp.bonfire_id,
			cp.scene_path,
			Vector2(cp.spawn_pos_x, cp.spawn_pos_y)
		)
		print("[SaveManager] Restored last checkpoint: ", cp.bonfire_id if cp.bonfire_id else "[none]")

	# Death / bloodstain state
	Global.has_pending_bloodstain = data.get("has_pending_bloodstain", false)
	Global.dropped_souls = data.get("dropped_souls", 0)
	Global.last_death_pos = Vector2(data.get("last_death_pos_x", 0.0), data.get("last_death_pos_y", 0.0))
	Global.last_death_scene = data.get("last_death_scene", "")
	Global.locked_death_pos = Vector2(data.get("locked_death_pos_x", 0.0), data.get("locked_death_pos_y", 0.0))
	Global.is_death_respawn = data.get("is_death_respawn", false)
	Global.death_timestamp = data.get("death_timestamp", 0)
	Global.saved_positions_per_scene = data.get("saved_positions_per_scene", {})
	Global.death_scene_path = data.get("death_scene_path", "")
	Global.death_locked_pos = Vector2(
		data.get("death_locked_pos_x", 0.0),
		data.get("death_locked_pos_y", 0.0)
	)

	# Health, stamina, estus, world time
	if Global:
		Global.current_health = data.get("current_health", 101.0)
		Global.current_stamina = data.get("current_stamina", 100.0)
		Global.world_time = data.get("world_time", 0.0)
		print("[Feature-DEBUG] Loaded persisted health/stamina from save → health: ", Global.current_health, " | stamina: ", Global.current_stamina)

	if PlayerStats:
		PlayerStats.current_estus = data.get("current_estus", PlayerStats.max_estus)
		PlayerStats.estus_charges = PlayerStats.current_estus
		PlayerStats.estus_changed.emit(PlayerStats.current_estus)
		print("[Feature-DEBUG] Loaded persisted estus from save → current: ", PlayerStats.current_estus, " / max: ", PlayerStats.max_estus)

	Global.last_saved_scene_path = data.get("last_saved_scene", "")
	var loaded_scene_path = data.get("current_scene_path", "")
	if loaded_scene_path and ResourceLoader.exists(loaded_scene_path):
		print("[SaveManager] Loading saved scene: ", loaded_scene_path.get_file())
		get_tree().call_deferred("change_scene_to_file", loaded_scene_path)
	else:
		print("[SaveManager] No saved scene or invalid — falling back to _testroom")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/_testroom.tscn")

func _on_bloodstain_collected(souls: int) -> void:
	print("[SaveManager] bloodstain_collected received (souls: ", souls, ") — clearing pending + forcing save")
	Global.clear_pending_bloodstain()
	Global.is_death_respawn = false
	request_save()
