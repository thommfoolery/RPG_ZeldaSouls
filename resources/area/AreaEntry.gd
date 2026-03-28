@tool
class_name AreaEntry
extends Resource

@export var area_id: String = "" 
@export_file("*.tscn") var scene_path: String = "" 
@export var title: String = "Unknown Region"
@export var subtitle: String = "The fog thickens..."
@export var first_visit_subtitle: String = "" 
@export var ambient_color: Color = Color(0.1, 0.1, 0.15, 1.0)
@export var music_track: AudioStream = null
@export var dlc_namespace: String = "" 

# ── NEW: Golden Order ──
@export var sort_order: int = 999   # Lower number = appears earlier in tabs

func _to_string() -> String:
	return "[AreaEntry:%s → %s]" % [area_id, scene_path.get_file() if scene_path else "?"]
