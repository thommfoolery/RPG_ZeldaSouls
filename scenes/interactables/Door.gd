# scripts/interactables/Door.gd
extends StaticBody2D

@export_enum("horizontal", "vertical") var orientation: String = "horizontal"
@export var door_id: String = "door_temp_001"           # MUST be unique per door instance
@export var is_locked: bool = false
@export var required_key_id: String = ""                # only checked if is_locked = true

@onready var h_closed: Sprite2D   = $HClosed
@onready var h_open:   Sprite2D   = $HOpen
@onready var v_closed: Sprite2D   = $VClosed
@onready var v_open:   Sprite2D   = $VOpen

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label      = $PromptLabel

var player_in_range: bool = false
var is_open: bool = false

func _ready() -> void:
	# ─── Safety: hide everything first ───
	_hide_all_sprites()
	
	# ─── Load persistent state from WorldStateManager ───
	if WorldStateManager and WorldStateManager.is_permanent("opened_doors", door_id):
		_set_open_state(true)  # silent = true
		print("[Door-DEBUG] Loaded as ALREADY OPEN → ", door_id)
	else:
		_set_closed_state()
		print("[Door-DEBUG] Loaded as CLOSED → ", door_id, " | orientation=", orientation)
	
	# ─── Connect body signals ───
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	else:
		push_error("[Door] CRITICAL: InteractionArea missing on ", door_id)
	
	# ─── Connect to global InputManager signal (preferred over _input()) ───
	if InputManager:
		InputManager.interact_pressed.connect(_on_interact_pressed)
		print("[Door-DEBUG] Connected to InputManager.interact_pressed for ", door_id)
	else:
		push_error("[Door] InputManager autoload missing — door won't respond to interact!")
	
	# Start with prompt hidden
	if prompt_label:
		prompt_label.visible = false

func _hide_all_sprites() -> void:
	if h_closed: h_closed.visible = false
	if h_open:   h_open.visible   = false
	if v_closed: v_closed.visible = false
	if v_open:   v_open.visible   = false

func _set_closed_state() -> void:
	_hide_all_sprites()
	if orientation == "horizontal":
		if h_closed: h_closed.visible = true
	else:
		if v_closed: v_closed.visible = true
	
	collision_layer = 1  # adjust to your actual door/wall layer
	is_open = false
	print("[Door-DEBUG] Set closed visual state → ", door_id)

func _set_open_state(silent: bool = false) -> void:
	_hide_all_sprites()
	if orientation == "horizontal":
		if h_open: h_open.visible = true
	else:
		if v_open: v_open.visible = true
	
	collision_layer = 0  # pass-through
	is_open = true
	
	if not silent:
		print("[Door] PERMANENTLY OPENED → ", door_id)
		# TODO: sound, particles, camera shake, etc.
	
	# Save the permanent state
	if WorldStateManager:
		WorldStateManager.mark_permanent("opened_doors", door_id)
	else:
		push_warning("[Door] WorldStateManager missing — open state NOT persisted!")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_prompt()
		print("[Door-DEBUG] PLAYER ENTERED RANGE → ", door_id, " | pos=", body.global_position.round())

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false
		print("[Door-DEBUG] PLAYER LEFT RANGE → ", door_id)

func _on_interact_pressed() -> void:
	if not player_in_range:
		# print("[Door-DEBUG] Interact pressed but player NOT in range → ignoring ", door_id)
		return
	
	print("[Door-DEBUG] INTERACT PRESSED WHILE IN RANGE → ", door_id)
	
	if is_open:
		print("[Door-DEBUG] Already open — ignoring interact")
		return
	
	if is_locked:
		if _player_has_key():
			print("[Door-DEBUG] Key check passed → opening ", door_id)
			_set_open_state()
		else:
			print("[Door] LOCKED — missing key: ", required_key_id)
			# TODO: play locked sound, show message, flash prompt red, etc.
	else:
		print("[Door-DEBUG] Unlocked door → opening ", door_id)
		_set_open_state()

func _player_has_key() -> bool:
	if required_key_id.is_empty():
		return true
	
	var keys = PlayerInventory.inventory.get("Keys", [])
	for item in keys:
		if item and item.id == required_key_id:
			print("[Door-DEBUG] Found required key in inventory: ", required_key_id)
			return true
	
	print("[Door-DEBUG] Key not found in inventory: ", required_key_id)
	return false

func _update_prompt() -> void:
	if not prompt_label:
		push_warning("[Door] PromptLabel missing on ", door_id)
		return
	
	if not player_in_range or is_open:
		prompt_label.visible = false
		return
	
	prompt_label.text = "Locked" if is_locked else "Press A"
	prompt_label.visible = true
	
	# ─── Better: Keep label upright relative to screen (recommended) ───
	# Option A: No rotation at all (simplest, usually looks fine)
	# prompt_label.rotation = 0.0   # local rotation only
	
	# Option B: Counter-rotate to camera if your camera ever rotates (rare in top-down)
	# if get_viewport().get_camera_2d():
	#     prompt_label.global_rotation = -get_viewport().get_camera_2d().global_rotation
	
	# Position above door (tweak offset to taste)
	prompt_label.global_position = global_position + Vector2(0, -32)
