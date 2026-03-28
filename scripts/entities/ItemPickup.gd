# res://scripts/entities/ItemPickup.gd
extends Area2D
class_name ItemPickup

@export var item: GameItem = null
@export var quantity: int = 1
@export var pickup_id: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

var player_in_range: bool = false

func _ready() -> void:
	if not item:
		push_warning("[ItemPickup] No item assigned to ", name)
		return
	
	if pickup_id.is_empty():
		push_error("[ItemPickup] pickup_id is empty on " + name + "! This item will not persist.")
	
	# Smart starting state
	if pickup_id.begins_with("chest_"):
		disable()        # Chest loot starts hidden
		print("[ItemPickup] Chest loot detected → starting DISABLED: ", pickup_id)
	else:
		enable()         # Normal ground loot starts visible
		print("[ItemPickup] Normal ground loot → starting ENABLED: ", pickup_id)
	
	# Check if already taken (for persistence)
	call_deferred("check_if_already_taken")

func check_if_already_taken() -> void:
	if pickup_id.is_empty():
		return
	
	if WorldStateManager and WorldStateManager.has_taken_item(pickup_id):
		print("[ItemPickup] Already taken on load → removing ", pickup_id)
		queue_free()
		return

func enable() -> void:
	visible = true
	if interaction_area and interaction_area.has_node("CollisionShape2D"):
		interaction_area.get_node("CollisionShape2D").disabled = false
	print("[ItemPickup] ENABLED → ", pickup_id)

func disable() -> void:
	visible = false
	if interaction_area and interaction_area.has_node("CollisionShape2D"):
		interaction_area.get_node("CollisionShape2D").disabled = true
	print("[ItemPickup] DISABLED → ", pickup_id)

# ─── Interaction ───
func _input(event: InputEvent) -> void:
	if not player_in_range or not item or pickup_id.is_empty():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		
		WorldStateManager.mark_taken_item(pickup_id)
		PlayerInventory.add_item(item, quantity)
		UIManager.show_pickup_notification(item, quantity)
		
		print("[ItemPickup] Picked up: ", item.display_name, " | ID: ", pickup_id)
		queue_free()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		UIManager.show_interact_prompt("Pick up " + item.display_name)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		UIManager.hide_interact_prompt()
