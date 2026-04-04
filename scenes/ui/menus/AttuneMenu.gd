# ui/menus/AttuneMenu.gd
extends Control

# ─── Node references ────────────────────────────────────────────────
@onready var title_label: Label = $Panel/Sort/TitleLabel
@onready var attunement_slots_container: HBoxContainer = $Panel/Sort/AttunementSlotsContainer
@onready var spell_grid: GridContainer = $Panel/Sort/SpellScroll/SpellGrid
@onready var bottom_icon: TextureRect = $Panel/Sort/BottomDescription/SpellIcon
@onready var bottom_name: Label = $Panel/Sort/BottomDescription/SpellName
@onready var bottom_desc: Label = $Panel/Sort/BottomDescription/SpellDescription

var attunement_slots: Array[Panel] = []
var backgrounds: Array[TextureRect] = []
var icons: Array[TextureRect] = []

const EMPTY_SLOT_TEXTURE = preload("res://art/objects/items/item_ui/EmptySlot.png")

var selected_attunement_index: int = 0
var selected_spell_index: int = 0
var is_in_selection_mode: bool = false

func _ready() -> void:
	print("[ATTUNE-MENU] _ready() — Clean multi-slot visual system")
	
	for i in 10:
		var slot = get_node_or_null("Panel/Sort/AttunementSlotsContainer/AttunementSlot" + str(i))
		if slot:
			attunement_slots.append(slot)
			backgrounds.append(slot.get_node("Background" + str(i)))
			icons.append(slot.get_node("Icon" + str(i)))
	
	for bg in backgrounds:
		bg.texture = EMPTY_SLOT_TEXTURE
		bg.visible = true
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	_update_attunement_display()
	_highlight_current_attunement_slot()
	_populate_spell_grid()


func _update_attunement_display() -> void:
	var i = 0
	while i < attunement_slots.size():
		var slot = attunement_slots[i]
		var bg = backgrounds[i]
		var icon = icons[i]
		
		if i < PlayerStats.attunement_slots_unlocked:
			bg.modulate = Color.WHITE
			
			if i < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[i]:
				var spell = PlayerStats.attuned_spells[i]
				icon.texture = spell.icon
				icon.visible = true
				
				# Skip extra slots consumed by this spell
				var needed = 1
				if "attunement_slots" in spell:
					needed = spell.attunement_slots
				
				for j in range(1, needed):
					if i + j < attunement_slots.size():
						backgrounds[i + j].modulate = Color(0.3, 0.3, 0.3, 0.4)
						icons[i + j].visible = false
				
				i += needed - 1   # skip the hidden slots
			else:
				icon.texture = null
				icon.visible = false
		else:
			bg.modulate = Color(0.3, 0.3, 0.3, 0.4)
			icon.visible = false
		
		i += 1


func _highlight_current_attunement_slot() -> void:
	for i in attunement_slots.size():
		var slot = attunement_slots[i]
		if i == selected_attunement_index and i < PlayerStats.attunement_slots_unlocked:
			slot.modulate = Color(1.6, 1.6, 1.286, 1.0)
		else:
			slot.modulate = Color.GRAY


func _populate_spell_grid() -> void:
	for child in spell_grid.get_children():
		child.queue_free()
	
	var all_spells = []
	for cat in PlayerInventory.inventory:
		if cat.to_lower() == "spells":
			all_spells.append_array(PlayerInventory.inventory[cat])
	
	for spell in all_spells:
		var btn = Button.new()
		btn.icon = spell.icon
		btn.text = spell.display_name
		btn.custom_minimum_size = Vector2(80, 80)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.set_meta("spell", spell)
		btn.pressed.connect(_on_spell_button_pressed.bind(spell))
		spell_grid.add_child(btn)


func _on_spell_button_pressed(spell: GameItem) -> void:
	if not spell: return
	
	var needed = 1
	if "attunement_slots" in spell:
		needed = spell.attunement_slots
	
	print("[ATTUNE-MENU] Attempting to equip ", spell.display_name, " (needs ", needed, " slots)")
	
	if selected_attunement_index + needed > PlayerStats.attunement_slots_unlocked:
		print("[ATTUNE-MENU] Not enough slots! Needs ", needed, ", only ", PlayerStats.attunement_slots_unlocked - selected_attunement_index, " available from here")
		return
	
	# Clear the required range first
	for i in range(needed):
		var idx = selected_attunement_index + i
		if idx < PlayerStats.attuned_spells.size():
			PlayerStats.attuned_spells[idx] = null
	
	# Place the spell only in the first visible slot
	PlayerStats.attuned_spells[selected_attunement_index] = spell
	
	print("[ATTUNE-MENU] SUCCESS: Equipped ", spell.display_name, " using ", needed, " slots starting at ", selected_attunement_index)
	
	PlayerStats.attunement_changed.emit()
	_update_attunement_display()
	_highlight_current_attunement_slot()
	is_in_selection_mode = false


func open_attune_menu() -> void:
	visible = true
	is_in_selection_mode = false
	selected_attunement_index = mini(selected_attunement_index, PlayerStats.attunement_slots_unlocked - 1)
	_update_attunement_display()
	_highlight_current_attunement_slot()
	_populate_spell_grid()
	print("[ATTUNE-MENU] Opened — ", PlayerStats.attunement_slots_unlocked, " slots unlocked")


# ─── INPUT ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_cancel"):
		visible = false
		is_in_selection_mode = false
		return
	
	if PlayerStats.attunement_slots_unlocked <= 0:
		return
	
	if is_in_selection_mode:
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
				if btn:
					_on_spell_button_pressed(btn.get_meta("spell"))
			get_viewport().set_input_as_handled()
			return
	
	# Normal slot navigation
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
	
	# UNEQUIP
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


func _highlight_current_spell() -> void:
	for i in spell_grid.get_child_count():
		var btn = spell_grid.get_child(i) as Button
		if btn:
			btn.modulate = Color(1.6, 1.6, 1.6, 1.0) if i == selected_spell_index else Color.WHITE
