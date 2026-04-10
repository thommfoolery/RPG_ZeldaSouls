# PlayerStats.gd (autoload)
extends Node
const MAX_STAT_LEVEL = 99
const MAX_UPGRADE_LEVEL = 12   # ← NEW for Estus upgrades

var is_initial_load: bool = true

# Basic stats
var level: int = 4
var souls_carried: int = 500000

# Core stats
var vitality: int = 5
var endurance: int = 5
var strength: int = 5
var dexterity: int = 5
var attunement: int = 5
var intelligence: int = 5
var faith: int = 5
var luck: int = 5

# Attunement system
var attunement_slots_unlocked: int = 0
var attuned_spells: Array[GameItem] = []

# World / Bonfire data
var discovered_bonfires: Dictionary = {}
var last_bonfire: String = ""
var last_rest_bonfire_id: String = ""
var last_rest_bonfire_scene: String = ""
var last_rest_player_pos: Vector2 = Vector2.ZERO

# ── ESTUS UPGRADE SYSTEM ─────────────────────────────────────────────
var estus_heal_level: int = 0          # Potency upgrades (heal amount)
var estus_max_charges_level: int = 0   # Capacity upgrades (+1 charge per level)

# Estus
var estus_charges: int = 3
var max_estus: int = 3
var current_estus: int = 3

# Respawn flag
var is_respawning_after_death: bool = false

# ─── Signals ────────────────────────────────────────────────────────
signal health_changed(new: float)
signal max_health_changed(new: float)
signal stamina_changed(new: float)
signal max_stamina_changed(new: float)
signal estus_changed(new: int)
signal souls_changed(new: int)
signal stat_changed(stat: String, new: int)

# Attunement signals
signal attunement_changed()
signal attunement_slots_changed()

func _ready() -> void:
	# Ensure discovered_bonfires is always a Dictionary
	if discovered_bonfires == null or not discovered_bonfires is Dictionary:
		discovered_bonfires = {}
		print("[PlayerStats] Fixed discovered_bonfires to Dictionary on init")

	# Initialize attuned_spells array to match unlocked slots
	attuned_spells.resize(attunement_slots_unlocked)

	# Estus persistence init
	current_estus = estus_charges
	estus_changed.emit(current_estus)
	print("[PlayerStats] Estus initialized → current: ", current_estus, " / max: ", max_estus)
	print("[Feature-DEBUG] PlayerStats ready — estus persisted at ", current_estus)

# ─── ESTUS UPGRADE HELPERS ───────────────────────────────────────────
func get_current_estus_heal_amount() -> float:
	# 100 base → ~350 at level 8 → continues smoothly to level 12
	return 100.0 + (estus_heal_level * 31.25)

func upgrade_estus_capacity() -> bool:
	if estus_max_charges_level >= MAX_UPGRADE_LEVEL: return false
	if not PlayerInventory.has_enough("estus_capacity", 1): return false

	PlayerInventory.consume_item("estus_capacity", 1)
	estus_max_charges_level += 1
	max_estus = 3 + estus_max_charges_level
	current_estus = max_estus

	# Also upgrade the actual equipped Estus item if it exists
	_apply_upgrade_to_equipped_estus()
	estus_changed.emit(current_estus)
	SaveManager.request_save()
	return true

func upgrade_estus_potency() -> bool:
	if estus_heal_level >= MAX_UPGRADE_LEVEL: return false
	if not PlayerInventory.has_enough("estus_potency", 1): return false
	
	PlayerInventory.consume_item("estus_potency", 1)
	estus_heal_level += 1
	
	_apply_upgrade_to_equipped_estus()   # ← This line was already there, keep it
	
	SaveManager.request_save()
	return true


# Helper - finds the Estus in equipment and updates its level
# Helper - updates ALL Estus items in equipment with the current potency level
func _apply_upgrade_to_equipped_estus() -> void:
	var updated = false
	
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and item.id == "estus":
			item.upgrade_level = estus_heal_level
			print("[PlayerStats] Updated Estus potency in slot ", i, " → upgrade_level = ", estus_heal_level)
			EquipmentManager.equipped_changed.emit(i, item)
			updated = true
	
	if not updated:
		print("[PlayerStats] No Estus found in any equipment slot to update")
	
	# Also force a full HUD refresh so quick slot label updates immediately
	var cross_huds = get_tree().get_nodes_in_group("cross_hud")
	for hud in cross_huds:
		if hud.has_method("refresh"):
			hud.refresh()

# ─── Rest / Bonfire ─────────────────────────────────────────────────
func rest_at_bonfire(bonfire_id: String) -> void:
	last_rest_bonfire_id = bonfire_id
	last_rest_bonfire_scene = get_tree().current_scene.scene_file_path

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hc = player.get_node_or_null("HealthComponent")
		var sc = player.get_node_or_null("StaminaComponent")
		if hc:
			hc.current_health = hc.max_health
			hc.health_changed.emit(hc.current_health, hc.max_health)
			health_changed.emit(hc.current_health)
			if Global:
				Global.current_health = hc.current_health
		if sc:
			sc.current_stamina = sc.max_stamina
			sc.stamina_changed.emit(sc.current_stamina, sc.max_stamina)
			stamina_changed.emit(sc.current_stamina)

	# FIXED: Refill estus on rest (now respects upgraded max)
	current_estus = max_estus
	estus_charges = max_estus
	estus_changed.emit(current_estus)
	print("[Feature-DEBUG] Estus refilled on rest → current_estus: ", current_estus, " / max_estus: ", max_estus)
	print("Rest at bonfire:", bonfire_id)

# ─── Estus Use ──────────────────────────────────────────────────────
func use_estus() -> bool:
	if current_estus <= 0:
		print("DEBUG PlayerStats: No estus left")
		return false

	current_estus -= 1
	estus_charges = current_estus
	estus_changed.emit(current_estus)

	var heal_amount = get_current_estus_heal_amount()   # ← now uses upgraded value

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hc = player.get_node_or_null("HealthComponent")
		if hc:
			hc.current_health = min(hc.current_health + heal_amount, hc.max_health)
			hc.health_changed.emit(hc.current_health, hc.max_health)
			health_changed.emit(hc.current_health)
			if Global:
				Global.current_health = hc.current_health
			print("[Feature-DEBUG] Estus heal synced to Global.current_health → ", Global.current_health)

	print("[Feature-DEBUG] Estus used → remaining: ", current_estus, " | heal amount: ", heal_amount)
	return true

# ─── Full heal / stamina ────────────────────────────────────────────
func full_heal() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hc = player.get_node_or_null("HealthComponent")
		if hc:
			hc.current_health = hc.max_health
			hc.health_changed.emit(hc.current_health, hc.max_health)
			health_changed.emit(hc.current_health)
			print("DEBUG: Full heal applied via component")

func full_stamina() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var sc = player.get_node_or_null("StaminaComponent")
		if sc:
			sc.current_stamina = sc.max_stamina
			sc.stamina_changed.emit(sc.current_stamina, sc.max_stamina)
			stamina_changed.emit(sc.current_stamina)
			print("DEBUG: Full stamina restored via component")

# ─── Souls ──────────────────────────────────────────────────────────
func add_souls(amount: int) -> void:
	souls_carried += amount
	souls_changed.emit(souls_carried)
	print("DEBUG: Added ", amount, " souls — total: ", souls_carried)

# ─── Stat cost ──────────────────────────────────────────────────────
func get_stat_cost(sl: int) -> int:
	if sl < 4: return 0
	return int(0.02 * sl * sl + 3.0 * sl + 105.0)

# ─── Optional fallback take_damage ──────────────────────────────────
func take_damage(amount: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hc = player.get_node_or_null("HealthComponent")
		if hc:
			hc.take_damage(amount)
			return
	print("[PlayerStats] take_damage fallback - no HealthComponent found. Damage ignored: ", amount)

# ─── Respawn ────────────────────────────────────────────────────────
func respawn_full_heal() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hc = player.get_node_or_null("HealthComponent")
		if hc:
			hc.current_health = hc.max_health
			hc.is_invincible = false
			hc.health_changed.emit(hc.current_health, hc.max_health)
			print("[PlayerStats] Respawn full heal applied")

	# FIXED: Refill estus on death respawn (now respects upgraded max)
	current_estus = max_estus
	estus_charges = max_estus
	estus_changed.emit(current_estus)
	print("[Feature-DEBUG] Estus refilled on death respawn → ", current_estus, "/", max_estus)

# ─── SAVE / LOAD ────────────────────────────────────────────────────
func to_save_dict() -> Dictionary:
	return {
		"level": level,
		"souls_carried": souls_carried,
		"vitality": vitality,
		"endurance": endurance,
		"strength": strength,
		"dexterity": dexterity,
		"attunement": attunement,
		"intelligence": intelligence,
		"faith": faith,
		"luck": luck,
		"discovered_bonfires": discovered_bonfires,
		"current_estus": current_estus,
		# Attunement persistence
		"attunement_slots_unlocked": attunement_slots_unlocked,
		"attuned_spells": attuned_spells.map(func(s): return s.id if s else null),
		# NEW Estus upgrade persistence
		"estus_heal_level": estus_heal_level,
		"estus_max_charges_level": estus_max_charges_level
	}

func from_save_dict(data: Dictionary) -> void:
	level = data.get("level", 4)
	souls_carried = data.get("souls_carried", 0)
	vitality = data.get("vitality", 5)
	endurance = data.get("endurance", 5)
	strength = data.get("strength", 5)
	dexterity = data.get("dexterity", 5)
	attunement = data.get("attunement", 5)
	intelligence = data.get("intelligence", 5)
	faith = data.get("faith", 5)
	luck = data.get("luck", 5)
	discovered_bonfires = data.get("discovered_bonfires", {})
	current_estus = data.get("current_estus", max_estus)
	estus_charges = current_estus
	estus_changed.emit(current_estus)
	souls_changed.emit(souls_carried)

	# ── Attunement restore ─────────────────────────────────────
	attunement_slots_unlocked = data.get("attunement_slots_unlocked", 2)
	var saved_ids = data.get("attuned_spells", [])
	attuned_spells.clear()
	attuned_spells.resize(attunement_slots_unlocked)
	for i in range(saved_ids.size()):
		if i >= attuned_spells.size(): break
		var spell_id = saved_ids[i]
		if spell_id == null or spell_id.is_empty():
			attuned_spells[i] = null
			continue
		var path = "res://resources/items/" + spell_id + ".tres"
		var real_spell = load(path) as GameItem
		if real_spell:
			attuned_spells[i] = real_spell.duplicate(true)
		else:
			push_warning("[PlayerStats] Could not restore attuned spell: " + spell_id)
			attuned_spells[i] = null

	# NEW: Load Estus upgrades
	estus_heal_level = data.get("estus_heal_level", 0)
	estus_max_charges_level = data.get("estus_max_charges_level", 0)
	max_estus = 3 + estus_max_charges_level

	# IMPORTANT: Re-calculate unlocked slots based on current Attunement stat
	update_attunement_slots()
	print("[PlayerStats] Restored attunement: ", attunement_slots_unlocked, " slots unlocked")
	attunement_changed.emit()

# ─── Stat changed signal helper (optional) ──────────────────────────
func update_stat(stat_name: String, new_value: int) -> void:
	match stat_name:
		"vitality": vitality = new_value
		"endurance": endurance = new_value
		"strength": strength = new_value
		"dexterity": dexterity = new_value
		"attunement": attunement = new_value
		"intelligence": intelligence = new_value
		"faith": faith = new_value
		"luck": luck = new_value
	stat_changed.emit(stat_name, new_value)

func update_attunement_slots() -> void:
	var new_slots = StatCalculator.get_attunement_slots(attunement)
	if new_slots != attunement_slots_unlocked:
		attunement_slots_unlocked = new_slots
		# Resize attuned_spells array safely
		attuned_spells.resize(attunement_slots_unlocked)
		attunement_slots_changed.emit()
		attunement_changed.emit()
		print("[PlayerStats] Attunement slots updated to ", attunement_slots_unlocked)
