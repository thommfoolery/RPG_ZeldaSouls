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


func _update_left_row(stat_name: String, current_lbl: Label, preview_lbl: Label) -> void:
	var base = PlayerStats.get(stat_name)
	var add = queued_levels.get(stat_name, 0)
	current_lbl.text = str(base)
	preview_lbl.text = "→ " + str(base + add)
	preview_lbl.modulate = Color(1.6, 1.4, 0.6) if STAT_NAMES.find(stat_name) == selected_stat_index else Color.WHITE


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
				line = "Max HP:          %d" % get_max_hp(final_val)
			"endurance":
				line = "Max Stamina:     %d" % get_max_stamina(final_val)
				lines.append(line if not is_changing else "[color=#ffdd66]" + line + "[/color]")
				line = "Equip Load:      %.1f" % get_equip_load(final_val)
			"strength":
				line = "Strength Scaling: %d" % final_val
			"dexterity":
				line = "Dexterity Scaling: %d" % final_val
			"intelligence":
				line = "Intelligence Scaling: %d" % final_val
			"faith":
				line = "Faith Scaling:   %d" % final_val
			"attunement":
				var slots_line = "Spell Slots:       %d" % get_attunement_slots(final_val)
				var slots_changed = get_attunement_slots(base) != get_attunement_slots(final_val)
				lines.append(slots_line if not slots_changed else "[color=#ffdd66]" + slots_line + "[/color]")
				line = "Max Mana:        %d" % get_max_mana(final_val)
			"luck":
				line = "Item Discovery:  %d" % (100 + final_val)
		
		if is_changing and line != "":
			line = "[color=#ffdd66]" + line + "[/color]"
		
		lines.append(line)
	
	preview_stats.text = "\n".join(lines)


# ── Scaling functions (always delegate to StatCalculator) ─────────────────────
func get_max_hp(vit: int) -> int:
	return StatCalculator.get_max_health(vit)

func get_max_stamina(end: int) -> int:
	return StatCalculator.get_max_stamina(end)

func get_equip_load(end: int) -> float:
	return StatCalculator.get_equip_load(end)

func get_max_mana(att: int) -> int:
	return StatCalculator.get_max_mana(att)

func get_attunement_slots(att: int) -> int:
	if att < 10: return 0
	if att <= 11: return 1
	if att <= 13: return 2
	if att <= 15: return 3
	if att <= 18: return 4
	if att <= 22: return 5
	if att <= 27: return 6
	if att <= 33: return 7
	if att <= 40: return 8
	if att <= 49: return 9
	return 10


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
		var player = PlayerManager.current_player
		if player:
			var stamina = player.get_node_or_null("StaminaComponent")
			if stamina:
				stamina.call_deferred("_update_dynamic_bar")
				print("[LevelUpMenu] Endurance leveled — forcing Stamina bar update")
	
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
