@tool
class_name AreaRegistry
extends Resource

@export var entries: Array[AreaEntry] = []

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if entries.is_empty():
		warnings.append("No areas defined yet — game will have no levels!")
	for i in entries.size():
		var e = entries[i]
		if e.area_id.is_empty():
			warnings.append("Entry #%d has empty area_id" % i)
		if e.scene_path.is_empty():
			warnings.append("Entry '%s' has no scene_path" % e.area_id)
	return warnings

# Helper – get by id (used everywhere)
func get_area(area_id: String) -> AreaEntry:
	for e in entries:
		if e.area_id == area_id:
			return e
	push_warning("Area not found in registry: " + area_id)
	return null

# Optional: debug print in editor
func _get_property_list() -> Array:
	if Engine.is_editor_hint():
		print("[AreaReg] Loaded %d areas" % entries.size())
	return []
