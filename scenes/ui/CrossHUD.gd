# ui/hud/CrossHUD.gd
extends Control
class_name CrossHUD

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

# ─── State ──────────────────────────────────────────────────────────
var active_right_index: int = 0
var active_left_index: int = 7
var active_quick_index: int = 2
var active_attunement_index: int = 0

var quick_hold_timer: Timer
var attunement_hold_timer: Timer

func _ready() -> void:
	# Timers
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

	# Connect to EquipmentManager
	if EquipmentManager:
		EquipmentManager.equipped_changed.connect(_on_equipped_changed)
		print("[CrossHUD] Connected to EquipmentManager.equipped_changed")
	# Safe initial update (fresh game protection)
	_update_all_cross_slots()

# ─── Signal handler for equipment changes ───────────────────────────
func _on_equipped_changed(slot_index: int, _new_item: GameItem) -> void:
	print("[CrossHUD] equipped_changed received for slot ", slot_index, " — refreshing cross")
	_update_all_cross_slots()

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

	if event.is_action_pressed("cycle_right_hand"):
		active_right_index = 1 if active_right_index == 0 else 0
		_update_right_hand_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_left_hand"):
		active_left_index = 8 if active_left_index == 7 else 7
		_update_left_hand_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_down"):
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

# ─── Hold timers & cycles ───────────────────────────────────────────
func _on_quick_hold_timeout() -> void:
	active_quick_index = 2
	_update_quick_use_slot()
	print("[CrossHUD] Hold Down → first quick use slot")

func _on_attunement_hold_timeout() -> void:
	if PlayerStats.attunement_slots_unlocked > 0:
		active_attunement_index = 0
		while active_attunement_index < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[active_attunement_index] == null:
			active_attunement_index += 1
		if active_attunement_index >= PlayerStats.attunement_slots_unlocked:
			active_attunement_index = 0
		_update_attunement_slot()
		print("[CrossHUD] Hold Up → first filled attunement slot")

func _cycle_quick_use() -> void:
	active_quick_index = (active_quick_index + 1) % 5 + 2
	_update_quick_use_slot()
	print("[CrossHUD] Cycled quick use to slot ", active_quick_index)

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

# ─── Update functions ───────────────────────────────────────────────
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

func _update_quick_use_slot() -> void:
	var item = EquipmentManager.get_equipped_item(active_quick_index)
	if item and item.category == "Consumables":
		quick_use_icon.texture = item.icon
		quick_use_icon.visible = true
		quick_use_qty.text = str(item.quantity)
		quick_use_qty.visible = true
	else:
		quick_use_icon.texture = null
		quick_use_icon.visible = false
		quick_use_qty.text = ""
		quick_use_qty.visible = false

func _update_ammo_display() -> void:
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

func _update_attunement_slot() -> void:
	var item = null
	if active_attunement_index < PlayerStats.attuned_spells.size():
		item = PlayerStats.attuned_spells[active_attunement_index]

	if item == null:
		for i in PlayerStats.attunement_slots_unlocked:
			if i < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[i] != null:
				active_attunement_index = i
				item = PlayerStats.attuned_spells[i]
				break

	if item:
		attunement_icon.texture = item.icon
		attunement_icon.visible = true
		if attunement_label: attunement_label.text = item.display_name
	else:
		attunement_icon.texture = null
		attunement_icon.visible = false
		if attunement_label: attunement_label.text = ""

func _update_all_cross_slots() -> void:
	_update_right_hand_slot()
	_update_left_hand_slot()
	_update_quick_use_slot()
	_update_ammo_display()
	_update_attunement_slot()

# Public refresh
func refresh() -> void:
	_update_all_cross_slots()
