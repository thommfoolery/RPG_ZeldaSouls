# autoload/CheckpointManager.gd
extends Node

var current_bonfire_id: String = ""
var current_scene_path: String = ""
var current_spawn_position: Vector2 = Vector2.ZERO

const FALLBACK_SCENE = "res://scenes/cliff_side.tscn"
const FALLBACK_POS = Vector2(100, 200)

func set_checkpoint(bonfire_id: String, scene_path: String, spawn_pos: Vector2) -> void:
	current_bonfire_id = bonfire_id
	current_scene_path = scene_path
	current_spawn_position = spawn_pos
	print("[Checkpoint] Saved: ", bonfire_id, " in ", scene_path.get_file(), " pos: ", spawn_pos)

func has_valid_checkpoint() -> bool:
	return not current_scene_path.is_empty() and ResourceLoader.exists(current_scene_path)

func respawn() -> void:
	if not has_valid_checkpoint():
		print("[Checkpoint] No valid checkpoint → fallback spawn at ", FALLBACK_POS)
		get_tree().change_scene_to_file(FALLBACK_SCENE)
		return
	
	print("[Checkpoint] Respawning to: ", current_scene_path.get_file(), " at pos ", current_spawn_position)
	
	if current_scene_path != get_tree().current_scene.scene_file_path:
		print("[Checkpoint] Changing to different scene: ", current_scene_path)
		get_tree().change_scene_to_file(current_scene_path)
		call_deferred("_after_scene_change_restore_and_teleport")
	else:
		print("[Checkpoint] Same scene - deferring teleport + restore")
		call_deferred("_teleport_and_restore_after_frame")

func _after_scene_change_restore_and_teleport() -> void:
	await get_tree().create_timer(0.15).timeout
	_try_restore_bloodstain()
	_teleport_player()

func _teleport_and_restore_after_frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_try_restore_bloodstain()
	_teleport_player()

func _teleport_player() -> void:
	var player = PlayerManager.current_player
	if player and is_instance_valid(player):
		var old_pos = player.global_position
		player.global_position = current_spawn_position
		print("[Checkpoint] SUCCESS - teleported player from ", old_pos, " → ", current_spawn_position)
	else:
		push_warning("[Checkpoint] No player via PlayerManager - using fallback group search")
		player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var old_pos = player.global_position
			player.global_position = current_spawn_position
			print("[Checkpoint] Fallback SUCCESS - teleported player from ", old_pos, " → ", current_spawn_position)
		else:
			push_error("[Checkpoint] NO PLAYER FOUND - registration failed. Check PlayerManager / group 'player'")

func _try_restore_bloodstain() -> void:
	if not Global.has_pending_bloodstain:
		return
	if Global.last_death_scene != get_tree().current_scene.scene_file_path:
		print("[Checkpoint] Bloodstain pending but wrong scene → skip")
		return
	
	# Cleanup pass: remove any bloodstains that don't match the current death position
	for node in get_tree().current_scene.get_children():
		if node is Area2D and node.has_method("bob_animation"):
			if node.global_position.distance_to(Global.last_death_pos) > 30.0:
				node.queue_free()
				print("[Checkpoint] Removed orphaned/old bloodstain far from death pos at ", node.global_position)
	
	# Duplicate check: only spawn if nothing is already very close to death pos
	var should_spawn = true
	for node in get_tree().current_scene.get_children():
		if node is Area2D and node.has_method("bob_animation"):
			if node.global_position.distance_to(Global.last_death_pos) < 5.0:
				should_spawn = false
				print("[Checkpoint] Bloodstain already present at/near death pos → keeping it")
				break
	
	if not should_spawn:
		return
	
	print("[Checkpoint] SPAWNING bloodstain POST-RESPAWN at ", Global.last_death_pos)
	var bloodstain_scene = preload("res://scenes/entities/bloodstain/bloodstain.tscn")
	if not bloodstain_scene:
		push_error("[Checkpoint] Failed to preload bloodstain.tscn")
		return
	
	var stain = bloodstain_scene.instantiate()
	
	var ysort = get_tree().current_scene.get_node_or_null("YSort") or get_tree().current_scene.get_node_or_null("ysort")
	if ysort:
		ysort.call_deferred("add_child", stain)
		print("[Checkpoint] Bloodstain added to YSort (deferred)")
	else:
		get_tree().current_scene.call_deferred("add_child", stain)
		print("[Checkpoint] Bloodstain added to scene root (deferred - no YSort)")
	
	# CRITICAL FIX: set souls_held AFTER add_child (deferred so _ready() has run)
	stain.call_deferred("set", "souls_held", Global.dropped_souls)
	print("[Checkpoint] souls_held set to ", Global.dropped_souls, " (deferred after add_child)")
	
	print("[Checkpoint] Bloodstain spawned post-respawn (pending kept until pickup)")
