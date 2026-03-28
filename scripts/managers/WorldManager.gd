# autoload/WorldManager.gd
extends Node

func _ready() -> void:
	print("[WorldManager] Ready — scene entry only (BloodstainManager handles stains)")
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_run_on_load")


func _on_scene_changed(_old = null) -> void:
	call_deferred("_run_on_load")

func _run_on_load() -> void:
	await get_tree().create_timer(0.4).timeout
	print("[WorldManager-DEBUG] === SCENE LOAD ===", get_tree().current_scene.scene_file_path.get_file())
	print(" └─ has_pending_bloodstain =", Global.has_pending_bloodstain)
	print(" └─ is_death_respawn =", Global.is_death_respawn)
	_register_player()
	print("[WorldManager-DEBUG] Load mode check")
	print(" └─ is_death_respawn: ", Global.is_death_respawn)
	print(" └─ has_pending_bloodstain: ", Global.has_pending_bloodstain)
	print(" └─ death_age_seconds: ", (Time.get_unix_time_from_system() - Global.death_timestamp if Global.death_timestamp > 0 else 999999))
	var current_time = Time.get_unix_time_from_system()
	var death_age_seconds = current_time - Global.death_timestamp if Global.death_timestamp > 0 else 999999
	# ─── MINIMAL FIX: ONLY force bonfire if death flag AND NO transition marker (normal walk wins) ───
	if Global.has_pending_bloodstain and Global.is_death_respawn and not SceneEntryOrchestrator.pending_spawn_marker:
		print("[WorldManager] DEATH RELOAD detected — forcing bonfire respawn")
		print(" └─ Reason: death_respawn flag")
		if CheckpointManager and CheckpointManager.has_valid_checkpoint():
			print(" └─ Using CheckpointManager.respawn()")
			print(" └─ Respawn scene: ", CheckpointManager.current_scene_path.get_file())
			print(" └─ Respawn pos: ", CheckpointManager.current_spawn_position.round())
			CheckpointManager.respawn()
			Global.is_death_respawn = false
			print("[WorldManager] DEATH RESPAWN COMPLETE — cleared is_death_respawn flag (bloodstain persists until pickup)")
		else:
			print(" └─ No checkpoint → fallback to scene start")
		return
	# Otherwise → normal load at last saved position
	print("[WorldManager] Normal/old load or long break → restoring saved position")
	var pos = Vector2(Global.player_pos_x, Global.player_pos_y)
	print(" └─ Loaded saved position from Global: ", pos.round())
	print(" └─ Is ZERO vector? ", pos == Vector2.ZERO)
	print(" └─ Player exists and valid? ", PlayerManager.current_player != null and is_instance_valid(PlayerManager.current_player))
	if pos != Vector2.ZERO and PlayerManager.current_player:
		PlayerManager.current_player.global_position = pos
		print("[WorldManager] NORMAL RELOAD → restored exact position: ", pos.round())
		print(" └─ Position actually set to: ", PlayerManager.current_player.global_position.round())
	else:
		print("[WorldManager] No valid saved pos → default spawn")
	await get_tree().create_timer(0.4).timeout
	_register_player()
	_apply_position_on_load()
	print("[WorldManager-DEBUG] Skipped hardcoded title card (now commented out)")
	if BloodstainManager:
		BloodstainManager.spawn_if_pending()
	print("[WorldManager] Forced bloodstain check on load/respawn")
	var final_pos = Vector2(Global.player_pos_x, Global.player_pos_y)
	if final_pos != Vector2.ZERO and PlayerManager.current_player and is_instance_valid(PlayerManager.current_player):
		var current = PlayerManager.current_player.global_position
		if current.distance_to(final_pos) > 10.0:
			PlayerManager.current_player.global_position = final_pos
			print("[WorldManager] FINAL SAFETY RESTORE → player now at saved pos: ", final_pos.round())
		else:
			print("[WorldManager] Saved pos already close — no override needed")

func _register_player() -> void:
	print("[PLAYER-LIFECYCLE] WorldManager._register_player() called but now passive (Orchestrator owns lifecycle)")
	# Do nothing. Orchestrator + InstantiationService are now the only creators.

func _apply_position_on_load() -> void:
	print("[WorldManager] Load mode check → is_death_respawn = ", Global.is_death_respawn)
	var current_time = Time.get_unix_time_from_system()
	var death_age_seconds = current_time - Global.death_timestamp if Global.death_timestamp > 0 else 999999
	# ─── STRICT FIX: ONLY force bonfire if death flag is STILL true AND no transition marker ───
	if Global.is_death_respawn and not SceneEntryOrchestrator.pending_spawn_marker:
		print("[WorldManager] DEATH RELOAD (recent ", death_age_seconds, "s ago or flagged) → forcing bonfire respawn")
		if CheckpointManager and CheckpointManager.has_valid_checkpoint():
			CheckpointManager.respawn()
		else:
			print("[WorldManager] No checkpoint yet → fallback to scene start")
		return
	print("[WorldManager] Normal/old load or long break → restoring saved position")
	var pos = Vector2(Global.player_pos_x, Global.player_pos_y)
	if pos != Vector2.ZERO and PlayerManager.current_player:
		PlayerManager.current_player.global_position = pos
		print("[WorldManager] NORMAL RELOAD → restored exact position: ", pos)
	else:
		print("[WorldManager] No valid saved pos → default spawn")
