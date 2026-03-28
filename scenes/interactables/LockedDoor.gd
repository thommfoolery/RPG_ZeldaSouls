# scripts/interactables/LootChest.gd
extends StaticBody2D

@export var chest_id: String = "chest_temp_001"
@export var linked_item_pickup_id: String = ""
@export var is_one_time_loot: bool = true

@onready var closed_sprite: Sprite2D = $ClosedSprite
@onready var open_sprite: Sprite2D   = $OpenSprite
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt: Label = $PromptLabel

var player_in_range: bool = false
var is_opened: bool = false

func _ready() -> void:
	# Default to closed first
	_set_closed_state()
	
	# Then restore permanent state if it was opened before
	if WorldStateManager and WorldStateManager.is_permanent("opened_chests", chest_id):
		_open_chest(true)   # silent = true
		print("[Chest] Loaded as OPEN (persistent) → ", chest_id)
	else:
		print("[Chest] Loaded as CLOSED → ", chest_id)
	
	# Connections
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	
	if InputManager:
		InputManager.interact_pressed.connect(_on_interact_pressed)
	
	if prompt:
		prompt.visible = false
		prompt.modulate.a = 1.0

# ────────────────────────────────────────────────────────────────
func _set_closed_state() -> void:
	closed_sprite.visible = true
	open_sprite.visible = false
	collision_layer = 1
	is_opened = false
	print("[Chest-DEBUG] Set CLOSED visual state → ", chest_id)

func _open_chest(silent: bool = false) -> void:
	is_opened = true
	closed_sprite.visible = false
	open_sprite.visible = true
	collision_layer = 0
	
	# Smooth prompt fade out
	if prompt and prompt.visible:
		var tween = create_tween()
		tween.tween_property(prompt, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func(): prompt.visible = false)
	
	if not silent:
		print("[Chest] CHEST OPENED → ", chest_id)
	
	if WorldStateManager:
		WorldStateManager.mark_permanent("opened_chests", chest_id)

# ────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_update_prompt()
		print("[Chest-DEBUG] Player ENTERED range → ", chest_id)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_update_prompt()

func _on_interact_pressed() -> void:
	if not player_in_range or is_opened:
		return
	
	print("[Chest-DEBUG] Interact pressed while in range → ", chest_id)
	_open_chest()
	_enable_linked_loot()

func _enable_linked_loot() -> void:
	if linked_item_pickup_id.is_empty():
		return
	
	print("[Chest-DEBUG] Looking for pickup ID: ", linked_item_pickup_id)
	
	var all_pickups = get_tree().get_nodes_in_group("item_pickups")
	for pickup in all_pickups:
		if pickup.pickup_id == linked_item_pickup_id:
			pickup.enable()
			print("[Chest] Loot revealed → ", linked_item_pickup_id)
			return
	
	push_warning("[Chest] Could not find linked pickup: " + linked_item_pickup_id)

func _update_prompt() -> void:
	if not prompt:
		return
	
	if not player_in_range or is_opened:
		if prompt.visible:
			var tween = create_tween()
			tween.tween_property(prompt, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func(): prompt.visible = false)
		return
	
	prompt.text = "Press A to open"
	prompt.visible = true
	prompt.modulate.a = 1.0
