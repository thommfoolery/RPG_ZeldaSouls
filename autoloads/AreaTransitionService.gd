# autoload/AreaTransitionService.gd
extends Node

func warp_to_bonfire(bonfire_id: String) -> void:
	var entry = BonfireManager.get_entry(bonfire_id)
	if not entry:
		push_error("[AreaTransitionService] warp_to_bonfire(): Unknown bonfire_id: " + bonfire_id)
		return
	
	print("[AreaTransitionService] Warping to bonfire: ", bonfire_id, " | scene: ", entry.scene_path, " | spawn: ", entry.spawn_position)
	
	# Tell the orchestrator this is a bonfire warp (highest priority)
	SceneEntryOrchestrator.pending_bonfire_warp = {
		"bonfire_id": bonfire_id,
		"spawn_position": entry.spawn_position
	}
	
	# Set normal checkpoint as backup
	CheckpointManager.set_checkpoint(bonfire_id, entry.scene_path, entry.spawn_position)
	
	# Fade to black
	TransitionManager.fade_to_black(0.8)
	await get_tree().create_timer(0.85).timeout
	
	# Safe scene change
	var scene_path = entry.scene_path
	if scene_path is String and not scene_path.is_empty():
		if scene_path.begins_with("uid://"):
			var packed = load(scene_path) as PackedScene
			if packed:
				get_tree().change_scene_to_packed(packed)
			else:
				push_error("[AreaTransitionService] Failed to load UID scene: " + scene_path)
		else:
			get_tree().change_scene_to_file(scene_path)
	else:
		push_error("[AreaTransitionService] Invalid scene_path for bonfire: " + bonfire_id)
	
	# Reset pending spawn marker (we use pending_bonfire_warp instead)
	SceneEntryOrchestrator.pending_spawn_marker = ""
	
	# Fade back in after scene loads
	await get_tree().process_frame
	await get_tree().process_frame
	TransitionManager.fade_from_black(0.6)
	
	print("[AreaTransitionService] Warp completed - faded in")

# Existing function - kept for compatibility
func change_to_area(area_id: String, spawn_marker_name: String = "PlayerEntranceMarker") -> void:
	var entry = AreaReg.registry.get_area(area_id) if AreaReg and AreaReg.registry else null
	if not entry:
		push_error("Unknown area: " + area_id)
		return
	
	SceneEntryOrchestrator.pending_spawn_marker = spawn_marker_name
	
	TransitionManager.blackout_then(func():
		var path = entry.scene_path
		if path.begins_with("uid://"):
			get_tree().change_scene_to_packed(load(path))
		else:
			get_tree().change_scene_to_file(path)
	, 0.3, 0.5)
