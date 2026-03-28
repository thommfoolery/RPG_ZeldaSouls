# ui/menus/LevelUpMenu.gd
extends Control

signal menu_closed

# ── Title & Subtitle ──

# ── Top Info ──
@onready var souls_label: Label = %SoulsLabel
@onready var after_spend_label: Label = %AfterSpendLabel
@onready var total_queued_cost_label: Label = %TotalQueuedCostLabel
@onready var total_level_label: Label = %TotalLevelLabel

# ── Stat Rows (using Unique Names) ──
@onready var vit_current: Label = %VitalityCurrent
@onready var vit_preview: Label = %VitalityPreview
@onready var vit_effect: Label = %VitalityEffect

@onready var end_current: Label = %EnduranceCurrent
@onready var end_preview: Label = %EndurancePreview
@onready var end_effect: Label = %EnduranceEffect

@onready var str_current: Label = %StrengthCurrent
@onready var str_preview: Label = %StrengthPreview
@onready var str_effect: Label = %StrengthEffect

@onready var dex_current: Label = %DexterityCurrent
@onready var dex_preview: Label = %DexterityPreview
@onready var dex_effect: Label = %DexterityEffect

@onready var att_current: Label = %AttunementCurrent
@onready var att_preview: Label = %AttunementPreview
@onready var att_effect: Label = %AttunementEffect

@onready var faith_current: Label = %FaithCurrent
@onready var faith_preview: Label = %FaithPreview
@onready var faith_effect: Label = %FaithEffect

@onready var int_current: Label = %IntelligenceCurrent
@onready var int_preview: Label = %IntelligencePreview
@onready var int_effect: Label = %IntelligenceEffect

@onready var luck_current: Label = %LuckCurrent
@onready var luck_preview: Label = %LuckPreview
@onready var luck_effect: Label = %LuckEffect

@onready var confirm_button: Button = %ConfirmButton
@onready var exit_button: Button = %ExitButton

var queued_levels: Dictionary = {
	"vitality": 0, "endurance": 0, "strength": 0, "dexterity": 0,
	"attunement": 0, "faith": 0, "intelligence": 0, "luck": 0
}

var total_queued_cost: int = 0

func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("[LevelUpMenu] _ready() - Menu fully initialized")

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

	refresh_stats()



func refresh_stats() -> void:
	print("[LevelUpMenu] refresh_stats()")
	vit_current.text = str(PlayerStats.vitality)
	end_current.text = str(PlayerStats.endurance)
	str_current.text = str(PlayerStats.strength)
	dex_current.text = str(PlayerStats.dexterity)
	att_current.text = str(PlayerStats.attunement)
	faith_current.text = str(PlayerStats.faith)
	int_current.text = str(PlayerStats.intelligence)
	luck_current.text = str(PlayerStats.luck)

	total_level_label.text = "Level: " + str(PlayerStats.level)
	souls_label.text = "Souls: %d" % PlayerStats.souls_carried


# ── Clean Input - B exits, A does nothing for now ──
func _input(event: InputEvent) -> void:
	if not visible: return

	print("[LevelUpMenu-INPUT] Event: ", event.as_text())

	if event.is_action_pressed("ui_cancel"):           # B button
		print("[LevelUpMenu-INPUT] B pressed → exiting LevelUpMenu")
		get_viewport().set_input_as_handled()
		_on_exit_pressed()
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		print("[LevelUpMenu-INPUT] A pressed (ignored for now)")
		get_viewport().set_input_as_handled()
		return


func _on_confirm_pressed() -> void:
	print("[LevelUpMenu] Confirm button pressed")
	menu_closed.emit()


func _on_exit_pressed() -> void:
	print("[LevelUpMenu] _on_exit_pressed() - emitting menu_closed and hiding")
	
	# Reset data (kept for later)
	queued_levels = {"vitality":0, "endurance":0, "strength":0, "dexterity":0,
					"attunement":0, "faith":0, "intelligence":0, "luck":0}
	total_queued_cost = 0
	
	visible = false
	menu_closed.emit()          # Tell BonfireMenu we're done


# ── Future code kept but commented ──
# func _get_queued_total_levels() -> int: ...
# func _get_next_cost() -> int: ...
# func _can_afford_next() -> bool: ...
# func get_hp_gain(level: int) -> int: return 15 + (level * 8)
# ... etc.
