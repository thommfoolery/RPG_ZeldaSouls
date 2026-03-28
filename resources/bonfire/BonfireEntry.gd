@tool
class_name BonfireEntry
extends Resource

@export var area_name: String = ""
@export var bonfire_id: String = ""                     # must be unique forever (e.g. "test_001")
@export_file("*.tscn") var scene_path: String = ""      # full path to the level scene
@export var spawn_position: Vector2 = Vector2.ZERO      # where player spawns when resting / respawning here
@export var title: String = "Unknown Outpost"
@export var subtitle: String = "A lonely flame in the fog..."
@export var is_lit_on_first_rest: bool = true
@export var discovery_sfx: AudioStream = null
@export var rest_particle_color: Color = Color(1.0, 0.6, 0.3, 1.0)
@export var preview_texture: Texture2D = null
@export var sort_order: int = 999   # Lower = appears higher in the list inside its area
