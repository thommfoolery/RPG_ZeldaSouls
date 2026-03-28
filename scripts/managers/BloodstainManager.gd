# autoload/BloodstainManager.gd
extends Node

const BLOODSTAIN_SCENE = preload("res://scenes/entities/bloodstain/bloodstain.tscn")

var _spawned_this_death: bool = false # one-shot guard per death cycle

func _ready() -> void:
	print("[BloodstainManager] Initialized — managing bloodstains across scenes")
	if get_tree():
		get_tree().scene_changed.connect(_on_scene_changed)
		call_deferred("spawn_if_pending")
	# EventBus listener (from DeathHandler)
	if EventBus:
		EventBus.player_died.connect(_on_player_died)
		print("[BloodstainManager] Subscribed to EventBus.player_died")
	else:
		print("[BloodstainManager] WARNING: get_tree() not ready yet")

func _on_scene_changed(_old_scene = null) -> void:
	print("[BloodstainManager] Scene changed — checking bloodstain")
	_spawned_this_death = false # reset guard on reload
	call_deferred("spawn_if_pending")

# ─── EventBus handler ───
func _on_player_died(death_position: Vector2, dropped_souls: int) -> void:
	print("[BloodstainManager] Received player_died via EventBus — queuing spawn")
	
	# FIX: Store death info separately (rest/checkpoint won't overwrite)
	Global.death_scene_path = get_tree().current_scene.scene_file_path
	Global.death_locked_pos = death_position
	Global.dropped_souls = dropped_souls
	Global.has_pending_bloodstain = true  # keep for UI/debug
	
	print("[BloodstainManager] Locked death info for persistence:")
	print("  └─ Death scene: ", Global.death_scene_path.get_file())
	print("  └─ Locked pos: ", Global.death_locked_pos.round())
	print("  └─ Souls: ", dropped_souls)
	
	call_deferred("spawn_if_pending")

# CLEANUP
func _clear_all_bloodstains() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	for child in scene.get_children():
		if child.is_in_group("bloodstains"):
			child.queue_free()
			print("[BloodstainManager] Cleared old bloodstain instance")
	# Extra safety: clear any lingering in Ysort
	var ysort = scene.get_node_or_null("Ysort")
	if ysort:
		for child in ysort.get_children():
			if child.is_in_group("bloodstains"):
				child.queue_free()
				print("[BloodstainManager] Cleared lingering bloodstain in Ysort")

# MAIN SPAWN FUNCTION — with deferred position fix
func spawn_if_pending() -> void:
	if Global.death_scene_path.is_empty():
		print("[BloodstainManager] No death_scene_path stored - skipping")
		return
	
	var current_scene = get_tree().current_scene
	if not current_scene or Global.death_scene_path != current_scene.scene_file_path:
		print("[BloodstainManager] Wrong scene (death was in ", Global.death_scene_path.get_file(), ") - skipping")
		return
	
	if _spawned_this_death:
		print("[BloodstainManager] Already spawned this death cycle")
		return
	
	print("[BloodstainManager] Persistent spawn triggered | pos: ", Global.death_locked_pos.round(), " souls: ", Global.dropped_souls)
	
	_clear_all_bloodstains()
	
	var stain = BLOODSTAIN_SCENE.instantiate()
	stain.souls_held = Global.dropped_souls
	
	# ─── ULTRA-SAFE PARENT (no or chaining, no bool crash) ───
	var parent: Node = current_scene.get_node_or_null("ysort")
	if not parent:
		parent = current_scene.get_node_or_null("YSort")
	if not parent:
		parent = current_scene.get_node_or_null("Ysort")
	if not parent:
		parent = current_scene
	
	print("[BloodstainManager] Using parent: ", parent.name)
	
	parent.add_child(stain)
	stain.call_deferred("set", "global_position", Global.death_locked_pos)
	
	_spawned_this_death = true
	print("[BloodstainManager] Spawn SUCCESS | souls: ", Global.dropped_souls)
