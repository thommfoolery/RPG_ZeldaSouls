# ui/menus/LevelUpMenu.gd
extends Control

signal menu_closed

# Left side base stats
@onready var souls_label: Label = %SoulsLabel
@onready var total_queued_cost_label: Label = %TotalQueuedCostLabel
@onready var total_level_label: Label = %TotalLevelLabel

@onready var vit_current: Label = %VitalityCurrent
@onready var vit_preview: Label = %VitalityPreview
@onready var end_current: Label = %EnduranceCurrent
@onready var end_preview: Label = %EndurancePreview
@onready var str_current: Label = %StrengthCurrent
@onready var str_preview: Label = %StrengthPreview
@onready var dex_current: Label = %DexterityCurrent
@onready var dex_preview: Label = %DexterityPreview
@onready var att_current: Label = %AttunementCurrent
@onready var att_preview: Label = %AttunementPreview
@onready var faith_current: Label = %FaithCurrent
@onready var faith_preview: Label = %FaithPreview
@onready var int_current: Label = %IntelligenceCurrent
@onready var int_preview: Label = %IntelligencePreview
@onready var luck_current: Label = %LuckCurrent
@onready var luck_preview: Label = %LuckPreview

# Right side Preview Panel
@onready var preview_title: Label = %PreviewTitle
@onready var preview_stats: RichTextLabel = %PreviewStats
@onready var confirm_button: Button = %ConfirmButton
@onready var exit_button: Button = %ExitButton
# Even more Right 
@onready var preview_attack_stats: RichTextLabel = %PreviewAttackStats

var queued_levels: Dictionary = {
	"vitality": 0, "endurance": 0, "strength": 0, "dexterity": 0,
	"attunement": 0, "faith": 0, "intelligence": 0, "luck": 0
}

var selected_stat_index: int = 0
const STAT_NAMES = ["vitality", "endurance", "strength", "dexterity", "attunement", "faith", "intelligence", "luck"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_button.pressed.connect(_on_confirm_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	preview_title.text = "Stat Preview"
	print("[LevelUpMenu] Polished — intelligent gold highlighting on affected lines")
	_refresh_all_display()


func _input(event: InputEvent) -> void:
	if not visible: return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("cycle_item_up"):
		selected_stat_index = wrapi(selected_stat_index - 1, 0, STAT_NAMES.size())
		_refresh_all_display()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down") or event.is_action_pressed("cycle_item_down"):
		selected_stat_index = wrapi(selected_stat_index + 1, 0, STAT_NAMES.size())
		_refresh_all_display()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_left") or event.is_action_pressed("cycle_left_hand"):
		_adjust_queued(-1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_right") or event.is_action_pressed("cycle_right_hand"):
		_adjust_queued(1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()


func _adjust_queued(delta: int) -> void:
	if delta > 0:
		var stat = STAT_NAMES[selected_stat_index]
		var base = PlayerStats.get(stat)
		var queued = queued_levels[stat]
		
		# HARD CAP at 99
		if base + queued + delta > PlayerStats.MAX_STAT_LEVEL:
			print("[LevelUpMenu] Cannot queue — ", stat, " would exceed 99")
			return
		
		# affordability check
		var temp = queued_levels.duplicate()
		temp[stat] += 1
		if _calculate_cost_from_queued(temp) > PlayerStats.souls_carried:
			return
	
	var stat = STAT_NAMES[selected_stat_index]
	queued_levels[stat] = max(0, queued_levels[stat] + delta)
	_refresh_all_display()


func _refresh_all_display() -> void:
	var total_cost = _calculate_total_cost()
	var total_queued_points = queued_levels.values().reduce(func(a, b): return a + b, 0)
	var preview_level = PlayerStats.level + total_queued_points
	
	souls_label.text = "Souls: %d" % PlayerStats.souls_carried
	total_queued_cost_label.text = "Queued cost: %d" % total_cost
	total_level_label.text = "Level: %d → %d" % [PlayerStats.level, preview_level]
	
	confirm_button.disabled = total_cost > PlayerStats.souls_carried or total_cost == 0

	_update_left_row("vitality", vit_current, vit_preview)
	_update_left_row("endurance", end_current, end_preview)
	_update_left_row("strength", str_current, str_preview)
	_update_left_row("dexterity", dex_current, dex_preview)
	_update_left_row("attunement", att_current, att_preview)
	_update_left_row("faith", faith_current, faith_preview)
	_update_left_row("intelligence", int_current, int_preview)
	_update_left_row("luck", luck_current, luck_preview)

	_update_preview_panel()
	_update_weapon_preview()


func _update_left_row(stat_name: String, current_lbl: Label, preview_lbl: Label) -> void:
	var base = PlayerStats.get(stat_name)
	var add = queued_levels.get(stat_name, 0)
	current_lbl.text = str(base)
	preview_lbl.text = "→ " + str(base + add)
	preview_lbl.modulate = Color("ffb300ff") if STAT_NAMES.find(stat_name) == selected_stat_index else Color.WHITE
func _update_preview_panel() -> void:
	var lines = []
	for stat in STAT_NAMES:
		var base = PlayerStats.get(stat)
		var add = queued_levels.get(stat, 0)
		var final_val = base + add
		var is_changing = add > 0
		var line = ""
		
		match stat:
			"vitality":
				line = "Max HP: %d" % get_max_hp(final_val)
			"endurance":
				line = "Max Stamina: %d" % get_max_stamina(final_val)
				lines.append(line if not is_changing else "[color=#ffb300ff]" + line + "[/color]")
				line = "Equip Load: %.1f" % StatCalculator.get_equip_load_base_only(final_val)
			"strength":
				line = "Strength Scaling: %d" % StatCalculator.get_strength_scaling_base_only(final_val)
			"dexterity":
				line = "Dexterity Scaling: %d" % StatCalculator.get_dexterity_scaling_base_only(final_val)
			"intelligence":
				line = "Intelligence Scaling: %d" % StatCalculator.get_intelligence_scaling_base_only(final_val)
			"faith":
				line = "Faith Scaling: %d" % StatCalculator.get_faith_scaling_base_only(final_val)
			"attunement":
				var slots_line = "Spell Slots: %d" % StatCalculator.get_attunement_slots_base_only(final_val)
				var slots_changed = StatCalculator.get_attunement_slots_base_only(base) != StatCalculator.get_attunement_slots_base_only(final_val)
				lines.append(slots_line if not slots_changed else "[color=#ffb300ff]" + slots_line + "[/color]")
				
				line = "Max Mana: %d" % get_max_mana(final_val)
				if is_changing:
					line = "[color=#ffb300ff]" + line + "[/color]"
				lines.append(line)
				continue
			"luck":
				line = "Item Discovery: %d" % (100 + final_val)
		
		if line != "":
			if is_changing:
				line = "[color=#ffb300ff]" + line + "[/color]"
			lines.append(line)
	
	# === Defensive Stats at the bottom - live updating + gold highlighting ===
	
	# Calculate queued levels for specialist bonuses
	var q_end = queued_levels.get("endurance", 0)
	var q_int = queued_levels.get("intelligence", 0)
	var q_faith = queued_levels.get("faith", 0)
	var q_luck = queued_levels.get("luck", 0)
	
	# Universal bonus = total queued levels across all stats * 0.8
	var total_queued = queued_levels.values().reduce(func(a, b): return a + b, 0)
	var universal = total_queued * 0.8
	
	# Calculate preview values with universal + specialist bonuses
	var phys = StatCalculator.get_physical_defense_base_only() + universal + q_end * 1.5
	var mag = StatCalculator.get_magic_defense_base_only() + universal + q_int * 1.5
	var fire = StatCalculator.get_fire_defense_base_only() + universal
	var light = StatCalculator.get_lightning_defense_base_only() + universal
	var holy = StatCalculator.get_holy_defense_base_only() + universal + q_faith * 1.5
	var status_res = StatCalculator.get_status_resistance_base_only() + universal + q_luck * 1.5
	
	# Highlight the whole defensive block if any relevant stat is queued
	var def_is_changing = total_queued > 0
	
	var phys_line = "Physical Defense: %.1f" % phys
	var mag_line = "Magic Defense: %.1f" % mag
	var fire_line = "Fire Defense: %.1f" % fire
	var light_line = "Lightning Defense: %.1f" % light
	var holy_line = "Holy Defense: %.1f" % holy
	var status_line = "Status Resistance: %.1f" % status_res
	
	if def_is_changing:
		phys_line = "[color=#ffb300ff]" + phys_line + "[/color]"
		mag_line = "[color=#ffb300ff]" + mag_line + "[/color]"
		fire_line = "[color=#ffb300ff]" + fire_line + "[/color]"
		light_line = "[color=#ffb300ff]" + light_line + "[/color]"
		holy_line = "[color=#ffb300ff]" + holy_line + "[/color]"
		status_line = "[color=#ffb300ff]" + status_line + "[/color]"
	
	lines.append(phys_line)
	lines.append(mag_line)
	lines.append(fire_line)
	lines.append(light_line)
	lines.append(holy_line)
	lines.append(status_line)
	
	preview_stats.text = "\n".join(lines)
	_update_weapon_preview()

func _update_weapon_preview() -> void:
	if not is_instance_valid(preview_attack_stats):
		print("[LEVELUP-WEAPON-PREVIEW] CRITICAL: preview_attack_stats var invalid!")
		return

	print("[LEVELUP-WEAPON-PREVIEW] === START (per-slot gold) ===")
	
	var lines = []
	var slot_data = [
		[0, "Right Hand 1"],
		[1, "Right Hand 2"],
		[7, "Left Hand 1"],
		[8, "Left Hand 2"]
	]
	
	for entry in slot_data:
		var slot_idx = entry[0]
		var slot_name = entry[1]
		var item = EquipmentManager.get_equipped_item(slot_idx)
		
		if not item or not item.weapon_stats:
			lines.append("%s: —" % slot_name)
			continue
		
		# Save current real stats
		var old_strength = PlayerStats.strength
		var old_dexterity = PlayerStats.dexterity
		var old_intelligence = PlayerStats.intelligence
		var old_faith = PlayerStats.faith
		
		# === 1. Calculate BASE AR (no queued levels) ===
		var base_ar = StatCalculator.get_attack_rating(item)
		
		# === 2. Apply queued levels and calculate new AR ===
		PlayerStats.strength     = old_strength + queued_levels.get("strength", 0)
		PlayerStats.dexterity    = old_dexterity + queued_levels.get("dexterity", 0)
		PlayerStats.intelligence = old_intelligence + queued_levels.get("intelligence", 0)
		PlayerStats.faith        = old_faith + queued_levels.get("faith", 0)
		
		var queued_ar = StatCalculator.get_attack_rating(item)
		
		# Restore original stats
		PlayerStats.strength     = old_strength
		PlayerStats.dexterity    = old_dexterity
		PlayerStats.intelligence = old_intelligence
		PlayerStats.faith        = old_faith
		
		# Per-slot gold: only gold if AR actually increased
		var color = "#ffb300ff" if queued_ar > base_ar else "#ffffff"
		
		
		lines.append("%s: [color=%s]%d[/color]" % [slot_name, color, queued_ar])
	
	preview_attack_stats.text = "\n".join(lines)

# ── Scaling functions for Preview Panel (PURE BASE ONLY - no equipment modifiers) ──
# This makes the preview show "what this level-up gives me in isolation"
func get_max_hp(vit: int) -> int:
	return StatCalculator.get_max_health_base_only(vit)

func get_max_stamina(end: int) -> int:
	return StatCalculator.get_max_stamina_base_only(end)

func get_max_mana(att: int) -> int:
	return StatCalculator.get_max_mana_base_only(att)

func get_equip_load(end: int) -> float:
	return StatCalculator.get_equip_load(end)   # no ring modifiers yet, so this is fine

func get_attunement_slots(att: int) -> int:
	return StatCalculator.get_attunement_slots(att)

func _calculate_total_cost() -> int:
	return _calculate_cost_from_queued(queued_levels)

func _calculate_cost_from_queued(temp_queued: Dictionary) -> int:
	var total_points = 0
	for stat in temp_queued:
		total_points += temp_queued[stat]
	var cost = 0
	var current_level = PlayerStats.level
	for i in range(total_points):
		cost += PlayerStats.get_stat_cost(current_level + i)
	return cost


func _on_confirm_pressed() -> void:
	var cost = _calculate_total_cost()
	if cost > PlayerStats.souls_carried or cost == 0:
		return
	
	print("[LevelUpMenu] CONFIRMED — spending ", cost, " souls")
	
	PlayerStats.souls_carried -= cost
	PlayerStats.souls_changed.emit(PlayerStats.souls_carried)   # ← ADD THIS LINE
	
	# Capture leveled stats BEFORE clearing queue
	var vitality_leveled = queued_levels["vitality"] > 0
	var endurance_leveled = queued_levels["endurance"] > 0
	var attunement_leveled = queued_levels["attunement"] > 0
	
	for stat in queued_levels:
		if queued_levels[stat] > 0:
			var old = PlayerStats.get(stat)
			PlayerStats.set(stat, old + queued_levels[stat])
			PlayerStats.stat_changed.emit(stat, PlayerStats.get(stat))
	
	var total_points = queued_levels.values().reduce(func(a, b): return a + b, 0)
	PlayerStats.level += total_points
	
	# Vitality - full heal
	if vitality_leveled:
		var player = PlayerManager.current_player
		if player:
			var health = player.get_node_or_null("HealthComponent")
			if health and StatCalculator:
				health.max_health = StatCalculator.get_max_health(PlayerStats.vitality)
				health.current_health = health.max_health
				health.health_changed.emit(health.current_health, health.max_health)
				health.call_deferred("_update_dynamic_bar")
				print("[LevelUpMenu] Vitality leveled — player fully healed to new max HP ", health.max_health)
	
		# Endurance - force bar update
	if endurance_leveled:
		print("[LevelUpMenu-DEBUG] Endurance leveled → calling full StatCalculator refresh")
		StatCalculator.refresh_all_player_stats()
	
	# Attunement / Mana - fill to new max
	if attunement_leveled:
		var player = PlayerManager.current_player
		if player:
			PlayerStats.update_attunement_slots()
			var mana = player.get_node_or_null("ManaComponent")
			if mana:
				mana.fill_to_new_max()
	
	# Clear queue
	queued_levels = {"vitality":0, "endurance":0, "strength":0, "dexterity":0,
					 "attunement":0, "faith":0, "intelligence":0, "luck":0}
	
	# Final refresh
	if StatCalculator:
		StatCalculator.refresh_all_player_stats()
	
	# AUTO-SAVE after successful level-up
	SaveManager.request_save()
	print("[LevelUpMenu] Auto-save triggered after level-up")
	
	_refresh_all_display()

func _on_exit_pressed() -> void:
	queued_levels = {"vitality":0, "endurance":0, "strength":0, "dexterity":0,
					 "attunement":0, "faith":0, "intelligence":0, "luck":0}
	visible = false
	menu_closed.emit()
