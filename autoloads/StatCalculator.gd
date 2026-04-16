# autoload/StatCalculator.gd
extends Node
## Main public interface for all stat calculations.
## This is the only file other scripts should call.

var core = preload("res://autoloads/StatCalculator_Core.gd").new()
var weapons = preload("res://autoloads/StatCalculator_Weapons.gd").new()

# ── Modifiers ──
func add_modifier(mod: EquipmentModifier) -> void:
	core.add_modifier(mod)

func remove_modifier(mod: EquipmentModifier) -> void:
	core.remove_modifier(mod)

func clear_all_modifiers() -> void:
	core.clear_all_modifiers()

# ── Effective Stat ──
func get_effective_stat(stat_name: String) -> int:
	return core.get_effective_stat(stat_name)

# ── Core Stats ──
func get_max_health(vitality: int = -1) -> int:
	return core.get_max_health(vitality)

func get_max_mana(attunement: int = -1) -> int:
	return core.get_max_mana(attunement)

func get_max_stamina(endurance: int = -1) -> int:
	return core.get_max_stamina(endurance)

func get_mana_regen_rate() -> float:
	return core.get_mana_regen_rate()

func get_stamina_regen_rate() -> float:
	return core.get_stamina_regen_rate()

func get_hp_regen_rate() -> float:
	return core.get_hp_regen_rate()

func get_equip_load(endurance: int = -1) -> float:
	return core.get_equip_load(endurance)

func get_attunement_slots(attunement: int = -1) -> int:
	return core.get_attunement_slots(attunement)

func get_item_discovery() -> int:
	return core.get_item_discovery()

# ── Base-Only for LevelUpMenu ──
func get_max_health_base_only(vitality: int) -> int:
	return core.get_max_health_base_only(vitality)

func get_max_mana_base_only(attunement: int) -> int:
	return core.get_max_mana_base_only(attunement)

func get_max_stamina_base_only(endurance: int) -> int:
	return core.get_max_stamina_base_only(endurance)

func get_equip_load_base_only(endurance: int = -1) -> float:
	return core.get_equip_load_base_only(endurance)

func get_attunement_slots_base_only(attunement: int) -> int:
	return core.get_attunement_slots_base_only(attunement)

# ── Attunement Special ──
func get_flat_attunement_slot_bonus() -> int:
	return core.get_flat_attunement_slot_bonus()

# ── Internal Core Helpers (if any are called directly) ──
func get_max_health_base(vitality: int) -> int:
	return core.get_max_health_base(vitality)

func get_max_mana_base(attunement: int) -> int:
	return core.get_max_mana_base(attunement)

func get_max_stamina_base(endurance: int) -> int:
	return core.get_max_stamina_base(endurance)

func get_equip_load_base(endurance: int) -> int:
	return core.get_equip_load_base(endurance)

func _get_defense_base() -> float:
	return core._get_defense_base()

func _calculate_scaling(eff: int) -> int:
	return core._calculate_scaling(eff)

# ── Offensive Scaling ──
func get_strength_scaling() -> int:
	return core.get_strength_scaling()

func get_dexterity_scaling() -> int:
	return core.get_dexterity_scaling()

func get_intelligence_scaling() -> int:
	return core.get_intelligence_scaling()

func get_faith_scaling() -> int:
	return core.get_faith_scaling()

func get_strength_scaling_base_only(str: int) -> int:
	return core.get_strength_scaling_base_only(str)

func get_dexterity_scaling_base_only(dex: int) -> int:
	return core.get_dexterity_scaling_base_only(dex)

func get_intelligence_scaling_base_only(intel: int) -> int:
	return core.get_intelligence_scaling_base_only(intel)

func get_faith_scaling_base_only(faith: int) -> int:
	return core.get_faith_scaling_base_only(faith)

# ── Defensive Stats ──
func get_physical_defense() -> float:
	return core.get_physical_defense()

func get_magic_defense() -> float:
	return core.get_magic_defense()

func get_fire_defense() -> float:
	return core.get_fire_defense()

func get_lightning_defense() -> float:
	return core.get_lightning_defense()

func get_holy_defense() -> float:
	return core.get_holy_defense()

func get_status_resistance() -> float:
	return core.get_status_resistance()

func get_poise() -> float:
	return core.get_poise()

# ── Defensive Base-Only ──
func get_physical_defense_base_only() -> float:
	return core.get_physical_defense_base_only()

func get_magic_defense_base_only() -> float:
	return core.get_magic_defense_base_only()

func get_fire_defense_base_only() -> float:
	return core.get_fire_defense_base_only()

func get_lightning_defense_base_only() -> float:
	return core.get_lightning_defense_base_only()

func get_holy_defense_base_only() -> float:
	return core.get_holy_defense_base_only()

func get_status_resistance_base_only() -> float:
	return core.get_status_resistance_base_only()

func get_poise_base_only() -> float:
	return core.get_poise_base_only()

# ── Armor Totals ──
func get_total_armor_physical_defense() -> float:
	return core.get_total_armor_physical_defense()

func get_total_armor_magic_defense() -> float:
	return core.get_total_armor_magic_defense()

func get_total_armor_fire_defense() -> float:
	return core.get_total_armor_fire_defense()

func get_total_armor_lightning_defense() -> float:
	return core.get_total_armor_lightning_defense()

func get_total_armor_holy_defense() -> float:
	return core.get_total_armor_holy_defense()

func get_total_armor_status_resistance() -> float:
	return core.get_total_armor_status_resistance()

func get_total_armor_poise() -> float:
	return core.get_total_armor_poise()

# ── Refresh & Control ──
func refresh_all_player_stats() -> void:
	core.refresh_all_player_stats()

func set_refresh_enabled(enabled: bool) -> void:
	core.set_refresh_enabled(enabled)

# ── Weapon functions will be added here later ──
# Weapon calculations
func get_attack_rating(weapon: GameItem, upgrade_level: int = 0) -> float:
	return weapons.get_attack_rating(weapon, upgrade_level)
