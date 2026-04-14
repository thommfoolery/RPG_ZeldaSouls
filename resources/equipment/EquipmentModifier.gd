# res://resources/equipment/EquipmentModifier.gd
@tool
extends Resource
class_name EquipmentModifier

# ── Display & Categorization ──
@export var display_name: String = ""          # For tooltips and debug (e.g. "Ring of Vitality")
@export var icon: Texture2D = null             # Icon shown in BuffHUD
@export var color: Color = Color.WHITE         # Tint for the icon

# ── What kind of modifier is this? ──
@export_enum("Flat_Stat", "Flat_Attunement_Slots", "Flat_Levels", "Over_Time", "Set_Bonus", "Special") var modifier_type: String = "Flat_Stat"

# ── Core Stat Modification ──
@export var stat_type: String = ""             # "max_health", "mana_regen_rate", "hp_regen_rate", etc.
@export var flat_value: float = 0.0            # +30 max health, +6 HP/s, etc.

# ── NEW: Flat Level Bonus (e.g. +10 VIT, +5 Attunement) ──
@export var stat_bonus: String = ""            # "vitality", "endurance", "attunement", "strength", etc.
@export var flat_levels: int = 0               # +10 levels of that stat (does NOT affect level-up cost)

# ── Multiplier support (future) ──
@export var multiplier: float = 1.0            # For % based buffs later (1.15 = +15%)

# ── Over-time effects (permanent regen) ──
@export var is_over_time: bool = false
@export var tick_rate: float = 0.0
@export var tick_value: float = 0.0

# ── Set Bonus Support ──
@export var required_set_pieces: int = 0
@export var set_bonus_description: String = ""

# ── Special / Unique effects (rare) ──
@export var custom_script: Script = null

func _to_string() -> String:
	if flat_levels != 0 and not stat_bonus.is_empty():
		return "%s | +%d %s levels" % [display_name, flat_levels, stat_bonus]
	else:
		return "%s | %s %s" % [display_name, flat_value, stat_type]
