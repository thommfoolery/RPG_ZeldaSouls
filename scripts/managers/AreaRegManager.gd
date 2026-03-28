# autoload/AreaRegManager.gd
extends Node

var registry: AreaRegistry

func _ready() -> void:
	registry = preload("res://resources/area/AreaRegistry.tres") as AreaRegistry
	if registry == null:
		push_error("[AreaReg] CRITICAL: Failed to preload AreaRegistry.tres!")
		return
	
	print("[AreaReg] Successfully loaded registry with ", registry.entries.size(), " areas")
	if registry.entries.is_empty():
		push_warning("[AreaReg] Warning: No AreaEntry resources added yet — transitions will fail")

# Helper: resolve area_id from current scene path
func get_area_id_for_scene(scene_path: String) -> String:
	print("[PATH-DEBUG] Incoming path (Godot truth): '", scene_path, "'")
	
	for entry in registry.entries:
		print("[PATH-DEBUG] Stored in registry: '", entry.scene_path, "' → ID: ", entry.area_id)
		if entry.scene_path == scene_path:
			print("[PATH-DEBUG] MATCH → returning ", entry.area_id)
			return entry.area_id
	
	print("[PATH-DEBUG] NO MATCH – registry paths do not equal Godot's scene_file_path")
	return ""
