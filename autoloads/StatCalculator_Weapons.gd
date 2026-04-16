# autoload/StatCalculator_Weapons.gd
extends Node

const SCALING_STRENGTH = 3.5                    # ← was 7.0 → doubled
const ELEMENTAL_SCALING_FACTOR = 3.5

# Same shape as before, tuned to your scaling values (52/79/100/120)
func _get_efficiency(scaling_value: float) -> float:
	if scaling_value <= 52:                               # raw ~20 → good
		return scaling_value * 0.02115                    # → 1.10 at 52
	
	elif scaling_value <= 79:                             # raw 20–40 → great
		return 1.10 + (scaling_value - 52) * 0.03333      # → 2.00 at 79
	
	elif scaling_value <= 100:                            # raw 40–60 → back to good
		return 2.00 + (scaling_value - 79) * 0.02381      # → 2.50 at 100
	
	elif scaling_value <= 120:                            # raw 60–80 → less than good
		return 2.50 + (scaling_value - 100) * 0.015       # → 2.80 at 120
	
	else:                                                 # 80+ → very slow tail
		return 2.80 + (scaling_value - 120) * 0.008


func get_attack_rating(weapon: GameItem, upgrade_level: int = 0) -> float:
	if not weapon or not weapon.weapon_stats:
		return 0.0
	
	var ws = weapon.weapon_stats
	var total = 0.0
	
	var phys_bonus = _get_scaling_bonus(ws.base_physical, ws.str_scaling, "strength") \
				   + _get_scaling_bonus(ws.base_physical, ws.dex_scaling, "dexterity")
	total += ws.base_physical + phys_bonus
	
	var magic_bonus = _get_scaling_bonus(ws.base_magic, ws.int_scaling, "intelligence") * ELEMENTAL_SCALING_FACTOR
	total += ws.base_magic + magic_bonus
	
	var fire_bonus = _get_scaling_bonus(ws.base_fire, ws.faith_scaling, "faith") * ELEMENTAL_SCALING_FACTOR
	total += ws.base_fire + fire_bonus
	
	var lightning_bonus = _get_scaling_bonus(ws.base_lightning, ws.int_scaling, "intelligence") * ELEMENTAL_SCALING_FACTOR
	total += ws.base_lightning + lightning_bonus
	
	var holy_bonus = _get_scaling_bonus(ws.base_holy, ws.faith_scaling, "faith") * ELEMENTAL_SCALING_FACTOR
	total += ws.base_holy + holy_bonus
	
	return round(total)


func _get_scaling_bonus(base: float, grade: WeaponStats.ScalingGrade, stat_name: String) -> float:
	if grade == WeaponStats.ScalingGrade.NONE:
		return 0.0
	
	var player_scaling = 0.0
	match stat_name:
		"strength":      player_scaling = StatCalculator.get_strength_scaling()
		"dexterity":     player_scaling = StatCalculator.get_dexterity_scaling()
		"intelligence":  player_scaling = StatCalculator.get_intelligence_scaling()
		"faith":         player_scaling = StatCalculator.get_faith_scaling()
	
	var efficiency = _get_efficiency(player_scaling)
	
	var grade_multiplier = 0.0
	match grade:
		WeaponStats.ScalingGrade.S: grade_multiplier = 1.60   # slightly higher for more drama
		WeaponStats.ScalingGrade.A: grade_multiplier = 1.30
		WeaponStats.ScalingGrade.B: grade_multiplier = 1.00
		WeaponStats.ScalingGrade.C: grade_multiplier = 0.70
		WeaponStats.ScalingGrade.D: grade_multiplier = 0.40
		WeaponStats.ScalingGrade.E: grade_multiplier = 0.20
	
	return base * efficiency * grade_multiplier * (SCALING_STRENGTH / 10.0)
