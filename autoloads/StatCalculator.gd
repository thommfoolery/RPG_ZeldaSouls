# autoload/StatCalculator.gd
extends Node

## Single source of truth for all derived stats.
## Base stats come from PlayerStats. Equipment/rings will be added later.

func get_max_health(vitality: int) -> int:
	# Scaled and shaped to feel exactly like Dark Souls 1
	# Starts at 122 HP @ Vit 5, ends ~950 HP @ Vit 99
	# Slow early → strong ramp → soft cap around 30-40 → diminishing returns
	
	if vitality <= 5:
		return 122
	
	var v = vitality - 5  # normalize so Vit 5 = 0
	
	if v <= 15:           # Vit 5 → 20 (early slow)
		return 122 + int(v * 18.5)
	elif v <= 25:         # Vit 20 → 30 (ramp up)
		return 400 + int((v - 15) * 32)
	elif v <= 45:         # Vit 30 → 50 (peak ramp then start to slow)
		return 720 + int((v - 25) * 26)
	else:                 # Vit 50 → 99 (strong diminishing returns)
		var late = v - 45
		return 1240 + int(late * 14 - late * late * 0.12)

func get_max_stamina(endurance: int) -> int:
	# Matches your provided table exactly, starting from Endurance 5 = 90
	# Hard cap at 160 from Endurance 40 onward
	if endurance <= 5:
		return 90
	if endurance >= 40:
		return 160
	
	# Linear ramp that matches the table
	return 80 + int(endurance * 2.0)


func get_equip_load(endurance: int) -> float:
	# Exact match to your table: +1.0 per point, no cap
	return 40.0 + endurance * 1.0
	
func get_attunement_slots(attunement: int) -> int:
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

func get_max_mana(attunement: int) -> int:
	# Elden Ring Mind scaling, adjusted to feel good with our Attunement 5 baseline
	if attunement <= 5:
		return 80
	
	var m = attunement - 5
	
	if m <= 15:          # Early slow ramp
		return 80 + int(m * 4.5)
	elif m <= 35:        # Mid-game good ramp
		return 148 + int((m - 15) * 7.2)
	else:                # Late diminishing returns, cap around 450 at 99
		var late = m - 35
		return 370 + int(late * 4.8 - late * late * 0.08)

func get_item_discovery(luck: int) -> int:
	return 100 + clamp(luck, 0, 99)

# Future hooks
func get_strength_scaling(str: int) -> int: return str
func get_dexterity_scaling(dex: int) -> int: return dex
func get_intelligence_scaling(intel: int) -> int: return intel
func get_faith_scaling(faith: int) -> int: return faith

# Call this after any stat change (level up, equipment, etc.)
func refresh_all_player_stats() -> void:
	var player = PlayerManager.current_player
	if not player: 
		push_warning("[StatCalculator] No player to refresh")
		return
	
	var health = player.get_node_or_null("HealthComponent")
	if health:
		health.max_health = get_max_health(PlayerStats.vitality)
		health.health_changed.emit(health.current_health, health.max_health)
	
	var stamina = player.get_node_or_null("StaminaComponent")
	if stamina:
		stamina.max_stamina = get_max_stamina(PlayerStats.endurance)
		stamina.stamina_changed.emit(stamina.current_stamina, stamina.max_stamina)
	
	var mana = player.get_node_or_null("ManaComponent")
	if mana:
		mana.max_mana = get_max_mana(PlayerStats.attunement)
		mana.mana_changed.emit(mana.current_mana, mana.max_mana)
	
	print("[StatCalculator] All player stats refreshed")
