# autoload/StatCalculator_Core.gd
extends Node

## Single source of truth for all derived and modified stats.
## Base stats come from PlayerStats. Permanent equipment modifiers are added here.

var _active_modifiers: Array[EquipmentModifier] = []
var _refresh_enabled: bool = true

func add_modifier(mod: EquipmentModifier) -> void:
	if mod:
		_active_modifiers.append(mod)
		refresh_all_player_stats()

func remove_modifier(mod: EquipmentModifier) -> void:
	if mod:
		_active_modifiers.erase(mod)
		refresh_all_player_stats()

func clear_all_modifiers() -> void:
	_active_modifiers.clear()
	refresh_all_player_stats()

# ── Effective Stat (Base + Flat Level Bonuses from rings) ──
func get_effective_stat(stat_name: String) -> int:
	var base := PlayerStats.get(stat_name) as int
	var bonus_levels := 0
	for mod in _active_modifiers:
		if mod.stat_bonus == stat_name and mod.modifier_type == "Flat_Levels":
			bonus_levels += mod.flat_levels
	var effective = base + bonus_levels
	return effective

# ── Final Computed Stats (with equipment modifiers) ──
func get_max_health(vitality: int = -1) -> int:
	var effective_vit = get_effective_stat("vitality")
	var base = get_max_health_base(effective_vit)
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "max_health":
			bonus += mod.flat_value
	return int(base + bonus)

func get_max_mana(attunement: int = -1) -> int:
	var effective_att = get_effective_stat("attunement")
	var base = get_max_mana_base(effective_att)
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "max_mana":
			bonus += mod.flat_value
	return int(base + bonus)

# ── All derived stats now use effective level (Flat_Levels rings work) ──
func get_max_stamina(endurance: int = -1) -> int:
	var eff = get_effective_stat("endurance")
	var base = get_max_stamina_base(eff)
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "max_stamina":
			bonus += mod.flat_value
	return int(base + bonus)

func get_mana_regen_rate() -> float:
	var base := 0.0
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "mana_regen_rate":
			bonus += mod.flat_value
	return base + bonus

func get_stamina_regen_rate() -> float:
	var base := 30.0                     # ← matches your StaminaComponent default
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "stamina_regen_rate":
			bonus += mod.flat_value
	return base + bonus

func get_hp_regen_rate() -> float:
	var base := 0.0
	var bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "hp_regen_rate":
			bonus += mod.flat_value
	return base + bonus

# ── Base calculations (unchanged) ──
# ── Pure Base Calculations (for LevelUpMenu preview - no equipment modifiers) ──
func get_max_health_base_only(vitality: int) -> int:
	return get_max_health_base(vitality)

func get_max_mana_base_only(attunement: int) -> int:
	return get_max_mana_base(attunement)

func get_max_stamina_base_only(endurance: int) -> int:
	return get_max_stamina_base(endurance)


func get_max_health_base(vitality: int) -> int:
	if vitality <= 5: return 122
	var v = vitality - 5
	if v <= 15: return 122 + int(v * 18.5)
	elif v <= 25: return 400 + int((v - 15) * 32)
	elif v <= 45: return 720 + int((v - 25) * 26)
	else:
		var late = v - 45
		return 1240 + int(late * 14 - late * late * 0.12)

func get_max_mana_base(attunement: int) -> int:
	if attunement <= 5:
		return 80
	
	var m = attunement - 5
	
	if m <= 15:                    # Early game (Att 6 → 20)
		return 80 + int(m * 4.5)
	elif m <= 35:                  # Mid game (Att 21 → 40)
		return 148 + int((m - 15) * 7.2)
	else:                          # Late game (Att 41 → 99) - positive slow scaling
		var late = m - 35
		# Positive scaling with very soft diminishing returns
		return 370 + int(late * 5.2 - late * late * 0.035)

func get_equip_load_base_only(endurance: int = -1) -> float:
	if endurance == -1:
		endurance = PlayerStats.endurance
	return 40.0 + endurance * 1.0

func get_attunement_slots_base_only(attunement: int) -> int:
	if attunement < 10: return 0
	if attunement <= 11: return 1
	if attunement <= 13: return 2
	if attunement <= 15: return 3
	if attunement <= 18: return 4
	if attunement <= 22: return 5
	if attunement <= 27: return 6
	if attunement <= 33: return 7
	if attunement <= 40: return 8
	if attunement <= 49: return 9
	return 10

# Base stamina scaling 
func get_max_stamina_base(endurance: int) -> int:
	if endurance <= 5:
		return 90
	if endurance >= 40:
		return 160
	# Linear ramp (Endurance 6 → 39)
	return 90 + int((endurance - 5) * 2.0)

func get_attunement_slots(attunement: int = -1) -> int:
	var eff = get_effective_stat("attunement")
	
	var base_slots := 0
	if eff < 10: base_slots = 0
	elif eff <= 11: base_slots = 1
	elif eff <= 13: base_slots = 2
	elif eff <= 15: base_slots = 3
	elif eff <= 18: base_slots = 4
	elif eff <= 22: base_slots = 5
	elif eff <= 27: base_slots = 6
	elif eff <= 33: base_slots = 7
	elif eff <= 40: base_slots = 8
	elif eff <= 49: base_slots = 9
	else: base_slots = 10
	
	var flat_bonus = get_flat_attunement_slot_bonus()
	var total = base_slots + flat_bonus
	
	return total

# ── Direct flat attunement slots (for pure "+2 Spell Slots" rings) ──
# Does NOT affect max mana or effective attunement level
func get_flat_attunement_slot_bonus() -> int:
	var bonus := 0
	for mod in _active_modifiers:
		if mod.modifier_type == "Flat_Attunement_Slots":
			bonus += int(mod.flat_value)  # use flat_value for this type
	return bonus

func get_equip_load(endurance: int = -1) -> float:
	var eff = get_effective_stat("endurance")
	var base = 40.0 + eff * 1.0
	var ring_bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "equip_load":
			ring_bonus += mod.flat_value
	return base + ring_bonus

func get_equip_load_base(endurance: int) -> int:
	return 40 + endurance * 1.0   # your original, kept pure

##
# ── Uniform Offensive Scaling (STR, DEX, INT, FTH) ──
# Same structure for all four stats. Easy to tune.

# ── Uniform Offensive Scaling with Equipment Modifier Support ──
func get_strength_scaling() -> int:
	var base = _calculate_scaling(get_effective_stat("strength"))
	var bonus := 0
	for mod in _active_modifiers:
		if mod.stat_type == "strength_scaling":
			bonus += int(mod.flat_value)
	return base + bonus

func get_dexterity_scaling() -> int:
	var base = _calculate_scaling(get_effective_stat("dexterity"))
	var bonus := 0
	for mod in _active_modifiers:
		if mod.stat_type == "dexterity_scaling":
			bonus += int(mod.flat_value)
	return base + bonus

func get_intelligence_scaling() -> int:
	var base = _calculate_scaling(get_effective_stat("intelligence"))
	var bonus := 0
	for mod in _active_modifiers:
		if mod.stat_type == "intelligence_scaling":
			bonus += int(mod.flat_value)
	return base + bonus

func get_faith_scaling() -> int:
	var base = _calculate_scaling(get_effective_stat("faith"))
	var bonus := 0
	for mod in _active_modifiers:
		if mod.stat_type == "faith_scaling":
			bonus += int(mod.flat_value)
	return base + bonus

# Internal uniform ramp function
func _calculate_scaling(eff: int) -> int:
	if eff <= 20:
		return 8 + eff * 2.2          # Fast early game
	elif eff <= 50:
		return 52 + (eff - 20) * 1.35 # Good mid game
	elif eff <= 80:
		return 93 + (eff - 50) * 0.78 # Slow late game
	else:
		return 116 + (eff - 80) * 0.32 # Very slow after 80
		
func get_strength_scaling_base_only(str: int) -> int:
	return _calculate_scaling(str)

func get_dexterity_scaling_base_only(dex: int) -> int:
	return _calculate_scaling(dex)

func get_intelligence_scaling_base_only(intel: int) -> int:
	return _calculate_scaling(intel)

func get_faith_scaling_base_only(faith: int) -> int:
	return _calculate_scaling(faith)

func _get_defense_base() -> float:
	var total_levels = PlayerStats.level - 5
	return 20.0 + total_levels * 0.8

func get_item_discovery() -> int:
	var effective_luck = get_effective_stat("luck")
	var bonus := 0
	for mod in _active_modifiers:
		if mod.stat_type == "item_discovery":
			bonus += int(mod.flat_value)
	return 100 + effective_luck + bonus

# Final values (used for actual damage calculation)
func get_physical_defense() -> float:
	return _get_defense_base() + (get_effective_stat("endurance") - 5) * 1.5 + get_total_armor_physical_defense()

func get_magic_defense() -> float:
	return _get_defense_base() + (get_effective_stat("intelligence") - 5) * 1.5 + get_total_armor_magic_defense()

func get_fire_defense() -> float:
	return _get_defense_base() + get_total_armor_fire_defense()

func get_lightning_defense() -> float:
	return _get_defense_base() + get_total_armor_lightning_defense()

func get_holy_defense() -> float:
	return _get_defense_base() + (get_effective_stat("faith") - 5) * 1.5 + get_total_armor_holy_defense()

func get_status_resistance() -> float:
	return _get_defense_base() + (get_effective_stat("luck") - 5) * 1.5 + get_total_armor_status_resistance()

# Poise is purely from armor — no level-based growth
# Poise — supports both armor AND rings (via EquipmentModifier)
func get_poise() -> float:
	var armor_poise = get_total_armor_poise()
	var ring_bonus := 0.0
	for mod in _active_modifiers:
		if mod.stat_type == "poise":
			ring_bonus += mod.flat_value   # ← This line was likely the issue
	return armor_poise + ring_bonus

# Base-only versions for Level Up Menu preview (no armor)
func get_physical_defense_base_only() -> float:
	return _get_defense_base() + (get_effective_stat("endurance") - 5) * 1.5

func get_magic_defense_base_only() -> float:
	return _get_defense_base() + (get_effective_stat("intelligence") - 5) * 1.5

func get_fire_defense_base_only() -> float:
	return _get_defense_base()

func get_lightning_defense_base_only() -> float:
	return _get_defense_base()

func get_holy_defense_base_only() -> float:
	return _get_defense_base() + (get_effective_stat("faith") - 5) * 1.5

func get_status_resistance_base_only() -> float:
	return _get_defense_base() + (get_effective_stat("luck") - 5) * 1.5

func get_poise_base_only() -> float:
	return 0.0  # kept for LevelUpMenu compatibility (preview shows 0)

# Sum armor contributions
func get_total_armor_physical_defense() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.physical_defense
	return total

func get_total_armor_magic_defense() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.magic_defense
	return total

func get_total_armor_fire_defense() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.fire_defense
	return total

func get_total_armor_lightning_defense() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.lightning_defense
	return total

func get_total_armor_holy_defense() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.holy_defense
	return total

func get_total_armor_status_resistance() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.status_resistance
	return total

func get_total_armor_poise() -> float:
	var total := 0.0
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.armor_stats:
			total += item.armor_stats.poise
	return total

func refresh_all_player_stats() -> void:
	if not _refresh_enabled:
		return
	
	var player = PlayerManager.current_player
	if not player or not is_instance_valid(player):
		return
	
	
	# Health
	var health = player.get_node_or_null("HealthComponent")
	if health:
		var old = health.max_health
		health.max_health = get_max_health()
		health.hp_regen_rate = get_hp_regen_rate()
		health.health_changed.emit(health.current_health, health.max_health)
		health.call_deferred("_update_dynamic_bar")
	
	# Mana
	var mana = player.get_node_or_null("ManaComponent")
	if mana:
		var old = mana.max_mana
		mana.max_mana = get_max_mana()
		mana.mana_regen_rate = get_mana_regen_rate()
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)
		mana.call_deferred("_update_dynamic_bar")
	
	# Stamina
	var stamina = player.get_node_or_null("StaminaComponent")
	if stamina:
		var old = stamina.max_stamina
		stamina.max_stamina = get_max_stamina()
		stamina.regen_rate = get_stamina_regen_rate()
		stamina.stamina_changed.emit(stamina.current_stamina, stamina.max_stamina)
		stamina.call_deferred("_update_dynamic_bar")
	
	# Attunement slots
	PlayerStats.update_attunement_slots()

# Called by Orchestrator to safely enable/disable refreshes during player instantiation
func set_refresh_enabled(enabled: bool) -> void:
	_refresh_enabled = enabled
	if not enabled:
		print("[StatCalculator-DEBUG] All stat refreshes DISABLED during player load")
	else:
		print("[StatCalculator-DEBUG] Stat refreshes ENABLED")
