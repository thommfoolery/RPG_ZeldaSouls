# autoload/BonfireManager.gd
extends Node

var registry: BonfireRegistry
var _lookup: Dictionary = {}  # bonfire_id → BonfireEntry

func _ready() -> void:
	registry = preload("res://resources/bonfire/BonfireRegistry.tres")
	if not registry:
		push_error("[BonfireManager] Failed to load BonfireRegistry.tres!")
		return
	
	_build_lookup()
	print("[BonfireManager] Loaded registry with ", registry.entries.size(), " bonfires")

func _build_lookup() -> void:
	_lookup.clear()
	for entry in registry.entries:
		if entry.bonfire_id.is_empty():
			push_warning("[BonfireManager] Skipping entry with empty bonfire_id")
			continue
		if _lookup.has(entry.bonfire_id):
			push_warning("[BonfireManager] Duplicate bonfire_id: " + entry.bonfire_id)
		_lookup[entry.bonfire_id] = entry
	
	print("[BonfireManager] Lookup table built — ", _lookup.size(), " valid entries")

func get_entry(id: String) -> BonfireEntry:
	if id.is_empty():
		push_warning("[BonfireManager] get_entry() called with empty id")
		return null
	return _lookup.get(id)

# Called when player first lights/rests at a bonfire
# Called when player first lights/rests at a bonfire
func discover_bonfire(id: String) -> bool:
	if id.is_empty():
		push_warning("[BonfireManager] discover_bonfire() called with empty id")
		return false
	
	# ─── Logging ───
	var current_scene_file = "NO_SCENE"
	if get_tree().current_scene:
		current_scene_file = get_tree().current_scene.scene_file_path.get_file()
	
	print("[BonfireManager] discover_bonfire CALLED | bonfire_id: ", id,
		  " | already known? ", PlayerStats.discovered_bonfires.has(id),
		  " | current scene: ", current_scene_file)
	
	# Short call stack (shows who called us)
	var call_stack = get_stack()
	if call_stack.size() >= 3:
		var caller = call_stack[2]
		print("  └─ called from: ", caller["source"].get_file(), ":", caller["line"],
			  " in ", caller["function"], "()")
	
	if PlayerStats.discovered_bonfires.has(id):
		print("  → already discovered → skipping title")
		return false
	
	# ─── Actual discovery ───
	PlayerStats.discovered_bonfires[id] = true
	print("  → NEW DISCOVERY → queuing title card for ", id)
	
	var bonfire_entry = get_entry(id)
	if bonfire_entry and TitleCardManager:
		print("  → Title queued from BonfireManager for \"", bonfire_entry.title, "\"")
		TitleCardManager.show_title(
			bonfire_entry.title,
			bonfire_entry.subtitle,
			4.0,
			true,   # warm color
			true    # first visit only
		)
	
	if SaveManager:
		SaveManager.request_save()
	
	return true
