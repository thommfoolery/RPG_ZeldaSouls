@tool
class_name WeaponStats
extends Resource

# ── Scaling Grade Enum ─────────────────────────────────────────────────
enum ScalingGrade {
	NONE = 0,
	E    = 1,
	D    = 2,
	C    = 3,
	B    = 4,
	A    = 5,
	S    = 6
}

# ── Base Damage (at +0 upgrade) ─────────────────────────────────────
@export var base_physical: float = 100.0
@export var base_magic: float = 0.0
@export var base_fire: float = 0.0
@export var base_lightning: float = 0.0
@export var base_holy: float = 0.0

# ── Scaling Grades ──────────────────────────────────────────────────
@export var str_scaling: ScalingGrade = ScalingGrade.NONE
@export var dex_scaling: ScalingGrade = ScalingGrade.NONE
@export var int_scaling: ScalingGrade = ScalingGrade.NONE
@export var faith_scaling: ScalingGrade = ScalingGrade.NONE

# ── Catalyst / Spell Power (for staves, chimes, seals) ──────────────
@export var spell_scaling_power: float = 0.0   # Used heavily by spells

# ── Future Combat Fields (ready for Phase 2/3) ──────────────────────
@export var weight: float = 5.0
@export var poise_damage: float = 0.0
@export var bleed_buildup: float = 0.0
@export var poison_buildup: float = 0.0
@export var frost_buildup: float = 0.0

# Requirements
@export var required_strength: int = 0
@export var required_dexterity: int = 0
@export var required_intelligence: int = 0
@export var required_faith: int = 0

# ── Helpers ─────────────────────────────────────────────────────────
func get_scaling_display(grade: ScalingGrade) -> String:
	match grade:
		ScalingGrade.S: return "S"
		ScalingGrade.A: return "A"
		ScalingGrade.B: return "B"
		ScalingGrade.C: return "C"
		ScalingGrade.D: return "D"
		ScalingGrade.E: return "E"
		_: return "-"

func get_total_base_damage() -> float:
	return base_physical + base_magic + base_fire + base_lightning + base_holy

# Placeholder — we'll expand this later with real scaling + upgrade level
func get_attack_rating(player_stats, upgrade_level: int = 0) -> float:
	# For now: just returns base total
	# Later: player stats + upgrade_level will modify this
	return get_total_base_damage()

# Debug
func _to_string() -> String:
	return "WeaponStats: Phys=%.1f Mag=%.1f Fire=%.1f | STR:%s DEX:%s INT:%s FTH:%s SpellPower=%.1f" % [
		base_physical, base_magic, base_fire,
		get_scaling_display(str_scaling),
		get_scaling_display(dex_scaling),
		get_scaling_display(int_scaling),
		get_scaling_display(faith_scaling),
		spell_scaling_power
	]
