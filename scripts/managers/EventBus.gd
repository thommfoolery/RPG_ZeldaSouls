# autoload/EventBus.gd
extends Node

# ─── CORE / ACTIVE SIGNALS ──────────────────────────────────────────
signal player_died(death_position: Vector2, dropped_souls: int)
signal bloodstain_collected(souls: int)

# ─── PLANNED / FUTURE SIGNALS ───────────────────────────────────────
# (commented = not yet emitted anywhere, but signature is reserved)
# signal bloodstain_spawned(position: Vector2, souls: int)           # Planned: VFX, sound, minimap flash, etc.
signal bonfire_lit(bonfire_id: String, first_time: bool)           # Planned: TitleCard + lighting FX
signal player_rest_completed(bonfire_id: String)                   # Planned: enemy respawn trigger, save point
signal enemy_killed(enemy_id: String, scene_path: String)          # Planned: souls reward, loot table, achievements
signal stat_leveled_up(stat: String, new_value: int)               # Planned: HUD flash, stat-up SFX
signal estus_used(remaining: int)                                  # Planned: flask animation sync

# ─── DEBUG HELPER ───────────────────────────────────────────────────
func _ready() -> void:
	print("[EventBus] ONLINE — ", get_signal_list().size(), " signals registered")
	# Optional: auto-print every emission during dev (comment out before ship)
	# for sig in get_signal_list():
	#     connect(sig.name, _debug_log_event.bind(sig.name))

func _debug_log_event(arg1 = null, arg2 = null, arg3 = null, event_name: String = "") -> void:
	var msg = "[EVENT] " + event_name
	if arg1 != null: msg += " | " + str(arg1)
	if arg2 != null: msg += " | " + str(arg2)
	if arg3 != null: msg += " | " + str(arg3)
	print(msg)
