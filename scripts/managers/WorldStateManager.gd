# autoload/WorldStateManager.gd
extends Node
# ─── FUTURE-PROOF WORLD STATE (5+ years, DLC-ready) ─────────────────────
# Structure per scene:
# {
# "res://scenes/cliff_side.tscn": {
# "permanent": {
# "opened_doors": ["door_001"],
# "defeated_bosses": ["boss_gargoyle"],
# "taken_items": ["estus_shard_01"],
# "activated_switches": ["lever_poison"],
# "custom_flags": { "poison_swamp_drained": true }
# },
# "regular_dead_enemies": ["goblin_001"] # cleared ONLY on bonfire rest/warp
# }
# }
var world_state: Dictionary = {}
var discovered_areas: Dictionary = {} # area_id → true (switched to ID keying for future-proofing)

const PERMANENT_CATEGORIES = ["opened_doors", "defeated_bosses", "taken_items", "activated_switches"]
const REGULAR_DEAD_KEY = "regular_dead_enemies"
const CUSTOM_FLAGS_KEY = "custom_flags"

func _ready() -> void:
	print("[WorldStateManager] Ready — single source of truth for persistent world")
	
	# ─── DEV MODE: Force re-discovery of test areas (remove/comment after testing) ───
	if OS.has_feature("editor"):
		discovered_areas.erase("res://scenes/world001.tscn")
		discovered_areas.erase("res://scenes/world002.tscn")
		discovered_areas.erase("res://scenes/_testroom.tscn")
		print("[WorldStateManager-DEV] Cleared discovered flags for world001/002/_testroom → titles will fire next load")

# ─── CORE STATE LOADER (100% old-save safe) ─────────────────────────────
func get_or_create_scene_state(scene_path: String) -> Dictionary:
	if not world_state.has(scene_path):
		world_state[scene_path] = {
			"permanent": { CUSTOM_FLAGS_KEY: {} },
			REGULAR_DEAD_KEY: []
		}
		for cat in PERMANENT_CATEGORIES:
			world_state[scene_path].permanent[cat] = []
	
	var scene_data = world_state[scene_path]
	
	# Very old saves (pre-permanent structure)
	if not scene_data.has("permanent"):
		scene_data["permanent"] = { CUSTOM_FLAGS_KEY: {} }
	
	var perm = scene_data.permanent
	
	# Add any missing permanent categories from earlier script versions
	for cat in PERMANENT_CATEGORIES:
		if not perm.has(cat):
			perm[cat] = []
	
	# Ensure custom_flags always exists
	if not perm.has(CUSTOM_FLAGS_KEY):
		perm[CUSTOM_FLAGS_KEY] = {}
	
	return scene_data

# ─── NEW: TAKEN ITEMS (One-time pickups) ─────────────────────────────────
# Added with heavy debug prints as requested
func mark_taken_item(pickup_id: String, scene_path: String = "") -> void:
	if pickup_id.is_empty():
		push_warning("[WorldStateManager] mark_taken_item called with empty pickup_id!")
		return
	
	if scene_path.is_empty():
		scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	
	var state = get_or_create_scene_state(scene_path)
	if not state.permanent["taken_items"].has(pickup_id):
		state.permanent["taken_items"].append(pickup_id)
		SaveManager.request_save()
		print("[WorldStateManager] Item permanently taken: ", pickup_id, " | Scene: ", scene_path.get_file())
	else:
		print("[WorldStateManager] Item was already marked as taken: ", pickup_id)

func has_taken_item(pickup_id: String, scene_path: String = "") -> bool:
	if pickup_id.is_empty():
		return false
	
	if scene_path.is_empty():
		scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	
	var result = get_or_create_scene_state(scene_path).permanent["taken_items"].has(pickup_id)
	print("[WorldStateManager] has_taken_item('", pickup_id, "') = ", result, " | Scene: ", scene_path.get_file())
	return result

# ─── REGULAR ENEMIES (reset on rest/warp) ───────────────────────────────
func mark_regular_dead(enemy_id: String, scene_path: String = "") -> void:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			push_error("[WorldStateManager] Cannot mark_regular_dead — current_scene is null")
			return
		scene_path = get_tree().current_scene.scene_file_path
	var state = get_or_create_scene_state(scene_path)
	if not state[REGULAR_DEAD_KEY].has(enemy_id):
		state[REGULAR_DEAD_KEY].append(enemy_id)
		SaveManager.request_save()
		print("[WorldStateManager-DEBUG] Regular enemy marked until rest: ", enemy_id, " (", scene_path.get_file(), ")")

func is_regular_dead(enemy_id: String, scene_path: String = "") -> bool:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			return false
		scene_path = get_tree().current_scene.scene_file_path
	return get_or_create_scene_state(scene_path)[REGULAR_DEAD_KEY].has(enemy_id)

# ─── PERMANENT CHANGES (doors, bosses, items, switches, etc.) ───────────
func mark_permanent(category: String, id: String, scene_path: String = "") -> void:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			push_error("[WorldStateManager] Cannot mark_permanent — current_scene is null")
			return
		scene_path = get_tree().current_scene.scene_file_path
	if not PERMANENT_CATEGORIES.has(category):
		push_warning("[WorldStateManager] Unknown permanent category: " + category)
		return
	var state = get_or_create_scene_state(scene_path)
	var list = state.permanent[category]
	if not list.has(id):
		list.append(id)
		SaveManager.request_save()
		print("[WorldStateManager-DEBUG] PERMANENT ", category, " marked: ", id, " (", scene_path.get_file(), ")")

func is_permanent(category: String, id: String, scene_path: String = "") -> bool:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			return false
		scene_path = get_tree().current_scene.scene_file_path
	if not PERMANENT_CATEGORIES.has(category):
		return false
	return get_or_create_scene_state(scene_path).permanent[category].has(id)

# ─── ONE-OFF BOOLEAN FLAGS (poison swamp, secret walls, gates, etc.) ────
func set_custom_flag(flag_name: String, value: bool = true, scene_path: String = "") -> void:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			push_error("[WorldStateManager] Cannot set_custom_flag — current_scene is null")
			return
		scene_path = get_tree().current_scene.scene_file_path
	var state = get_or_create_scene_state(scene_path)
	state.permanent[CUSTOM_FLAGS_KEY][flag_name] = value
	SaveManager.request_save()
	print("[WorldStateManager-DEBUG] Custom flag: ", flag_name, " = ", value, " (", scene_path.get_file(), ")")

func is_custom_flag_set(flag_name: String, scene_path: String = "") -> bool:
	if scene_path.is_empty():
		if get_tree().current_scene == null:
			return false
		scene_path = get_tree().current_scene.scene_file_path
	return get_or_create_scene_state(scene_path).permanent[CUSTOM_FLAGS_KEY].get(flag_name, false)

# ─── RESET LOGIC ────────────────────────────────────────────────────────
func reset_regular_enemies(target_scene_path: String = "") -> void:
	var path: String = target_scene_path
	if path.is_empty():
		if get_tree().current_scene == null:
			push_error("[WorldStateManager] Cannot reset_regular_enemies — current_scene is null")
			return
		path = get_tree().current_scene.scene_file_path
	if world_state.has(path):
		world_state[path][REGULAR_DEAD_KEY].clear()
		SaveManager.request_save()
		print("[WorldStateManager-DEBUG] Regular enemies RESET: ", path.get_file())

func reset_all_regular_enemies() -> void:
	for path in world_state:
		if world_state[path].has(REGULAR_DEAD_KEY):
			world_state[path][REGULAR_DEAD_KEY].clear()
	SaveManager.request_save()
	print("[WorldStateManager-DEBUG] ALL regular enemies reset world-wide")

# Apply on every scene load (walking OR warp)
func apply_state_to_scene() -> void:
	var path = get_tree().current_scene.scene_file_path
	var state = get_or_create_scene_state(path)
	print("[WorldStateManager] State applied to ", path.get_file(),
	  " | Regular dead: ", state[REGULAR_DEAD_KEY].size(),
	  " | Permanent cats: ", state.permanent.size() - 1,
	  " | Custom flags: ", state.permanent[CUSTOM_FLAGS_KEY].size())

# ─── Bonfire-specific helpers ────────────────────────────────────────────
func discover_bonfire(bonfire_id: String) -> bool:
	if bonfire_id.is_empty():
		return false
	if not PlayerStats.discovered_bonfires.has(bonfire_id):
		PlayerStats.discovered_bonfires[bonfire_id] = true
	var scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if not discovered_areas.has(scene_path):
		discovered_areas[scene_path] = true
		print("[WorldStateManager] Area discovered via bonfire: ", scene_path.get_file())
	SaveManager.request_save() if SaveManager else null
	return true

func is_bonfire_discovered(bonfire_id: String) -> bool:
	return PlayerStats.discovered_bonfires.has(bonfire_id)

# In WorldStateManager.gd

# Add to your regular world state dictionary (or permanent if you prefer)
func set_vendor_stock(vendor_id: String, listing_index: int, stock: int) -> void:
	var key = "vendor_stock_" + vendor_id + "_" + str(listing_index)
	# Assuming you have a dict like world_state or regular_state
	world_state[key] = stock   # or permanent_state if it's never reset
	print("[WorldStateManager] Saved vendor stock: ", key, " = ", stock)

func get_vendor_stock(vendor_id: String, listing_index: int) -> int:
	var key = "vendor_stock_" + vendor_id + "_" + str(listing_index)
	return world_state.get(key, -1)  # -1 = not saved yet
