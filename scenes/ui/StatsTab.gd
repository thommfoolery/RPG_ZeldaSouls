# scripts/ui/StatsTab.gd
extends Panel

# ── Node references ──
@onready var level_value: Label = %LevelValue
@onready var souls_value: Label = %SoulsValue
@onready var vitality_value: Label = %VitalityValue
@onready var endurance_value: Label = %EnduranceValue
@onready var strength_value: Label = %StrengthValue
@onready var dexterity_value: Label = %DexterityValue
@onready var attunement_value: Label = %AttunementValue
@onready var intelligence_value: Label = %IntelligenceValue
@onready var faith_value: Label = %FaithValue
@onready var luck_value: Label = %LuckValue
@onready var max_hp_value: Label = %MaxHPValue
@onready var max_stamina_value: Label = %MaxStaminaValue
@onready var equip_load_value: Label = %EquipLoadValue
@onready var max_mana_value: Label = %MaxManaValue
@onready var spell_slots_value: Label = %SpellSlotsValue
@onready var str_scaling_value: Label = %StrScalingValue
@onready var dex_scaling_value: Label = %DexScalingValue
@onready var int_scaling_value: Label = %IntScalingValue
@onready var faith_scaling_value: Label = %FaithScalingValue
@onready var luck_discovery_value: Label = %LuckDiscoveryValue
@onready var hp_regen_value: Label = %HPRegenValue
@onready var mana_regen_value: Label = %ManaRegenValue
@onready var stamina_regen_value: Label = %StaminaRegenValue
@onready var physical_defense_value: Label = %PhysicalDefenseValue
@onready var magic_defense_value: Label = %MagicDefenseValue
@onready var fire_defense_value: Label = %FireDefenseValue
@onready var lightning_defense_value: Label = %LightningDefenseValue
@onready var holy_defense_value: Label = %HolyDefenseValue
@onready var status_resistance_value: Label = %StatusResistanceValue
@onready var poise_value: Label = %PoiseValue
@onready var right_hand1_ar_value: Label = %RightHand1ARValue  
@onready var right_hand2_ar_value: Label = %RightHand2ARValue
@onready var left_hand1_ar_value: Label = %LeftHand1ARValue
@onready var left_hand2_ar_value: Label = %LeftHand2ARValue

# New references for bonuses panel
@onready var active_bonuses_container: VBoxContainer = $MainLayout/BonusesVBox/ScrollContainer/ActiveBonusesContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visibility_changed.connect(_on_visibility_changed)
	
	if PlayerStats and PlayerStats.has_signal("stat_changed"):
		PlayerStats.stat_changed.connect(_on_stat_changed)
	
	_connect_to_level_up_menu()
	_refresh_stats_tab()
	print("[STATS-TAB] StatsTab ready — fully live updating with equipment bonuses")

func _on_visibility_changed() -> void:
	if visible:
		_refresh_stats_tab()

func _on_stat_changed(stat_name: String, new_value: int) -> void:
	_refresh_stats_tab()

func _connect_to_level_up_menu() -> void:
	var menu_root = get_parent().get_parent()
	if menu_root and menu_root.has_node("%LevelUpMenu"):
		var level_up_menu = menu_root.get_node("%LevelUpMenu")
		if level_up_menu.has_signal("menu_closed"):
			level_up_menu.menu_closed.connect(_on_level_up_closed)

func _on_level_up_closed() -> void:
	_refresh_stats_tab()

func _refresh_stats_tab() -> void:
	if not PlayerStats or not StatCalculator:
		push_warning("[STATS-TAB] PlayerStats or StatCalculator not ready")
		return
	
	print("[STATS-TAB-DEBUG] Full refresh triggered")
	
	# Core stats (keep everything you already had)
	level_value.text = str(PlayerStats.level)
	souls_value.text = "%d" % PlayerStats.souls_carried
	
	vitality_value.text = _format_base_stat_value("vitality", PlayerStats.vitality)
	endurance_value.text = _format_base_stat_value("endurance", PlayerStats.endurance)
	strength_value.text = _format_base_stat_value("strength", PlayerStats.strength)
	dexterity_value.text = _format_base_stat_value("dexterity", PlayerStats.dexterity)
	attunement_value.text = _format_base_stat_value("attunement", PlayerStats.attunement)
	intelligence_value.text = _format_base_stat_value("intelligence", PlayerStats.intelligence)
	faith_value.text = _format_base_stat_value("faith", PlayerStats.faith)
	luck_value.text = _format_base_stat_value("luck", PlayerStats.luck)
	
	max_hp_value.text = str(StatCalculator.get_max_health(PlayerStats.vitality))
	max_stamina_value.text = str(StatCalculator.get_max_stamina(PlayerStats.endurance))
	equip_load_value.text = "%.1f" % StatCalculator.get_equip_load(PlayerStats.endurance)
	max_mana_value.text = str(StatCalculator.get_max_mana(PlayerStats.attunement))
	spell_slots_value.text = str(StatCalculator.get_attunement_slots(PlayerStats.attunement))
	
	str_scaling_value.text = str(StatCalculator.get_strength_scaling())
	dex_scaling_value.text = str(StatCalculator.get_dexterity_scaling())
	int_scaling_value.text = str(StatCalculator.get_intelligence_scaling())
	faith_scaling_value.text = str(StatCalculator.get_faith_scaling())
	luck_discovery_value.text = str(StatCalculator.get_item_discovery())
	
	hp_regen_value.text = "%.1f/s" % StatCalculator.get_hp_regen_rate()
	mana_regen_value.text = "%.1f/s" % StatCalculator.get_mana_regen_rate()
	stamina_regen_value.text = "%.1f/s" % StatCalculator.get_stamina_regen_rate()
	
	# === Defensive Stats (3rd Column) ===
	var phys_base = StatCalculator.get_physical_defense_base_only()
	var mag_base = StatCalculator.get_magic_defense_base_only()
	var fire_base = StatCalculator.get_fire_defense_base_only()
	var light_base = StatCalculator.get_lightning_defense_base_only()
	var holy_base = StatCalculator.get_holy_defense_base_only()
	var status_base = StatCalculator.get_status_resistance_base_only()
	var poise_base = StatCalculator.get_poise_base_only()

	var phys_bonus = StatCalculator.get_total_armor_physical_defense()
	var mag_bonus = StatCalculator.get_total_armor_magic_defense()
	var fire_bonus = StatCalculator.get_total_armor_fire_defense()
	var light_bonus = StatCalculator.get_total_armor_lightning_defense()
	var holy_bonus = StatCalculator.get_total_armor_holy_defense()
	var status_bonus = StatCalculator.get_total_armor_status_resistance()
	var poise_bonus = StatCalculator.get_total_armor_poise()

	physical_defense_value.text = _format_defense_value(phys_base, phys_bonus)
	magic_defense_value.text = _format_defense_value(mag_base, mag_bonus)
	fire_defense_value.text = _format_defense_value(fire_base, fire_bonus)
	lightning_defense_value.text = _format_defense_value(light_base, light_bonus)
	holy_defense_value.text = _format_defense_value(holy_base, holy_bonus)
	status_resistance_value.text = _format_defense_value(status_base, status_bonus)

	# Poise — pure total, no bonus wrapper
	if poise_value:
		poise_value.text = "%.1f" % StatCalculator.get_poise()
	
		# === Hand Slot Attack Ratings ===
	# Right Hand 1
	var rh1_item = EquipmentManager.get_equipped_item(0)  # slot 0 = Right Hand 1
	right_hand1_ar_value.text = str(StatCalculator.get_attack_rating(rh1_item)) if rh1_item and rh1_item.weapon_stats else "—"

	# Right Hand 2
	var rh2_item = EquipmentManager.get_equipped_item(1)  # slot 1 = Right Hand 2
	right_hand2_ar_value.text = str(StatCalculator.get_attack_rating(rh2_item)) if rh2_item and rh2_item.weapon_stats else "—"

	# Left Hand 1
	var lh1_item = EquipmentManager.get_equipped_item(7)   # slot 7 = Left Hand 1
	left_hand1_ar_value.text = str(StatCalculator.get_attack_rating(lh1_item)) if lh1_item and lh1_item.weapon_stats else "—"

	# Left Hand 2
	var lh2_item = EquipmentManager.get_equipped_item(8)   # slot 8 = Left Hand 2
	left_hand2_ar_value.text = str(StatCalculator.get_attack_rating(lh2_item)) if lh2_item and lh2_item.weapon_stats else "—"
	# NEW: Refresh active equipment bonuses
	_refresh_active_equipment_bonuses()
	
	print("[STATS-TAB] Display updated — Level ", PlayerStats.level, " | HP ", max_hp_value.text)

# ── New: Active Equipment Bonuses Panel ──
func _refresh_active_equipment_bonuses() -> void:
	if not active_bonuses_container:
		return
	
	# Clear old entries
	for child in active_bonuses_container.get_children():
		child.queue_free()
	
	var has_bonus = false
	
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if item and not item.permanent_modifiers.is_empty():
			for mod in item.permanent_modifiers:
				if mod and mod.display_name:
					has_bonus = true
					
					var hbox = HBoxContainer.new()
					hbox.add_theme_constant_override("separation", 12)
					
					var icon_rect = TextureRect.new()
					icon_rect.texture = mod.icon if mod.icon else null
					icon_rect.custom_minimum_size = Vector2(36, 36)
					icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					hbox.add_child(icon_rect)
					
					var label = Label.new()
					label.text = mod.display_name
					label.modulate = mod.color if mod.color != Color.WHITE else Color.WHITE
					label.add_theme_font_size_override("font_size", 16)
					hbox.add_child(label)
					
					active_bonuses_container.add_child(hbox)
	
	if not has_bonus:
		var empty = Label.new()
		empty.text = "No equipment bonuses active"
		empty.modulate = Color(0.6, 0.6, 0.6, 1.0)
		active_bonuses_container.add_child(empty)

# Base stats: "(+2) 5" or "5"
func _format_base_stat_value(stat_name: String, base_value: int) -> String:
	var effective = StatCalculator.get_effective_stat(stat_name)
	var bonus = effective - base_value
	if bonus > 0:
		return "(+%d) %d" % [bonus, base_value]
	else:
		return "%d" % base_value

# Defensive stats: "(+35) 294.4" or "294.4"
func _format_defense_value(value: float, bonus: float) -> String:
	if bonus > 0:
		return "(+%.1f) %.1f" % [bonus, value]
	else:
		return "%.1f" % value
