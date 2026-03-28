extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene 
@export var spawn_count: int = 3
@export var spawn_radius: float = 50.0
@export var auto_spawn_on_ready: bool = true

var has_spawned: bool = false

func _ready() -> void:
	add_to_group("enemy_spawners")
	if auto_spawn_on_ready:
		call_deferred("spawn_enemies")  # ← Defer the whole spawn!

func spawn_enemies() -> void:
	if has_spawned: return
	_do_spawn()
	has_spawned = true

func reset_and_spawn() -> void:  # For bonfire rest
	has_spawned = false
	_do_spawn()
	has_spawned = true
	print("Respawn forced at ", name)

func _do_spawn() -> void:
	var parent_node = get_tree().current_scene.find_child("ysort", true, false)
	if not parent_node:
		parent_node = get_tree().current_scene.find_child("collisions", true, false)
	if not parent_node:
		parent_node = get_tree().current_scene
	
	print("Spawning under: ", parent_node.name, " at global pos ", global_position)
	
	for i in spawn_count:
		var enemy = enemy_scene.instantiate()
		var offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		var spawn_pos = global_position + offset
		
		# Defer per-enemy add (safest during _ready or any init phase)
		parent_node.call_deferred("add_child", enemy)
		
		# Position set after deferred add (safe, runs next frame)
		enemy.call_deferred("set", "global_position", spawn_pos)
		
		enemy.add_to_group("enemies")
		
		print("  → Enemy ", i+1, " queued at global: ", spawn_pos)
