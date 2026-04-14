# autoload/PlayerPositionResolver.gd
extends Node

## Returns where the player should spawn when a new scene loads.
## Priority order (updated for bonfire warping):
## 1. Pending bonfire warp (highest - from WarpMenu)
## 2. Transition marker (normal area/door travel)
## 3. Death respawn / checkpoint
## 4. Saved position per scene
## 5. DefaultSpawn marker
## 6. (0,0) fallback

func resolve_spawn_position() -> Vector2:
	print("[POSITION-DEBUG] === RESOLVER START ===")
	print("  └─ is_death_respawn=", Global.is_death_respawn)
	print("  └─ pending_bonfire_warp=", not SceneEntryOrchestrator.pending_bonfire_warp.is_empty())
	print("  └─ pending_death_respawn=", not SceneEntryOrchestrator.pending_death_respawn.is_empty())
	print("  └─ scene=", get_tree().current_scene.scene_file_path.get_file() if get_tree().current_scene else "none")

	# 1. BONFIRE WARP (from warp menu) - highest priority
	if SceneEntryOrchestrator.pending_bonfire_warp and not SceneEntryOrchestrator.pending_bonfire_warp.is_empty():
		var data = SceneEntryOrchestrator.pending_bonfire_warp
		var pos = data.get("spawn_position", Vector2.ZERO)
		print("[PositionResolver] → BONFIRE WARP WINS at ", pos.round())
		SceneEntryOrchestrator.pending_bonfire_warp = {}
		return pos

	# 2. NORMAL TRANSITION MARKER (door / area travel) - must come BEFORE death pending
	if SceneEntryOrchestrator.pending_spawn_marker:
		var requested_id = SceneEntryOrchestrator.pending_spawn_marker
		var markers = get_tree().get_nodes_in_group("transition_markers")
		for marker in markers:
			if marker is TransitionMarker and marker.marker_id == requested_id:
				print("[PositionResolver] → TRANSITION MARKER WINS: ", requested_id, " at ", marker.global_position.round())
				SceneEntryOrchestrator.pending_spawn_marker = ""
				# Safety: clear any stale death pending so it never leaks
				SceneEntryOrchestrator.pending_death_respawn = {}
				return marker.global_position

	# 3. DEATH RESPAWN (pending dict from CheckpointManager) - now after normal travel
	if SceneEntryOrchestrator.pending_death_respawn and not SceneEntryOrchestrator.pending_death_respawn.is_empty():
		var pos = SceneEntryOrchestrator.pending_death_respawn.get("target_pos", Vector2.ZERO)
		print("[PositionResolver] → DEATH CHECKPOINT (pending) WINS at ", pos.round())
		SceneEntryOrchestrator.pending_death_respawn = {}
		return pos

	# 4. Death respawn via checkpoint (same-scene fallback)
	if Global.is_death_respawn and CheckpointManager and CheckpointManager.has_valid_checkpoint():
		var pos = CheckpointManager.current_spawn_position
		print("[PositionResolver] → DEATH CHECKPOINT WINS at ", pos.round())
		return pos

	# 5. Saved position (normal loads only)
	if not Global.is_death_respawn:
		var current_path = get_tree().current_scene.scene_file_path
		if Global.saved_positions_per_scene.has(current_path):
			var saved_pos = Global.saved_positions_per_scene[current_path]
			print("[PositionResolver] → Using saved position: ", saved_pos.round())
			return saved_pos

	# 6. DefaultSpawn fallback
	var default_marker = _find_node_recursive(get_tree().current_scene, "DefaultSpawn")
	if default_marker:
		print("[PositionResolver] → DefaultSpawn marker")
		return default_marker.global_position

	print("[PositionResolver] → Fallback (0,0)")
	return Vector2.ZERO


# ── Helper (unchanged) ──
func _find_node_recursive(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node_recursive(child, name)
		if found:
			return found
	return null
