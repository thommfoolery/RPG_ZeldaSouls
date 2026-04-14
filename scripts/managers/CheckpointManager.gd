# autoload/CheckpointManager.gd
extends Node

var current_bonfire_id: String = ""
var current_scene_path: String = ""
var current_spawn_position: Vector2 = Vector2.ZERO

# ─── INITIAL CHECKPOINT (for fresh game / first death before any bonfire) ───
var initial_spawn_scene: String = ""
var initial_spawn_position: Vector2 = Vector2.ZERO

const FALLBACK_SCENE = "res://scenes/_testroom.tscn"
const FALLBACK_POS = Vector2(180, 67)


func set_checkpoint(bonfire_id: String, scene_path: String, spawn_pos: Vector2) -> void:
	current_bonfire_id = bonfire_id
	current_scene_path = scene_path
	current_spawn_position = spawn_pos
	print("[Checkpoint] Saved → bonfire: ", bonfire_id, " | scene: ", scene_path.get_file(), " | pos: ", spawn_pos)


# NEW: Called once at game start to establish a safe first-death fallback
func set_initial_checkpoint(scene_path: String, spawn_pos: Vector2) -> void:
	initial_spawn_scene = scene_path
	initial_spawn_position = spawn_pos
	current_bonfire_id = "initial_start"
	current_scene_path = scene_path
	current_spawn_position = spawn_pos
	print("[CheckpointManager] Initial checkpoint set at ", scene_path.get_file(), " pos ", spawn_pos.round())


func has_valid_checkpoint() -> bool:
	# Consider initial checkpoint valid if no bonfire has been used yet
	return not current_scene_path.is_empty() and ResourceLoader.exists(current_scene_path) \
		or not initial_spawn_scene.is_empty()


func respawn() -> void:
	print("[CheckpointManager] === RESPAWN START ===")
	print("  └─ target scene: ", current_scene_path.get_file() if current_scene_path else "[none]")
	print("  └─ current_spawn_position: ", current_spawn_position)
	print("  └─ is_death_respawn BEFORE: ", Global.is_death_respawn)

	var target_scene = current_scene_path
	var target_pos = current_spawn_position

	# Initial fallback if never rested at a real bonfire
	if target_scene.is_empty() and not initial_spawn_scene.is_empty():
		target_scene = initial_spawn_scene
		target_pos = initial_spawn_position
		print("[CheckpointManager] Using INITIAL checkpoint fallback (first death)")

	Global.is_death_respawn = true

	await TransitionManager.blackout_then(func():
		var current_scene_node = get_tree().current_scene
		var current_path = current_scene_node.scene_file_path if current_scene_node else ""

		if current_path != target_scene and not target_scene.is_empty():
			print("[CheckpointManager] DIFFERENT SCENE - forcing change to ", target_scene.get_file())
			# ── NEW: Set pending so Orchestrator resolver will use the exact bonfire pos ──
			SceneEntryOrchestrator.pending_death_respawn = {"target_pos": target_pos}
			get_tree().change_scene_to_file(target_scene)
			await get_tree().create_timer(0.5).timeout
			print("[CheckpointManager] Scene change completed — Orchestrator will use pending_death_respawn")
		else:
			# SAME SCENE — keep our existing force (already working)
			print("[CheckpointManager] SAME SCENE - no change needed, forcing reposition")
			await get_tree().process_frame
			await get_tree().process_frame
			print("[CheckpointManager] Forcing resolver after respawn (same-scene only)")
			var final_pos = PlayerPositionResolver.resolve_spawn_position()
			var player = PlayerManager.current_player
			if player and is_instance_valid(player):
				player.global_position = final_pos
				print("[CheckpointManager] FORCED player position to: ", final_pos.round())

		# We no longer clear the flag here — Orchestrator now owns clearing for both paths
		, 0.25, 0.4)

	print("[CheckpointManager] === RESPAWN FINISHED ===")
	


func _after_scene_change() -> void:
	await get_tree().create_timer(0.35).timeout
	_teleport_after_respawn()


func _teleport_after_respawn() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = PlayerManager.current_player
	if not player or not is_instance_valid(player):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.global_position = current_spawn_position
		print("[Checkpoint] Player teleported to bonfire spawn: ", current_spawn_position)
		
		if Global.is_death_respawn:
			PlayerStats.souls_carried = 0
			PlayerStats.souls_changed.emit(0)
			print("[CheckpointManager] FORCED souls_carried = 0 after death respawn")
		
		print("[CheckpointManager-DEBUG] Direct spawn call triggered after respawn")
		if BloodstainManager:
			BloodstainManager.spawn_if_pending()
		else:
			print("[CheckpointManager] BloodstainManager missing!")
	else:
		print("[Checkpoint] ERROR: No valid player found for teleport")

func has_real_bonfire() -> bool:
	return not current_bonfire_id.is_empty() and current_bonfire_id != "initial_start"
