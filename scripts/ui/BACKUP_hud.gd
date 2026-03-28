# ui/hud.gd
extends CanvasLayer

# ─── Existing nodes ─────────────────────────────────────────────────
@onready var souls_label: Label = %SoulsLabel
@onready var estus_label: Label = %EstusLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var saving_icon: Control = $SavingIcon
@onready var saving_label: Label = $SavingIcon/Label
@onready var mana_bar: ProgressBar = %ManaBar

# ─── Cross Menu Nodes ───────────────────────────────────────────────
# Right Hand
@onready var right_hand_icon: TextureRect = $QuickUseCross/RightHandSlot/RightHandIcon
@onready var right_hand_label: Label = $QuickUseCross/RightHandSlot/RightHandLabel
# Left Hand
@onready var left_hand_icon: TextureRect = $QuickUseCross/LeftHandSlot/LeftHandIcon
@onready var left_hand_label: Label = $QuickUseCross/LeftHandSlot/LeftHandLabel
# Bottom Quick Use
@onready var quick_use_icon: TextureRect = $QuickUseCross/BottomSlot/QuickUseIcon
@onready var quick_use_qty: Label = $QuickUseCross/BottomSlot/DownQuantityLabel
# Ammo Slots
@onready var ammo_slot1_container: Control = $QuickUseCross/AmmoSlot1
@onready var ammo_slot1_icon: TextureRect = $QuickUseCross/AmmoSlot1/AmmoIcon1
@onready var ammo_qty1: Label = $QuickUseCross/AmmoSlot1/AmmoQuantityLabel1
@onready var ammo_slot2_container: Control = $QuickUseCross/AmmoSlot2
@onready var ammo_slot2_icon: TextureRect = $QuickUseCross/AmmoSlot2/AmmoIcon2
@onready var ammo_qty2: Label = $QuickUseCross/AmmoSlot2/AmmoQuantityLabel2
# Attunement Spell Display (Top of the cross)
@onready var attunement_icon: TextureRect = $QuickUseCross/AttunementSlot/AttunementIcon
@onready var attunement_label: Label = $QuickUseCross/AttunementSlot/AttunementLabel

# ─── Component references ───────────────────────────────────────────
var stamina_component: StaminaComponent
var health_component: HealthComponent

# ─── Cross Menu State ───────────────────────────────────────────────
var active_right_index: int = 0
var active_left_index: int = 7
var active_quick_index: int = 2
var active_attunement_index: int = 0

var quick_hold_timer: Timer
var attunement_hold_timer: Timer   # NEW for Up hold

func _ready() -> void:
	print("[HUD] _ready() | Instance:", get_instance_id(), " | Path:", get_path())
	await get_tree().process_frame
	_connect_to_player_manager()
	saving_icon.visible = false
	saving_icon.modulate.a = 0.0

	if EquipmentManager:
		EquipmentManager.equipped_changed.connect(_on_equipped_changed)
		print("[HUD-AMMO] Connected to EquipmentManager")

	if PlayerStats:
		PlayerStats.estus_changed.connect(_on_estus_changed)
		_on_estus_changed(PlayerStats.current_estus)
		if not PlayerStats.attunement_changed.is_connected(_on_attunement_changed):
			PlayerStats.attunement_changed.connect(_on_attunement_changed)

	# Quick use hold timer
	quick_hold_timer = Timer.new()
	quick_hold_timer.wait_time = 0.5
	quick_hold_timer.one_shot = true
	quick_hold_timer.timeout.connect(_on_quick_hold_timeout)
	add_child(quick_hold_timer)

	# NEW: Attunement hold timer (Up on D-pad)
	attunement_hold_timer = Timer.new()
	attunement_hold_timer.wait_time = 0.5
	attunement_hold_timer.one_shot = true
	attunement_hold_timer.timeout.connect(_on_attunement_hold_timeout)
	add_child(attunement_hold_timer)

	_update_all_cross_slots()



func _on_attunement_changed() -> void:
	print("[HUD] attunement_changed received — refreshing top slot")
	_update_attunement_slot()   # will snap to next filled slot if needed

func _on_equipped_changed(slot_index: int, _new_item: GameItem) -> void:
	_update_all_cross_slots()

# ─── Input ──────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if Global.is_in_menu: return

	# Right Hand cycle
	if event.is_action_pressed("cycle_right_hand"):
		active_right_index = 1 if active_right_index == 0 else 0
		_update_right_hand_slot()
		get_viewport().set_input_as_handled()

	# Left Hand cycle
	elif event.is_action_pressed("cycle_left_hand"):
		active_left_index = 8 if active_left_index == 7 else 7
		_update_left_hand_slot()
		get_viewport().set_input_as_handled()

	# Quick Use - Tap vs Hold
	elif event.is_action_pressed("cycle_item_down"):
		quick_hold_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("cycle_item_down"):
		if not quick_hold_timer.is_stopped():
			quick_hold_timer.stop()
			_cycle_quick_use()
		get_viewport().set_input_as_handled()

	# Attunement - Tap vs Hold (Up on D-pad)
	elif event.is_action_pressed("cycle_item_up"):
		attunement_hold_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("cycle_item_up"):
		if not attunement_hold_timer.is_stopped():
			attunement_hold_timer.stop()
			_cycle_attunement_up()   # tap = cycle to next filled
		get_viewport().set_input_as_handled()

# ─── Hold Timers ────────────────────────────────────────────────────
func _on_quick_hold_timeout() -> void:
	active_quick_index = 2
	_update_quick_use_slot()
	print("[HUD] Hold Down → selected first quick use slot")

func _on_attunement_hold_timeout() -> void:
	# Hold Up → jump to first filled attunement slot
	if PlayerStats.attunement_slots_unlocked > 0:
		active_attunement_index = 0
		# Snap to the first actually filled slot
		while active_attunement_index < PlayerStats.attuned_spells.size() and PlayerStats.attuned_spells[active_attunement_index] == null:
			active_attunement_index += 1
		if active_attunement_index >= PlayerStats.attunement_slots_unlocked:
			active_attunement_index = 0  # fallback
		_update_attunement_slot()
		print("[HUD] Hold Up → jumped to first filled attunement slot")

# ─── Cycle functions ────────────────────────────────────────────────
func _cycle_quick_use() -> void:
	active_quick_index = (active_quick_index + 1) % 5 + 2
	_update_quick_use_slot()
	print("[HUD] Cycled quick use to slot ", active_quick_index)

func _cycle_attunement_up() -> void:
	if PlayerStats.attunement_slots_unlocked <= 0:
		return

	var start = active_attunement_index
	var attempts = 0
	var max_slots = PlayerStats.attunement_slots_unlocked

	while attempts < max_slots:
		active_attunement_index = (active_attunement_index + 1) % max_slots
		if active_attunement_index < PlayerStats.attuned_spells.size() and \
		   PlayerStats.attuned_spells[active_attunement_index] != null:
			break
		attempts += 1

	if attempts >= max_slots:
		active_attunement_index = start

	_update_attunement_slot()
	print("[HUD] Cycled attunement → slot ", active_attunement_index, " (skipped empties)")

# ─── Update Functions ───────────────────────────────────────────────
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
	# Smart: always show a filled slot if one exists
	var item = null
	if active_attunement_index < PlayerStats.attuned_spells.size():
		item = PlayerStats.attuned_spells[active_attunement_index]

	# If current slot is empty, find the next filled one
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

func _connect_to_player_manager() -> void:
	if PlayerManager:
		if not PlayerManager.player_changed.is_connected(_on_player_changed):
			PlayerManager.player_changed.connect(_on_player_changed)
		if PlayerManager.current_player and is_instance_valid(PlayerManager.current_player):
			_connect_to_current_player()
		else:
			push_warning("[HUD] PlayerManager autoload not found!")

func _on_player_changed(new_player: Node) -> void:
	if new_player and is_instance_valid(new_player):
		_connect_to_current_player()

func _connect_to_current_player() -> void:
	var player = PlayerManager.current_player
	if not player or not is_instance_valid(player):
		print("[HUD] No valid current player — skipping")
		return

	# Safe disconnect old components
	if health_component and is_instance_valid(health_component) and health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.disconnect(_on_health_changed)
	if stamina_component and is_instance_valid(stamina_component) and stamina_component.stamina_changed.is_connected(_on_stamina_changed):
		stamina_component.stamina_changed.disconnect(_on_stamina_changed)

	health_component = null
	stamina_component = null

	health_component = player.get_node_or_null("HealthComponent")
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		_update_health_bar()
	else:
		push_warning("[HUD] HealthComponent not found")

	stamina_component = player.get_node_or_null("StaminaComponent")
	if stamina_component:
		stamina_component.stamina_changed.connect(_on_stamina_changed)
		_update_stamina_bar()
	else:
		push_warning("[HUD] StaminaComponent not found")

	var mana_component = player.get_node_or_null("ManaComponent")
	if mana_component:
		mana_component.mana_changed.connect(_on_mana_changed)
		_on_mana_changed(mana_component.current_mana, mana_component.max_mana)
	else:
		push_warning("[HUD] ManaComponent not found on player")

	if PlayerStats:
		if not PlayerStats.souls_changed.is_connected(_on_souls_changed):
			PlayerStats.souls_changed.connect(_on_souls_changed)
		if not PlayerStats.estus_changed.is_connected(_on_estus_changed):
			PlayerStats.estus_changed.connect(_on_estus_changed)
		if not PlayerStats.attunement_changed.is_connected(_on_attunement_changed):
			PlayerStats.attunement_changed.connect(_on_attunement_changed)

		_update_souls()
		_update_estus()

	print("[HUD] Successfully (re)connected to current player and all signals")
	_update_all_cross_slots()   # Force immediate refresh on connect

func _on_health_changed(current: float, max_health: float) -> void:
	_update_health_bar()

func _update_health_bar() -> void:
	if not health_bar: return
	if health_component:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.current_health
		print("[HUD] Health bar updated → ", health_bar.value, "/", health_bar.max_value)
	else:
		health_bar.value = 200.0

func _on_stamina_changed(current: float, max_stamina: float) -> void:
	_update_stamina_bar()

func _update_stamina_bar() -> void:
	if not stamina_bar: return
	if stamina_component:
		stamina_bar.max_value = stamina_component.max_stamina
		stamina_bar.value = stamina_component.current_stamina
	else:
		stamina_bar.value = 100.0

func _on_mana_changed(current: float, max_mana: float) -> void:
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current

func _on_souls_changed(_new: int) -> void:
	_update_souls()

func _update_souls() -> void:
	if souls_label and PlayerStats:
		souls_label.text = "Souls: %d" % PlayerStats.souls_carried

func _on_estus_changed(_new: int) -> void:
	_update_estus()

func _update_estus() -> void:
	if not estus_label or not PlayerStats: return
	estus_label.text = "%d/%d" % [PlayerStats.estus_charges, PlayerStats.max_estus]
	if PlayerStats.estus_charges >= PlayerStats.max_estus:
		estus_label.modulate = Color(1.0, 0.665, 0.161, 1.0)
	elif PlayerStats.estus_charges > 0:
		estus_label.modulate = Color(0.95, 0.95, 1.0)
	else:
		estus_label.modulate = Color(0.537, 0.0, 0.082, 1.0)

func show_saving_icon() -> void:
	if not saving_icon: return
	saving_icon.visible = true
	saving_label.text = "Saving..."
	var tween = create_tween()
	tween.tween_property(saving_icon, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(1.4).timeout
	tween = create_tween()
	tween.tween_property(saving_icon, "modulate:a", 0.0, 0.3)
	await tween.finished
	saving_icon.visible = false
