extends CanvasLayer

signal menu_closed

@onready var bonfire_title_label: Label = %BonfireTitleLabel     # or $MenuContainer/BonfireTitleLabel if no unique name
@onready var bonfire_subtitle_label: Label = %BonfireSubtitleLabel

@onready var souls_label: Label = $MenuContainer/Background/SoulsLabel
@onready var after_spend_label: Label = $MenuContainer/Background/AfterSpendLabel
@onready var total_queued_cost_label: Label = $MenuContainer/Background/TotalQueuedCostLabel
@onready var total_level_label: Label = $MenuContainer/Background/TotalLevelLabel

# Vitality
@onready var vit_current: Label = $MenuContainer/Background/StatsVBox/VitalityHBox/Current
@onready var vit_preview: Label = $MenuContainer/Background/StatsVBox/VitalityHBox/PreviewLabel
@onready var vit_effect: Label = $MenuContainer/Background/StatsVBox/VitalityHBox/EffectLabel
@onready var vit_plus: Button = $MenuContainer/Background/StatsVBox/VitalityHBox/PlusButton
@onready var vit_minus: Button = $MenuContainer/Background/StatsVBox/VitalityHBox/MinusButton

# Endurance
@onready var end_current: Label = $MenuContainer/Background/StatsVBox/EnduranceHBox/Current
@onready var end_preview: Label = $MenuContainer/Background/StatsVBox/EnduranceHBox/PreviewLabel
@onready var end_effect: Label = $MenuContainer/Background/StatsVBox/EnduranceHBox/EffectLabel
@onready var end_plus: Button = $MenuContainer/Background/StatsVBox/EnduranceHBox/PlusButton
@onready var end_minus: Button = $MenuContainer/Background/StatsVBox/EnduranceHBox/MinusButton

# Strength
@onready var str_current: Label = $MenuContainer/Background/StatsVBox/StrengthHBox/Current
@onready var str_preview: Label = $MenuContainer/Background/StatsVBox/StrengthHBox/PreviewLabel
@onready var str_effect: Label = $MenuContainer/Background/StatsVBox/StrengthHBox/EffectLabel
@onready var str_plus: Button = $MenuContainer/Background/StatsVBox/StrengthHBox/PlusButton
@onready var str_minus: Button = $MenuContainer/Background/StatsVBox/StrengthHBox/MinusButton

# Dexterity
@onready var dex_current: Label = $MenuContainer/Background/StatsVBox/DexterityHBox/Current
@onready var dex_preview: Label = $MenuContainer/Background/StatsVBox/DexterityHBox/PreviewLabel
@onready var dex_effect: Label = $MenuContainer/Background/StatsVBox/DexterityHBox/EffectLabel
@onready var dex_plus: Button = $MenuContainer/Background/StatsVBox/DexterityHBox/PlusButton
@onready var dex_minus: Button = $MenuContainer/Background/StatsVBox/DexterityHBox/MinusButton

@onready var confirm_button: Button = $MenuContainer/Background/ConfirmButton
@onready var exit_button: Button = $MenuContainer/Background/ExitButton

var queued_levels: Dictionary = {"vitality": 0, "endurance": 0, "strength": 0, "dexterity": 0}
var total_queued_cost: int = 0

func _ready() -> void:
	visible = false
	add_to_group("rest_menu")  # for InputManager to detect
	refresh_bonfire_info()
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps input alive while paused
	
	# Button connections
	vit_plus.pressed.connect(_on_vit_plus_pressed)
	vit_minus.pressed.connect(_on_vit_minus_pressed)
	end_plus.pressed.connect(_on_end_plus_pressed)
	end_minus.pressed.connect(_on_end_minus_pressed)
	str_plus.pressed.connect(_on_str_plus_pressed)
	str_minus.pressed.connect(_on_str_minus_pressed)
	dex_plus.pressed.connect(_on_dex_plus_pressed)
	dex_minus.pressed.connect(_on_dex_minus_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	
	confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.focus_mode = Control.FOCUS_ALL
	exit_button.focus_mode = Control.FOCUS_ALL
	
	# Force focus on exit button when menu opens (deferred so scene is ready)
	exit_button.grab_focus.call_deferred()
	if not bonfire_title_label or not bonfire_subtitle_label:
		push_warning("[RestMenu] Title/Subtitle labels not found — using fallback text")

# ─── Input handling ─────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	
	# Block START (menu_pause) while rest is open
	if event.is_action_pressed("menu_pause"):
		get_viewport().set_input_as_handled()
		return
	
	# B / Esc to close
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# ui_accept for focused buttons
	if event.is_action_pressed("ui_accept"):
		if confirm_button.has_focus():
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()
		elif exit_button.has_focus():
			_on_exit_pressed()
			get_viewport().set_input_as_handled()
			

# ─── Rest of your functions unchanged ──────────────────────────────────
func refresh_bonfire_info() -> void:
	# Find current bonfire from checkpoint (most reliable)
	if CheckpointManager and CheckpointManager.current_bonfire_id:
		var entry = BonfireManager.get_entry(CheckpointManager.current_bonfire_id)
		if entry:
			if bonfire_title_label:
				bonfire_title_label.text = entry.title
			if bonfire_subtitle_label:
				bonfire_subtitle_label.text = entry.subtitle
			print("[RestMenu] Displaying bonfire: ", entry.title, " - ", entry.subtitle)
		else:
			bonfire_title_label.text = "Unknown Flame"
			bonfire_subtitle_label.text = ""
	else:
		bonfire_title_label.text = "Resting..."
		bonfire_subtitle_label.text = ""

func refresh_stats() -> void:
	print("Refresh - vit:", PlayerStats.vitality, " queued:", queued_levels["vitality"],
	" HP gain diff:", (get_hp_gain(PlayerStats.vitality + queued_levels["vitality"]) - get_hp_gain(PlayerStats.vitality)))
	vit_current.text = str(PlayerStats.vitality)
	end_current.text = str(PlayerStats.endurance)
	str_current.text = str(PlayerStats.strength)
	dex_current.text = str(PlayerStats.dexterity)
	total_level_label.text = "Level: " + str(PlayerStats.level + _get_queued_total_levels())
	souls_label.text = "Souls: %d" % PlayerStats.souls_carried
	var next_vit = PlayerStats.vitality + queued_levels["vitality"]
	vit_preview.text = "+%d" % queued_levels["vitality"]
	vit_effect.text = "Max HP: +%d" % (get_hp_gain(next_vit) - get_hp_gain(PlayerStats.vitality))
	var next_end = PlayerStats.endurance + queued_levels["endurance"]
	end_preview.text = "+%d" % queued_levels["endurance"]
	end_effect.text = "Max Stamina: +%d" % (get_stamina_gain(next_end) - get_stamina_gain(PlayerStats.endurance))
	var next_str = PlayerStats.strength + queued_levels["strength"]
	str_preview.text = "+%d" % queued_levels["strength"]
	str_effect.text = "Attack Damage: +%.1f" % (get_strength_damage_gain(next_str) - get_strength_damage_gain(PlayerStats.strength))
	var next_dex = PlayerStats.dexterity + queued_levels["dexterity"]
	dex_preview.text = "+%d" % queued_levels["dexterity"]
	dex_effect.text = "Attack Speed: +%.2f" % (get_dex_attack_speed_gain(next_dex) - get_dex_attack_speed_gain(PlayerStats.dexterity))
	update_queued_cost()

func get_hp_gain(level: int) -> int:
	return 15 + (level * 8)

func get_stamina_gain(level: int) -> int:
	return 5 + (level * 3)

func get_strength_damage_gain(level: int) -> float:
	return 1.0 + (level * 0.12)

func get_dex_attack_speed_gain(level: int) -> float:
	return 0.02 * level

func update_queued_cost() -> void:
	total_queued_cost_label.text = "Cost: %d" % total_queued_cost
	after_spend_label.text = "After: %d" % (PlayerStats.souls_carried - total_queued_cost)

func _get_next_cost() -> int:
	var next_sl = PlayerStats.level + _get_queued_total_levels() + 1
	return PlayerStats.get_stat_cost(next_sl)

func _can_afford_next() -> bool:
	return PlayerStats.souls_carried >= total_queued_cost + _get_next_cost()

func _get_queued_total_levels() -> int:
	var total = 0
	for v in queued_levels.values():
		total += v
	return total

func _on_vit_plus_pressed() -> void:
	if _can_afford_next():
		queued_levels["vitality"] += 1
		total_queued_cost += _get_next_cost()
		refresh_stats()

func _on_vit_minus_pressed() -> void:
	if queued_levels["vitality"] > 0:
		queued_levels["vitality"] -= 1
		total_queued_cost -= _get_next_cost()
		refresh_stats()

func _on_end_plus_pressed() -> void:
	if _can_afford_next():
		queued_levels["endurance"] += 1
		total_queued_cost += _get_next_cost()
		refresh_stats()

func _on_end_minus_pressed() -> void:
	if queued_levels["endurance"] > 0:
		queued_levels["endurance"] -= 1
		total_queued_cost -= _get_next_cost()
		refresh_stats()

func _on_str_plus_pressed() -> void:
	if _can_afford_next():
		queued_levels["strength"] += 1
		total_queued_cost += _get_next_cost()
		refresh_stats()

func _on_str_minus_pressed() -> void:
	if queued_levels["strength"] > 0:
		queued_levels["strength"] -= 1
		total_queued_cost -= _get_next_cost()
		refresh_stats()

func _on_dex_plus_pressed() -> void:
	if _can_afford_next():
		queued_levels["dexterity"] += 1
		total_queued_cost += _get_next_cost()
		refresh_stats()

func _on_dex_minus_pressed() -> void:
	if queued_levels["dexterity"] > 0:
		queued_levels["dexterity"] -= 1
		total_queued_cost -= _get_next_cost()
		refresh_stats()

func _on_confirm_pressed() -> void:
	print("[RestMenu] Confirm button PRESSED - applying levels")
	PlayerStats.vitality += queued_levels["vitality"]
	PlayerStats.endurance += queued_levels["endurance"]
	PlayerStats.strength += queued_levels["strength"]
	PlayerStats.dexterity += queued_levels["dexterity"]
	PlayerStats.souls_carried -= total_queued_cost
	PlayerStats.souls_changed.emit(PlayerStats.souls_carried)
	PlayerStats.level += _get_queued_total_levels()
	queued_levels = {"vitality": 0, "endurance": 0, "strength": 0, "dexterity": 0}
	total_queued_cost = 0
	refresh_stats()
	print("[RestMenu] Emitting menu_closed from Confirm")
	menu_closed.emit()
	visible = false

func _on_exit_pressed() -> void:
	print("[RestMenu] Exit button PRESSED - resetting queued - EMITTING menu_closed")
	queued_levels = {"vitality": 0, "endurance": 0, "strength": 0, "dexterity": 0}
	total_queued_cost = 0
	refresh_stats()
	menu_closed.emit()
	visible = false
