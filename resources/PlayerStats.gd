# PlayerStats.gd (autoload)
extends Node

var is_initial_load: bool = true

# Basic stats
var level: int = 4
var souls_carried: int = 5000

# Core stats
var vitality: int = 1
var endurance: int = 1
var strength: int = 1
var dexterity: int = 1
var attunement: int = 1          # NEW - will control how many attunement slots you unlock
var intelligence: int = 1
var faith: int = 1
var luck: int = 1

# Attunement system (NEW)
var attunement_slots_unlocked: int = 2          # Start with 2 slots as requested
var attuned_spells: Array[GameItem] = []        # Will hold the actual spells in each slot

# World / Bonfire data
var discovered_bonfires: Dictionary = {}
var last_bonfire: String = ""
var last_rest_bonfire_id: String = ""
var last_rest_bonfire_scene: String = ""
var last_rest_player_pos: Vector2 = Vector2.ZERO

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

# Attunement signals - used by HUD and any future menus
signal attunement_changed()           # Emitted whenever a spell is equipped/unequipped
signal attunement_slots_changed()     # Emitted if you ever change how many slots are unlocked (level-up)


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

	# FIXED: Refill estus on rest
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

	var heal_amount = 40.0
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

	print("[Feature-DEBUG] Estus used → remaining: ", current_estus)
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

	# FIXED: Refill estus on death respawn
	current_estus = max_estus
	estus_charges = max_estus
	estus_changed.emit(current_estus)
	print("[Feature-DEBUG] Estus refilled on death respawn → ", current_estus, "/", max_estus)

# ─── SAVE / LOAD ────────────────────────────────────────────────────

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
		"attuned_spells": attuned_spells.map(func(s): return s.id if s else null)
	}

func from_save_dict(data: Dictionary) -> void:
	level = data.get("level", 1)
	souls_carried = data.get("souls_carried", 0)
	vitality = data.get("vitality", 1)
	endurance = data.get("endurance", 1)
	strength = data.get("strength", 1)
	dexterity = data.get("dexterity", 1)
	attunement = data.get("attunement", 1)
	intelligence = data.get("intelligence", 1)
	faith = data.get("faith", 1)
	luck = data.get("luck", 1)
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

	for i in saved_ids.size():
		if i >= attuned_spells.size():
			break
		var spell_id = saved_ids[i]
		if spell_id == null or spell_id.is_empty():
			attuned_spells[i] = null
			continue

		var path = "res://resources/items/" + spell_id + ".tres"
		var real_spell = load(path) as GameItem
		if real_spell:
			attuned_spells[i] = real_spell.duplicate(true)
			print("[PlayerStats] Restored attuned spell: ", real_spell.display_name, " → slot ", i)
		else:
			push_warning("[PlayerStats] Could not restore attuned spell: " + spell_id)
			attuned_spells[i] = null

	print("[PlayerStats] Restored attunement: ", attunement_slots_unlocked, " slots")
	attunement_changed.emit()  # Refresh HUD + menus

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
