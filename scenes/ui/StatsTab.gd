# scripts/ui/StatsTab.gd
extends Panel

# ── Node references (must match exact % names in StatsPanel) ──
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Refresh every time this tab becomes visible (covers reopen + tab switch)
	visibility_changed.connect(_on_visibility_changed)
	
	# Live update whenever ANY stat or level changes (LevelUpMenu, future equipment, etc.)
	if PlayerStats and PlayerStats.has_signal("stat_changed"):
		PlayerStats.stat_changed.connect(_on_stat_changed)
		print("[STATS-TAB] Connected to PlayerStats.stat_changed for live updates")
	
	# Optional: still keep LevelUpMenu direct connection for immediate feedback
	_connect_to_level_up_menu()
	
	_refresh_stats_tab()
	print("[STATS-TAB] StatsTab ready — fully live updating")


func _on_visibility_changed() -> void:
	if visible:
		print("[STATS-TAB] Tab became visible — refreshing")
		_refresh_stats_tab()


func _on_stat_changed(stat_name: String, new_value: int) -> void:
	print("[STATS-TAB] Stat changed: ", stat_name, " → ", new_value, " → refreshing display")
	_refresh_stats_tab()


func _connect_to_level_up_menu() -> void:
	var menu_root = get_parent().get_parent()  # CharacterMenu > MenuController > StatsPanel
	if menu_root and menu_root.has_node("%LevelUpMenu"):
		var level_up_menu = menu_root.get_node("%LevelUpMenu")
		if level_up_menu.has_signal("menu_closed"):
			level_up_menu.menu_closed.connect(_on_level_up_closed)
			print("[STATS-TAB] Connected to LevelUpMenu.menu_closed")


func _on_level_up_closed() -> void:
	print("[STATS-TAB] LevelUpMenu closed — immediate refresh")
	_refresh_stats_tab()


func _refresh_stats_tab() -> void:
	if not PlayerStats or not StatCalculator:
		push_warning("[STATS-TAB] PlayerStats or StatCalculator not ready")
		return
	
	print("[STATS-TAB-DEBUG] Full refresh triggered")
	
	# Level & Souls
	level_value.text = str(PlayerStats.level)
	souls_value.text = "%d" % PlayerStats.souls_carried
	
	# Base Stats
	vitality_value.text    = str(PlayerStats.vitality)
	endurance_value.text   = str(PlayerStats.endurance)
	strength_value.text    = str(PlayerStats.strength)
	dexterity_value.text   = str(PlayerStats.dexterity)
	attunement_value.text  = str(PlayerStats.attunement)
	intelligence_value.text = str(PlayerStats.intelligence)
	faith_value.text       = str(PlayerStats.faith)
	luck_value.text        = str(PlayerStats.luck)
	
	# Derived Stats — all from StatCalculator (single source of truth)
	max_hp_value.text       = str(StatCalculator.get_max_health(PlayerStats.vitality))
	max_stamina_value.text  = str(StatCalculator.get_max_stamina(PlayerStats.endurance))
	equip_load_value.text   = "%.1f" % StatCalculator.get_equip_load(PlayerStats.endurance)
	max_mana_value.text     = str(StatCalculator.get_max_mana(PlayerStats.attunement))
	spell_slots_value.text  = str(StatCalculator.get_attunement_slots(PlayerStats.attunement))
	
	# Scaling (raw values for now — easy to upgrade later)
	str_scaling_value.text    = str(PlayerStats.strength)
	dex_scaling_value.text    = str(PlayerStats.dexterity)
	int_scaling_value.text    = str(PlayerStats.intelligence)
	faith_scaling_value.text  = str(PlayerStats.faith)
	luck_discovery_value.text = str(100 + PlayerStats.luck)
	
	print("[STATS-TAB] Display updated — Level ", PlayerStats.level, " | HP ", max_hp_value.text)
