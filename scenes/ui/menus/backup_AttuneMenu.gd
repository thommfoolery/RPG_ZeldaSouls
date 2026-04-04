# ui/menus/AttuneMenu.gd
extends Control

# ─── Node references ────────────────────────────────────────────────
@onready var title_label: Label = $Panel/Sort/TitleLabel
@onready var attunement_slots_container: HBoxContainer = $Panel/Sort/AttunementSlotsContainer
@onready var spell_grid: GridContainer = $Panel/Sort/SpellScroll/SpellGrid
@onready var bottom_icon: TextureRect = $Panel/Sort/BottomDescription/SpellIcon
@onready var bottom_name: Label = $Panel/Sort/BottomDescription/SpellName
@onready var bottom_desc: Label = $Panel/Sort/BottomDescription/SpellDescription

# Pre-made attunement slots (9 total)
@onready var attunement_slot0: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot0
@onready var attunement_slot1: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot1
@onready var attunement_slot2: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot2
@onready var attunement_slot3: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot3
@onready var attunement_slot4: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot4
@onready var attunement_slot5: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot5
@onready var attunement_slot6: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot6
@onready var attunement_slot7: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot7
@onready var attunement_slot8: Panel = $Panel/Sort/AttunementSlotsContainer/AttunementSlot8

# Unique Backgrounds (always show EmptySlot.png)
@onready var background0: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot0/Background0
@onready var background1: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot1/Background1
@onready var background2: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot2/Background2
@onready var background3: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot3/Background3
@onready var background4: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot4/Background4
@onready var background5: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot5/Background5
@onready var background6: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot6/Background6
@onready var background7: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot7/Background7
@onready var background8: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot8/Background8

# Spell icons (appear on top when assigned)
@onready var icon0: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot0/Icon0
@onready var icon1: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot1/Icon1
@onready var icon2: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot2/Icon2
@onready var icon3: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot3/Icon3
@onready var icon4: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot4/Icon4
@onready var icon5: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot5/Icon5
@onready var icon6: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot6/Icon6
@onready var icon7: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot7/Icon7
@onready var icon8: TextureRect = $Panel/Sort/AttunementSlotsContainer/AttunementSlot8/Icon8

# State
var selected_attunement_index: int = 0
var selected_spell_index: int = 0
var is_in_selection_mode: bool = false

var attunement_slots: Array[Panel] = []
var backgrounds: Array[TextureRect] = []
var icons: Array[TextureRect] = []

const EMPTY_SLOT_TEXTURE = preload("res://art/objects/items/item_ui/EmptySlot.png")

func _ready() -> void:
	print("[ATTUNE-MENU] _ready() — Pre-made 9 slots loaded")

	attunement_slots = [attunement_slot0, attunement_slot1, attunement_slot2, attunement_slot3, attunement_slot4,
		attunement_slot5, attunement_slot6, attunement_slot7, attunement_slot8]
	backgrounds = [background0, background1, background2, background3, background4,
		background5, background6, background7, background8]
	icons = [icon0, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8]

	for bg in backgrounds:
		bg.texture = EMPTY_SLOT_TEXTURE
		bg.visible = true
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	selected_attunement_index = 0
	_populate_spell_grid()
	_update_attunement_display()
	_clear_bottom_description()
	_highlight_current_attunement_slot()

func _populate_spell_grid() -> void:
	for child in spell_grid.get_children():
		child.queue_free()

	var all_spells = []
	for cat in PlayerInventory.inventory:
		if cat.to_lower() == "spells":
			all_spells.append_array(PlayerInventory.inventory[cat])

	print("[ATTUNE-MENU] Found ", all_spells.size(), " spells in inventory")

	for spell in all_spells:
		var btn = Button.new()
		btn.icon = spell.icon
		btn.text = spell.display_name
		btn.custom_minimum_size = Vector2(80, 80)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.focus_mode = Control.FOCUS_ALL
		btn.set_meta("spell", spell)
		btn.pressed.connect(_on_spell_button_pressed.bind(spell))
		spell_grid.add_child(btn)

func _update_attunement_display() -> void:
	for i in icons.size():
		var icon = icons[i]
		var bg = backgrounds[i]

		if i < PlayerStats.attunement_slots_unlocked:
			bg.modulate = Color.WHITE  # normal unlocked look

			if i < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[i]:
				icon.texture = PlayerStats.attuned_spells[i].icon
				icon.visible = true
			else:
				icon.texture = null
				icon.visible = false
		else:
			# Locked slot
			bg.modulate = Color(0.318, 0.318, 0.318, 0.0)  # gone
			icon.visible = false

func _highlight_current_attunement_slot() -> void:
	print("[ATTUNE-MENU] [HIGHLIGHT] selected_attunement_index = ", selected_attunement_index)
	for i in attunement_slots.size():
		var slot = attunement_slots[i]
		if i == selected_attunement_index and i < PlayerStats.attunement_slots_unlocked:
			slot.modulate = Color(1.6, 1.6, 1.286, 1.0)
			print("[ATTUNE-MENU] → Highlighting slot ", i, " (gold)")
		else:
			slot.modulate = Color.GRAY

# ─── INPUT ──────────────────────────────────────────────────────────
# ─── INPUT ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# CRITICAL SAFETY: Prevent modulo by zero
	if PlayerStats.attunement_slots_unlocked <= 0:
		if event.is_action_pressed("ui_cancel"):
			visible = false
		return


	# B / ui_cancel always closes the menu
	if event.is_action_pressed("ui_cancel"):
		print("[ATTUNE-MENU] B pressed — closing AttuneMenu")
		is_in_selection_mode = false
		visible = false
		return

	if is_in_selection_mode:
		# Spell grid navigation
		if event.is_action_pressed("ui_right") or event.is_action_pressed("cycle_right_hand"):
			selected_spell_index = (selected_spell_index + 1) % spell_grid.get_child_count()
			_highlight_current_spell()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("cycle_left_hand"):
			selected_spell_index = (selected_spell_index - 1 + spell_grid.get_child_count()) % spell_grid.get_child_count()
			_highlight_current_spell()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_down"):
			selected_spell_index = (selected_spell_index + 4) % spell_grid.get_child_count()
			_highlight_current_spell()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_up"):
			selected_spell_index = (selected_spell_index - 4 + spell_grid.get_child_count()) % spell_grid.get_child_count()
			_highlight_current_spell()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			if selected_spell_index < spell_grid.get_child_count():
				var btn = spell_grid.get_child(selected_spell_index) as Button
				if btn and not btn.disabled:
					var spell = btn.get_meta("spell")
					if spell:
						_on_spell_button_pressed(spell)
			get_viewport().set_input_as_handled()
			return

	# Normal mode - attunement slot navigation
	if event.is_action_pressed("ui_right") or event.is_action_pressed("cycle_right_hand"):
		selected_attunement_index = (selected_attunement_index + 1) % PlayerStats.attunement_slots_unlocked
		_highlight_current_attunement_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("cycle_left_hand"):
		selected_attunement_index = (selected_attunement_index - 1 + PlayerStats.attunement_slots_unlocked) % PlayerStats.attunement_slots_unlocked
		_highlight_current_attunement_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if PlayerStats.attunement_slots_unlocked > 0:
			is_in_selection_mode = true
			selected_spell_index = 0
			_highlight_current_spell()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("equipment_unequip"):
		if not is_in_selection_mode and selected_attunement_index < PlayerStats.attuned_spells.size():
			if PlayerStats.attuned_spells[selected_attunement_index]:
				print("[ATTUNE-MENU] Unequipping slot ", selected_attunement_index)
				PlayerStats.attuned_spells[selected_attunement_index] = null
				PlayerStats.attunement_changed.emit()
				_update_attunement_display()
				_highlight_current_attunement_slot()
			else:
				print("[ATTUNE-MENU] Slot ", selected_attunement_index, " is already empty")
			get_viewport().set_input_as_handled()

# Confirm spell
func _on_spell_button_pressed(spell: GameItem) -> void:
	if not spell: return
	print("[ATTUNE-MENU] Spell confirmed: ", spell.display_name)

	# Anti-dupe
	for i in PlayerStats.attuned_spells.size():
		if i != selected_attunement_index and PlayerStats.attuned_spells[i] and PlayerStats.attuned_spells[i].id == spell.id:
			print("[ATTUNE-MENU] Anti-dupe blocked: ", spell.display_name, " already equipped")
			return

	if spell.attunement_slots > 1:
		print("[ATTUNE-MENU] Multi-slot spells not supported yet")
		return

	while PlayerStats.attuned_spells.size() <= selected_attunement_index:
		PlayerStats.attuned_spells.append(null)

	PlayerStats.attuned_spells[selected_attunement_index] = spell
	print("[ATTUNE-MENU] SUCCESS: Attuned ", spell.display_name, " to slot ", selected_attunement_index)

	PlayerStats.attunement_changed.emit() # HUD refresh

	is_in_selection_mode = false
	_update_attunement_display()
	_highlight_current_attunement_slot()

# Public open method
func open_attune_menu() -> void:
	visible = true
	is_in_selection_mode = false
	selected_attunement_index = 0
	
	# Safety guard
	if PlayerStats.attunement_slots_unlocked <= 0:
		selected_attunement_index = 0
	else:
		selected_attunement_index = mini(selected_attunement_index, PlayerStats.attunement_slots_unlocked - 1)
	
	_update_attunement_display()
	_clear_bottom_description()
	_highlight_current_attunement_slot()
	print("[ATTUNE-MENU] open_attune_menu() called")

func _highlight_current_spell() -> void:
	for i in spell_grid.get_child_count():
		var btn = spell_grid.get_child(i) as Button
		if i == selected_spell_index:
			btn.modulate = Color(1.6, 1.6, 1.6, 1.0)
		else:
			btn.modulate = Color.WHITE

func _clear_bottom_description() -> void:
	bottom_icon.texture = null
	bottom_name.text = ""
	bottom_desc.text = ""
