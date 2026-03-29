# autoload/ProjectileSpawner.gd
extends Node

signal projectile_fired(item: GameItem, projectile: Projectile)

const PROJECTILE_SCENE = preload("res://scenes/entities/projectiles/Projectile.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[PROJECTILE-SPAWNER] Ready — single reusable spawner for all ranged items")

# PUBLIC API
func spawn_projectile(item: GameItem, spawn_global_pos: Vector2, direction: Vector2 = Vector2.RIGHT) -> Projectile:
	if not item:
		push_error("[ProjectileSpawner] spawn_projectile called with null GameItem")
		return null

	# Safe trajectory lookup - Resource.get() only takes 1 argument
	var traj: String = "Straight"
	if "trajectory_type" in item and item.trajectory_type != "":
		traj = item.trajectory_type

	print("[ProjectileSpawner] SPAWNING → ", item.display_name, " | trajectory=", traj)

	var proj: Projectile = PROJECTILE_SCENE.instantiate()
	if not proj:
		push_error("[ProjectileSpawner] Failed to instantiate Projectile.tscn")
		return null

	proj.game_item = item

	# ULTRA-SAFE PARENT
	var parent: Node = get_tree().current_scene
	var ysort = get_tree().current_scene.get_node_or_null("ysort")
	if ysort:
		parent = ysort
	else:
		ysort = get_tree().current_scene.get_node_or_null("YSort")
		if ysort:
			parent = ysort
		else:
			ysort = get_tree().current_scene.get_node_or_null("Ysort")
			if ysort:
				parent = ysort

	print("[ProjectileSpawner] Using parent: ", parent.name, " (", parent.get_path(), ")")

	parent.call_deferred("add_child", proj)
	proj.call_deferred("_deferred_launch", spawn_global_pos, direction)

	projectile_fired.emit(item, proj)
	return proj


# INTERNAL DEFERRED LAUNCH
func _deferred_launch(proj: Projectile, spawn_pos: Vector2, dir: Vector2) -> void:
	if not is_instance_valid(proj):
		return

	proj.global_position = spawn_pos
	proj.launch(dir, spawn_pos)

	print("[ProjectileSpawner] LAUNCHED at ", spawn_pos.round(), " dir=", dir)
