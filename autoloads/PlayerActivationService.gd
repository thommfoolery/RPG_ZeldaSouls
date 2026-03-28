# autoload/PlayerActivationService.gd
extends Node

signal player_fully_active(player: Node)  # ← CameraManager, HUD, etc. will listen

func activate_and_position_player(target_pos: Vector2) -> void:
	print("[PLAYER-LIFECYCLE] Activate_and_position_player called with pos ", target_pos.round(), 
		  " | Current player ID: ", PlayerManager.current_player.get_instance_id() if PlayerManager.current_player else "null")
	# ... rest unchanged
	print("!!! ACTIVATE called with pos ", target_pos)
	var player = PlayerManager.current_player
	if not player: return
	
	print("[ActivationService] Setting player position to: ", target_pos.round())
	player.global_position = target_pos
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	
	# ─── ADDED DIAGNOSTIC PRINTS ───
	print("[ActivationService] Position right AFTER set: ", player.global_position.round())
	print("  └─ Is player valid? ", is_instance_valid(player))
	print("  └─ Parent node: ", player.get_parent().name if player.get_parent() else "[no parent]")
	# ─── End of prints ───
	
	print("[Activation] Player activated at ", target_pos.round())
	
	# NEW — activate camera here
	CameraManager.activate_player_camera()
	player_fully_active.emit(player)
