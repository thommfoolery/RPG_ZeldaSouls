# autoload/SceneEntryOrchestrator.gd
extends Node
signal area_changed(new_area_id: String)

@onready var area_reg_manager = get_node("/root/AreaReg")

var pending_spawn_marker: String = ""  # temporary until AreaTransitionService owns it
var _current_scene_path_on_load: String = ""
var pending_bonfire_warp: Dictionary = {}   # { "bonfire_id": String, "spawn_position": Vector2 }
var pending_death_respawn: Dictionary = {}  # { "target_pos": Vector2 } — survives scene change

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree():
		get_tree().scene_changed.connect(_on_scene_changed)
		call_deferred("_run_on_first_load")
		print("[Orchestrator] Ready — delegating to services (Godot 4.6 pattern)")

func _on_scene_changed(_old = null) -> void:
	call_deferred("_on_scene_loaded")

func _run_on_first_load() -> void:
	await get_tree().create_timer(0.4).timeout
	_on_scene_loaded()

func _on_scene_loaded() -> void:
	await get_tree().create_timer(0.35).timeout
	var current_scene := get_tree().current_scene
	if not current_scene:
		push_error("[Orchestrator] CRITICAL: No current_scene"); return
	
	print("[Orchestrator] === Scene Loaded: ", current_scene.scene_file_path.get_file())
	
	# STRICT ORDER
	PlayerInstantiationService.instantiate_or_reuse_player(current_scene)
	
	# ─── NEW: Wait one frame so player is fully in tree ────────────────────────
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = PlayerManager.current_player
	if player and player.has_method("_on_scene_loaded"):
		player._on_scene_loaded()
	
	if not player or not is_instance_valid(player):
		push_error("[Orchestrator] Player missing after instantiation!")
		return
	
	# ─── Resolve where we want to spawn ────────────────────────────────────────
	print("[Orchestrator] Before resolver — is_death_respawn=", Global.is_death_respawn,
		  " | pending_bonfire_warp=", not pending_bonfire_warp.is_empty())
	var target_pos: Vector2 = PlayerPositionResolver.resolve_spawn_position()
	
	if target_pos == Vector2.ZERO:
		print("[Orchestrator-WARNING] Spawn position is (0,0) — check markers!")
	
	# ─── ACTIVATE THE PLAYER ───────────────────────────────────────────────────
	print("[Orchestrator] Activating player at ", target_pos.round())
	PlayerActivationService.activate_and_position_player(target_pos)
	
	# ─── INITIAL CHECKPOINT (only if we have NEVER rested at a real bonfire) ───
	if CheckpointManager and CheckpointManager.initial_spawn_scene.is_empty():
		if not CheckpointManager.has_real_bonfire():
			CheckpointManager.set_initial_checkpoint(current_scene.scene_file_path, target_pos)
			print("[Orchestrator] Initial checkpoint automatically set for first-death fallback")
		else:
			print("[Orchestrator] Real bonfire already in use — skipping initial checkpoint")
	
	CameraManager.activate_player_camera()
	
	#Bring me the lamp
	await get_tree().process_frame
	EquipmentManager.reapply_dynamic_components()
	
		# ── Final clean stat refresh after player and all equipment are ready ──
	# ── Strict control of stat refreshes during player load ──
	StatCalculator.set_refresh_enabled(false)   # Disable all refreshes

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame   # Extra frame for safety
	await get_tree().process_frame   # extra safety frame

	# Now the player and all equipment should be fully ready
	StatCalculator.set_refresh_enabled(true)    # Re-enable
	StatCalculator.refresh_all_player_stats()   # One clean refresh
	print("[Orchestrator] Final stat refresh after full player + equipment load")
	
	# Side effects
	if BloodstainManager: BloodstainManager.spawn_if_pending()
	if WorldStateManager: WorldStateManager.apply_state_to_scene()
	_handle_area_discovery_and_title(current_scene.scene_file_path)
	
	# Update world lighting after scene loads
	if WorldTimeManager:
		WorldTimeManager._update_lighting()
		print("[Orchestrator] WorldTimeManager lighting updated for new scene")
	
	print("[Orchestrator] Entry sequence COMPLETE")
		# Final safety: clear death flag only after everything is settled
	if Global.is_death_respawn:
		print("[Orchestrator] Clearing death_respawn flag after full activation")
		Global.is_death_respawn = false
	
# ─── Area discovery + title (future: move to AreaDiscoveryService for DLC) ───
func _handle_area_discovery_and_title(scene_path: String) -> void:
	print("[Orchestrator-TITLE] === CHECK for ", scene_path.get_file())
	
	var area_id = area_reg_manager.get_area_id_for_scene(scene_path)
	if area_id.is_empty():
		print("[Orchestrator-TITLE] → No Area ID registered for this scene path — skipping title")
		return
	
	print("[Orchestrator-TITLE] Resolved area_id: ", area_id)
	
	if PlayerStats.discovered_areas.has(area_id):
		print("[Orchestrator-TITLE] → Already discovered — skip title")
		return
	
	PlayerStats.discovered_areas[area_id] = true
	print("[Orchestrator-TITLE] → NEW DISCOVERY! Marking ", area_id)
	
	var entry = area_reg_manager.get_entry(area_id)
	if not entry:
		print("[Orchestrator-TITLE] → No AreaEntry found for ", area_id)
		return
	
	print("[Orchestrator-TITLE] → SUCCESS: Found AreaEntry → queuing title '", entry.title, "'")
	var sub = entry.first_visit_subtitle if entry.first_visit_subtitle else entry.subtitle
	TitleCardManager.show_title(entry.title, sub, 4.5, true, true)

func _get_area_entry_for_scene(path: String) -> AreaEntry:
	if not AreaReg or not AreaReg.registry: return null
	for e in AreaReg.registry.entries:
		if e.scene_path == path: return e
	return null

# ─── FUTURE HOOKS (commented for 3–6 months from now) ───
# func _apply_ngplus_spawn_modifier(): pass
# func _handle_boss_arena_camera_lock(): pass
# func _trigger_elevator_mid_scene_reposition(): pass
