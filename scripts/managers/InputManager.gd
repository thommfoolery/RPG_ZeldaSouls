# autoload/InputManager.gd
extends Node

# ─── Configurable ───────────────────────────────────────────────────────
@export var tap_threshold: float = 0.18
@export var deadzone: float = 0.2

# ─── State ──────────────────────────────────────────────────────────────
var evade_press_time: float = -1.0
var evade_held: bool = false
var right_heavy_press_time: float = -1.0
var last_move_dir: Vector2 = Vector2.RIGHT

# ─── SIGNALS ────────────────────────────────────────────────────────────
signal right_hand_primary(charge_time: float)
signal right_hand_heavy(charge_time: float)
signal left_hand_primary(charge_time: float)
signal left_hand_heavy(charge_time: float)
signal use_item_pressed()
signal cycle_item_up()
signal cycle_item_down()
signal cycle_right_hand()
signal cycle_left_hand()
signal two_hand_toggle()
signal evade_or_sprint_tap(dir: Vector2)
signal sprint_toggled(held: bool)
signal interact_pressed()
signal estus_pressed()
signal attack_pressed()
signal lock_on_pressed()
signal menu_toggled()
signal direction_changed(new_dir: Vector2)
signal backstep_pressed()
signal dodge_pressed(direction: Vector2)

# ─── Blocking ───────────────────────────────────────────────────────────
var input_blocked: bool = false: set = _set_blocked

func _set_blocked(value: bool) -> void:
	input_blocked = value
	print("[InputManager] Input blocked = ", value)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[InputManager] FINAL hand-slot + D-pad + direction system online")

func _process(delta: float) -> void:
	if Global.is_in_menu:
		evade_held = false
		evade_press_time = -1.0
		right_heavy_press_time = -1.0
		direction_changed.emit(Vector2.ZERO)
		update_move_direction(Vector2.ZERO)
		return

	var raw_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction_changed.emit(raw_dir)
	update_move_direction(raw_dir)

	# Right heavy charge
	var heavy_pressed = Input.is_action_pressed("right_hand_heavy")
	if heavy_pressed and right_heavy_press_time < 0:
		right_heavy_press_time = Time.get_ticks_msec() / 1000.0
	elif not heavy_pressed and right_heavy_press_time >= 0:
		var charge = (Time.get_ticks_msec() / 1000.0) - right_heavy_press_time
		right_hand_heavy.emit(charge)
		right_heavy_press_time = -1.0

	# Sprint hold
	var sprint_held_now = Input.is_action_pressed("evade_or_sprint")
	if sprint_held_now != evade_held:
		evade_held = sprint_held_now
		sprint_toggled.emit(evade_held)


func update_move_direction(dir: Vector2) -> void:
	if dir.length_squared() > 0.01:
		last_move_dir = dir.normalized()


func _input(event: InputEvent) -> void:
	# ─── ALLOW UI NAVIGATION WHEN MENU IS OPEN ─────────────────────────────
	if Global.is_in_menu:
		# Let Godot handle all standard UI actions (D-pad, A, B)
		if event.is_action("ui_up") or event.is_action("ui_down") or \
		   event.is_action("ui_left") or event.is_action("ui_right") or \
		   event.is_action("ui_accept") or event.is_action("ui_cancel"):
			return   # Do NOT set as handled - let the focused Control use it

		# Block everything else (attacks, interact, etc.)
		get_viewport().set_input_as_handled()
		return

	# ─── Normal gameplay input ─────────────────────────────────────────────
	if event.is_action_pressed("menu_pause") or event.is_action_pressed("ui_unicode_start"):
		get_viewport().set_input_as_handled()
		var menu = get_tree().get_first_node_in_group("character_menu")
		if menu:
			menu.visible = not menu.visible
			Global.is_in_menu = menu.visible
			input_blocked = menu.visible
			print("[InputManager] CharacterMenu toggled: ", "OPEN" if menu.visible else "CLOSED")
		return

	if input_blocked and not event.is_action_pressed("menu_pause"):
		return

	if event.is_action_pressed("menu_pause"):
		menu_toggled.emit()
	elif event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("use_item"):
		use_item_pressed.emit()
	elif event.is_action_pressed("right_hand_primary"):
		right_hand_primary.emit()
	elif event.is_action_pressed("right_hand_heavy"):   
		right_hand_heavy.emit()
	elif event.is_action_pressed("left_hand_primary"):
		left_hand_primary.emit()
	elif event.is_action_pressed("left_hand_heavy"):
		left_hand_heavy.emit()
	elif event.is_action_pressed("cycle_item_up"):
		cycle_item_up.emit()
	elif event.is_action_pressed("cycle_item_down"):
		cycle_item_down.emit()
	elif event.is_action_pressed("cycle_right_hand"):
		cycle_right_hand.emit()
	elif event.is_action_pressed("cycle_left_hand"):
		cycle_left_hand.emit()
	elif event.is_action_pressed("two_hand_toggle"):
		two_hand_toggle.emit()
	elif event.is_action_pressed("lock_on"):
		lock_on_pressed.emit()
