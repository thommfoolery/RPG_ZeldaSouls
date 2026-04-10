# ui/hud/CrossHUD.gd
extends Control
class_name CrossHUD
signal quick_use_changed(new_index: int)

# ─── Cross Nodes ────────────────────────────────────────────────────
@onready var right_hand_icon: TextureRect = $RightHandSlot/RightHandIcon
@onready var right_hand_label: Label = $RightHandSlot/RightHandLabel
@onready var left_hand_icon: TextureRect = $LeftHandSlot/LeftHandIcon
@onready var left_hand_label: Label = $LeftHandSlot/LeftHandLabel
@onready var quick_use_icon: TextureRect = $BottomSlot/QuickUseIcon
@onready var quick_use_qty: Label = $BottomSlot/DownQuantityLabel
@onready var ammo_slot1_container: Control = $AmmoSlot1
@onready var ammo_slot1_icon: TextureRect = $AmmoSlot1/AmmoIcon1
@onready var ammo_qty1: Label = $AmmoSlot1/AmmoQuantityLabel1
@onready var ammo_slot2_container: Control = $AmmoSlot2
@onready var ammo_slot2_icon: TextureRect = $AmmoSlot2/AmmoIcon2
@onready var ammo_qty2: Label = $AmmoSlot2/AmmoQuantityLabel2
@onready var attunement_icon: TextureRect = $AttunementSlot/AttunementIcon
@onready var attunement_label: Label = $AttunementSlot/AttunementLabel
@onready var estus_container: Control = $HUDContainer/EstusContainer
@onready var quick_slot_label: Label = $BottomSlot/QuickSlotLabel   

# ─── State ──────────────────────────────────────────────────────────
var active_right_index: int = 0
var active_left_index: int = 7
var active_quick_index: int = 2
var active_attunement_index: int = 0
var quick_hold_timer: Timer
var attunement_hold_timer: Timer

func _ready() -> void:
	# Create timers first
	quick_hold_timer = Timer.new()
	quick_hold_timer.wait_time = 0.5
	quick_hold_timer.one_shot = true
	quick_hold_timer.timeout.connect(_on_quick_hold_timeout)
	add_child(quick_hold_timer)

	attunement_hold_timer = Timer.new()
	attunement_hold_timer.wait_time = 0.5
	attunement_hold_timer.one_shot = true
	attunement_hold_timer.timeout.connect(_on_attunement_hold_timeout)
	add_child(attunement_hold_timer)

	# Use call_deferred so we run after EquipmentManager finishes loading save data
	call_deferred("_late_init")

	print("[CrossHUD] _ready() - scheduling late init for post-save/load safety")


func _late_init() -> void:
	print("[CrossHUD] _late_init() running (post-save/load)")

	# Safe signal connections
	if EquipmentManager:
		if not EquipmentManager.equipped_changed.is_connected(_on_equipped_changed):
			EquipmentManager.equipped_changed.connect(_on_equipped_changed)
			print("[CrossHUD] Connected to EquipmentManager.equipped_changed")

	if PlayerInventory:
		if not PlayerInventory.inventory_changed.is_connected(_on_inventory_changed):
			PlayerInventory.inventory_changed.connect(_on_inventory_changed)
			print("[CrossHUD] Connected to PlayerInventory.inventory_changed")

	# Register with QuickUseHandler
	if QuickUseHandler:
		QuickUseHandler.cross_hud = self
		print("[CrossHUD-DEBUG] Registered self with QuickUseHandler")

	add_to_group("cross_hud")
	print("[CrossHUD] Added to group 'cross_hud'")

	# Multiple update attempts to handle timing issues after loading a save
	_update_all_cross_slots()
	_update_ammo_display()
	_update_attunement_slot()

	# One extra frame later - this fixes most save/load timing problems
	await get_tree().process_frame
	_update_all_cross_slots()
	_update_ammo_display()
	_update_attunement_slot()
	print("[CrossHUD] QuickSlotLabel found: ", quick_slot_label != null)
	print("[CrossHUD] Late initialization complete - CrossHUD should now respond to input")

func _on_inventory_changed() -> void:
	_update_ammo_display()
	_update_quick_use_slot()
	_update_ammo_tint_for_bow()
	_update_attunement_slot()   # ← add this   # ← add this line
	print("[CrossHUD] Inventory changed — refreshed ammo display")
	
# ─── Signal handler for equipment changes ───────────────────────────
func _on_equipped_changed(slot_index: int, _new_item: GameItem) -> void:
	print("[CrossHUD] equipped_changed received for slot ", slot_index, " — refreshing cross")
	_update_all_cross_slots()
	_update_ammo_tint_for_bow()   # ← add this
	_update_attunement_slot()
	if slot_index == 9 or slot_index == 10:
		_update_ammo_display()
		_update_quick_use_slot()   # ← add this line so it updates when quick slot changes
		_update_ammo_tint_for_bow() 
		_update_attunement_slot()

# ─── Public API ─────────────────────────────────────────────────────
func get_current_right_hand_item() -> GameItem:
	return EquipmentManager.get_equipped_item(active_right_index)

func get_current_left_hand_item() -> GameItem:
	return EquipmentManager.get_equipped_item(active_left_index)

func get_current_quick_use_item() -> GameItem:
	return EquipmentManager.get_equipped_item(active_quick_index)

func get_current_attunement_spell() -> GameItem:
	if active_attunement_index < PlayerStats.attuned_spells.size():
		return PlayerStats.attuned_spells[active_attunement_index]
	return null

# ─── Input ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if Global.is_in_menu: return


	if event.is_action_pressed("cycle_item_down"):
		quick_hold_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("cycle_item_down"):
		if not quick_hold_timer.is_stopped():
			quick_hold_timer.stop()
			_cycle_quick_use()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_up"):
		attunement_hold_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("cycle_item_up"):
		if not attunement_hold_timer.is_stopped():
			attunement_hold_timer.stop()
			_cycle_attunement_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_item"):
		if QuickUseHandler:
			QuickUseHandler.use_current_quick_slot()
			quick_use_changed.emit(active_quick_index)
			get_viewport().set_input_as_handled()
			print("[CrossHUD-DEBUG] X (use_item) pressed → slot ", active_quick_index)
		else:
			push_error("[CrossHUD] QuickUseHandler not found!")

# ─── SMART QUICK-USE CYCLING (strict sequential 2→3→4→5→6, skip empties) ─────
func _cycle_quick_use() -> void:
	var start = active_quick_index
	var attempts = 0
	var max_attempts = 5

	while attempts < max_attempts:
		# Strict sequential increment within 2-6 range
		active_quick_index += 1
		if active_quick_index > 6:
			active_quick_index = 2   # wrap from 6 back to 2

		var item = EquipmentManager.get_equipped_item(active_quick_index)
		if item:
			break
		attempts += 1

	if attempts >= max_attempts:
		active_quick_index = start  # fallback to where we started

	_update_quick_use_slot()
	quick_use_changed.emit(active_quick_index)
	print("[CrossHUD-DEBUG] Cycled quick use → slot ", active_quick_index, " (strict sequential, skipped empties)")

func _on_quick_hold_timeout() -> void:
	# Hold Down → first equipped quick slot (2-6)
	for i in range(2, 7):
		if EquipmentManager.get_equipped_item(i):
			active_quick_index = i
			break
		else:
			active_quick_index = 2  # fallback
	_update_quick_use_slot()
	quick_use_changed.emit(active_quick_index)
	print("[CrossHUD] Hold Down → first equipped quick slot ", active_quick_index)

# ─── Attunement cycling (unchanged) ─────────────────────────────────
func _cycle_attunement_up() -> void:
	if PlayerStats.attunement_slots_unlocked <= 0: return
	var start = active_attunement_index
	var attempts = 0
	var max_slots = PlayerStats.attunement_slots_unlocked
	while attempts < max_slots:
		active_attunement_index = (active_attunement_index + 1) % max_slots
		if active_attunement_index < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[active_attunement_index] != null:
			break
		attempts += 1
	if attempts >= max_slots:
		active_attunement_index = start
	_update_attunement_slot()
	print("[CrossHUD] Cycled attunement → slot ", active_attunement_index, " (skipped empties)")

func _on_attunement_hold_timeout() -> void:
	if PlayerStats.attunement_slots_unlocked > 0:
		active_attunement_index = 0
		while active_attunement_index < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[active_attunement_index] == null:
			active_attunement_index += 1
		if active_attunement_index >= PlayerStats.attunement_slots_unlocked:
			active_attunement_index = 0
	_update_attunement_slot()
	print("[CrossHUD] Hold Up → first filled attunement slot")

# ─── Update functions (unchanged) ───────────────────────────────────
func _update_right_hand_slot() -> void:
	var item = EquipmentManager.get_equipped_item(active_right_index)
	if item:
		right_hand_icon.texture = item.icon
		right_hand_icon.visible = true
		if right_hand_label: right_hand_label.text = item.display_name
	else:
		right_hand_icon.texture = null
		right_hand_icon.visible = false
		if right_hand_label: right_hand_label.text = ""
	_update_ammo_tint_for_bow()   # ← ADD THIS LINE
	_update_attunement_slot()

func _update_left_hand_slot() -> void:
	var item = EquipmentManager.get_equipped_item(active_left_index)
	if item:
		left_hand_icon.texture = item.icon
		left_hand_icon.visible = true
		if left_hand_label: left_hand_label.text = item.display_name
	else:
		left_hand_icon.texture = null
		left_hand_icon.visible = false
		if left_hand_label: left_hand_label.text = ""
	_update_ammo_tint_for_bow()   # ← ADD THIS LINE
	_update_attunement_slot()
	
func _update_quick_use_slot() -> void:
	var item = EquipmentManager.get_equipped_item(active_quick_index)
	
	if item and item.category == "Consumables":
		quick_use_icon.texture = item.icon
		quick_use_icon.visible = true
		
		# === BUILD DISPLAY NAME ===
		var display_text = item.display_name
		
		# Special Estus handling - use the REAL saved potency level from PlayerStats
		if item.id == "estus" or item.display_name.to_lower() == "estus":
			var potency = PlayerStats.estus_heal_level if "estus_heal_level" in PlayerStats else 0
			
			if potency > 0:
				display_text = "Estus +" + str(potency)
			else:
				display_text = "Estus"
			
			print("[CrossHUD-DEBUG] Estus potency from PlayerStats = ", potency, " → QuickSlotLabel: '", display_text, "'")
		
		# Apply to label
		if quick_slot_label:
			quick_slot_label.text = display_text
			quick_slot_label.visible = true
		else:
			print("[CrossHUD-DEBUG] WARNING: quick_slot_label is NULL!")
		
		# === ESTUS SPECIAL HANDLING (your original logic, untouched) ===
		if item.id == "estus" or item.display_name.to_lower() == "estus":
			quick_use_qty.visible = false
			var estus_cont = find_child("EstusContainer", true, false) as Control
			if estus_cont:
				estus_cont.visible = true
		else:
			# Normal consumable
			quick_use_qty.text = str(item.quantity)
			quick_use_qty.visible = true
			var estus_cont = find_child("EstusContainer", true, false) as Control
			if estus_cont:
				estus_cont.visible = false
			
	else:
		# Nothing equipped
		quick_use_icon.visible = false
		quick_use_qty.visible = false
		if quick_slot_label:
			quick_slot_label.visible = false
			quick_slot_label.text = ""
		var estus_cont = find_child("EstusContainer", true, false) as Control
		if estus_cont:
			estus_cont.visible = false

func _update_ammo_display() -> void:
	print("[CrossHUD-DEBUG] _update_ammo_display() CALLED")

	var item1 = EquipmentManager.get_equipped_item(9)
	if item1 and item1.category == "Ammo":
		ammo_slot1_container.visible = true
		ammo_slot1_icon.texture = item1.icon
		ammo_qty1.text = str(item1.quantity)
		ammo_qty1.visible = true
	else:
		ammo_slot1_container.visible = false

	var item2 = EquipmentManager.get_equipped_item(10)
	if item2 and item2.category == "Ammo":
		ammo_slot2_container.visible = true
		ammo_slot2_icon.texture = item2.icon
		ammo_qty2.text = str(item2.quantity)
		ammo_qty2.visible = true
	else:
		ammo_slot2_container.visible = false

func _update_ammo_tint_for_bow() -> void:
	# Check the CURRENTLY ACTIVE hand slot only
	var right_has_bow = EquipmentManager.get_equipped_item(active_right_index) and \
		EquipmentManager.get_equipped_item(active_right_index).weapon_type == "Bow"
	var left_has_bow  = EquipmentManager.get_equipped_item(active_left_index) and \
		EquipmentManager.get_equipped_item(active_left_index).weapon_type == "Bow"
	
	var has_active_bow = right_has_bow or left_has_bow
	var tint = Color(1.0, 0.302, 0.302, 0.365) if not has_active_bow else Color.WHITE
	
	if ammo_slot1_container:
		ammo_slot1_container.modulate = tint
	if ammo_slot2_container:
		ammo_slot2_container.modulate = tint

func _update_attunement_slot() -> void:
	var spell = get_current_attunement_spell()
	if not spell or spell.effect_type != "Cast":
		attunement_icon.texture = null
		attunement_icon.visible = false
		if attunement_label: attunement_label.text = ""
		_update_attunement_tint(false)
		return

	attunement_icon.texture = spell.icon
	attunement_icon.visible = true
	if attunement_label: attunement_label.text = spell.display_name

	# CHECK BOTH HANDS — tint is white if EITHER hand has the correct tool
	var right_tool = EquipmentManager.get_equipped_item(active_right_index)
	var left_tool  = EquipmentManager.get_equipped_item(active_left_index)

	var right_valid = _is_valid_casting_tool(right_tool, spell)
	var left_valid  = _is_valid_casting_tool(left_tool, spell)

	var is_valid = right_valid or left_valid
	_update_attunement_tint(is_valid)

func _update_all_cross_slots() -> void:
	_update_right_hand_slot()
	_update_left_hand_slot()
	_update_quick_use_slot()
	_update_ammo_display()
	_update_attunement_slot()
	_update_ammo_tint_for_bow()   # ← ADD THIS LINE

func _update_attunement_tint(is_valid: bool) -> void:
	var tint = Color(1.0, 0.3, 0.3, 0.85) if not is_valid else Color.WHITE
	if attunement_icon:
		attunement_icon.modulate = tint
	print("[CrossHUD-DEBUG] Attunement tint updated — valid tool = ", is_valid, " | active hand slot = ", 
		  "right" if active_right_index <= 1 else "left")

func _is_valid_casting_tool(tool_item: GameItem, spell: GameItem) -> bool:
	if not tool_item or not spell:
		return false
	
	var tool_type = tool_item.weapon_type
	var spell_type = spell.spell_type
	
	# Heretical can cast anything
	if tool_type == "Heretical":
		return true
	
	# Staff family
	if tool_type == "Staff" and spell_type in ["Sorcery", "Pyromancy", "Hex"]:
		return true
	
	# Chime family - make it more flexible
	if tool_type == "Chime" and spell_type in ["Miracle", "Incantation"]:
		return true
	
	# Extra safety: if the tool name contains "Chime" or the spell name contains "Miracle"
	if "Chime" in tool_type and "Miracle" in spell_type:
		return true
	if "Chime" in tool_type and "Incantation" in spell_type:
		return true
	
	return false

# Public refresh
func refresh() -> void:
	_update_all_cross_slots()

# Public method - call this after loading a save or when closing CharacterMenu
func force_full_refresh() -> void:
	_update_all_cross_slots()
	_update_ammo_display()
	_update_attunement_slot()
	_update_ammo_tint_for_bow()
	print("[CrossHUD] Force full refresh called")

func _process(_delta: float) -> void:
	if Global.is_in_menu or not visible:
		return

	# Hand cycling - moved here for reliability after save/load
	if Input.is_action_just_pressed("cycle_right_hand"):
		active_right_index = 1 if active_right_index == 0 else 0
		_update_right_hand_slot()
		_update_ammo_tint_for_bow()
		print("[CrossHUD] Cycled RIGHT hand → slot ", active_right_index)

	if Input.is_action_just_pressed("cycle_left_hand"):
		active_left_index = 8 if active_left_index == 7 else 7
		_update_left_hand_slot()
		_update_ammo_tint_for_bow()
		print("[CrossHUD] Cycled LEFT hand → slot ", active_left_index)
