extends Node2D

func _ready() -> void:
	Global.current_scene = "world"   # ← this is the only real difference here
	print("world _ready | Pending bloodstain? ", Global.has_pending_bloodstain, " | souls: ", Global.dropped_souls)
	
	# ─── BLOODSTAIN SPAWN (identical to cliff_side) ───
	if Global.has_pending_bloodstain and Global.dropped_souls > 0:
		var current_scene_path = get_tree().current_scene.scene_file_path
		print("Bloodstain check:")
		print("  Pending: ", Global.has_pending_bloodstain)
		print("  Souls: ", Global.dropped_souls)
		print("  Death scene stored: ", Global.last_death_scene)
		print("  Current scene path: ", current_scene_path)
		print("  Death position: ", Global.last_death_pos)
		
		var norm_death = Global.last_death_scene.get_file().get_basename()
		var norm_current = current_scene_path.get_file().get_basename()
		
		if norm_death == norm_current or Global.last_death_scene == current_scene_path:
			print("MATCH → spawning bloodstain at ", Global.last_death_pos)
			if Global.last_death_pos == Vector2.ZERO:
				print("WARNING: Death pos is ZERO — using fallback")
				var player = $ysort/player if $ysort and $ysort.has_node("player") else null
				Global.last_death_pos = player.global_position if player else Vector2(100, 100)
			
			var stain = preload("res://scenes/entities/bloodstain/bloodstain.tscn").instantiate()
			stain.global_position = Global.last_death_pos
			stain.souls_held = Global.dropped_souls
			
			if has_node("ysort"):
				$ysort.add_child(stain)
				print("Bloodstain added to ysort")
			else:
				add_child(stain)
				print("WARNING: No ysort found — bloodstain added to root")
			
			Global.has_pending_bloodstain = false
			Global.dropped_souls = 0
		else:
			print("NO MATCH — bloodstain still pending (paths differ)")
	else:
		print("No pending bloodstain")
	
	# ─── PLAYER POSITION LOGIC ───
	var player = $ysort/player if $ysort and $ysort.has_node("player") else null
	if not player:
		push_error("Player node not found in ysort!")
		return
	
	if PlayerStats.is_respawning_after_death:
		# ─── DEATH RESPAWN PATH ───
		print("DEATH RESPAWN flow active")
		if CheckpointManager.has_valid_checkpoint():
			player.global_position = CheckpointManager.last_checkpoint_position
			print("DEATH RESPAWN: Placed player at bonfire/checkpoint pos ", player.global_position)
		else:
			player.global_position = Vector2(100, 200)  # world fallback
			print("No valid checkpoint → fallback spawn at ", player.global_position)
		
		PlayerStats.is_respawning_after_death = false  # CRITICAL reset
	else:
		# ─── NORMAL WALK-IN / SCENE LOAD ───
		var entrance = get_node_or_null("PlayerEntranceMarker")
		if entrance:
			player.global_position = entrance.global_position
			print("Normal load/transition → player placed at entrance marker ", player.global_position)
		else:
			print("WARNING: No 'PlayerEntranceMarker' node found in world → using fallback")
			player.global_position = Vector2(100, 200)  # ← your preferred world entrance coords
	
	# ─── ENEMY SPAWNING ───
	spawn_all_enemies()


func spawn_all_enemies() -> void:
	var spawners = get_tree().get_nodes_in_group("enemy_spawners")
	for spawner in spawners:
		spawner.has_spawned = false  # reset on every scene load
		spawner.spawn_enemies()
	print("Loaded ", spawners.size(), " spawners → fresh enemies!")


func _process(_delta: float) -> void:
	change_scene()


# ─── TRANSITION TO CLIFF_SIDE ───
func _on_cliffside_transition_point_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		print("Player entered cliffside transition → setting flag")
		Global.transition_scene = true


func _on_cliffside_transition_point_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		print("Player exited cliffside transition → clearing flag")
		Global.transition_scene = false


func change_scene() -> void:
	if Global.transition_scene and Global.current_scene == "world":
		print("Changing to cliff_side.tscn")
		get_tree().change_scene_to_file("res://scenes/cliff_side.tscn")
		Global.transition_scene = false
