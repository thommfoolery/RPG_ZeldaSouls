# autoload/PlayerInstantiationService.gd
extends Node

## Single source of truth for player instantiation.
## Goal: Create once, reuse across scene changes and warps when possible.

func instantiate_or_reuse_player(current_scene: Node) -> void:
	if not current_scene:
		push_error("[PLAYER-LIFECYCLE] instantiate_or_reuse_player called with null scene")
		return
	
	var scene_name = current_scene.scene_file_path.get_file()
	print("[PLAYER-LIFECYCLE] === InstantiationService called for scene: ", scene_name)

	# ─── REUSE CHECK ───
	var existing = PlayerManager.current_player
	if existing and is_instance_valid(existing):
		# Reuse if the player node is still alive and has a parent
		if existing.get_parent() != null:
			print("[PLAYER-LIFECYCLE] Reusing existing player (ID: ", existing.get_instance_id(), ")")
			# Make sure it's in the correct scene if needed
			if existing.get_parent() != current_scene and existing.get_parent().get_parent() != current_scene:
				var ysort = _safe_get_ysort(current_scene)
				if ysort:
					ysort.add_child(existing)
				else:
					current_scene.add_child(existing)
			return

	# ─── CREATE NEW ───
	print("[PLAYER-LIFECYCLE] No valid reusable player → creating new instance")

	var packed = preload("res://scenes/entities/player.tscn") as PackedScene
	var player = packed.instantiate()

	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var ysort = _safe_get_ysort(current_scene)
	if ysort:
		ysort.add_child(player)
	else:
		current_scene.add_child(player)

	player.add_to_group("player")
	PlayerManager.register_player(player)

	print("[PLAYER-LIFECYCLE] NEW Player instantiated (ID: ", player.get_instance_id(), 
		  ") → path: ", player.get_path())
	print("  └─ Added under: ", player.get_parent().name if player.get_parent() else "null")
	print("  └─ Position right after add_child: ", player.global_position.round())

	print("[PLAYER-LIFECYCLE] InstantiationService finished. Final PlayerManager ID: ", 
		  PlayerManager.current_player.get_instance_id() if PlayerManager.current_player else "NONE")


func _safe_get_ysort(scene: Node) -> Node:
	var ysort = scene.get_node_or_null("YSort")
	if ysort: return ysort
	return scene.get_node_or_null("ysort")
