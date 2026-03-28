# autoload/global.gd
extends Node

var world_time: float = 0.0
var player_current_attack = false
var current_scene = "world"
var transition_scene = false
var player_exit_cliffside_posx = 0
var player_exit_cliffside_posy = 0
var player_start_posx = 0
var player_start_posy = 0
var player_pos_x: float = 0.0
var player_pos_y: float = 0.0
var is_death_respawn: bool = false
var death_timestamp: int = 0
var last_saved_scene_path: String = ""
var saved_positions_per_scene: Dictionary = {}
# ── MENU INPUT SAFETY ──
var menu_close_cooldown_until: int = 0   # timestamp in msec

# ─── HEALTH PERSISTENCE ───
var current_health: float = 101.0
var current_stamina: float = 100.0

# Death & bloodstain
var last_death_pos: Vector2 = Vector2.ZERO
var last_death_scene: String = ""
var dropped_souls: int = 0
var has_pending_bloodstain: bool = false
var death_scene_path: String = ""
var death_locked_pos: Vector2 = Vector2.ZERO
var locked_death_pos: Vector2 = Vector2.ZERO

# Menu state
var is_in_menu: bool = false


func _ready() -> void:
	print("[Global-DEBUG] Health persistence initialized — current_health = ", current_health)
	print("[Feature-DEBUG] Stamina persistence initialized — current_stamina = ", current_stamina)



func clear_pending_bloodstain() -> void:
	has_pending_bloodstain = false
	dropped_souls = 0
	last_death_pos = Vector2.ZERO
	last_death_scene = ""
	locked_death_pos = Vector2.ZERO
	death_scene_path = ""
	death_locked_pos = Vector2.ZERO
	print("[Global-DEBUG] Pending bloodstain state FULLY cleared")
