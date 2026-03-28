# test_dummy.gd
extends CharacterBody2D

@export var unique_id: String = "test_dummy_001"   # ← must be unique per placed instance

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("enemies")
	
	if not unique_id.strip_edges():
		push_warning("[TestDummy] No unique_id set — death will NOT persist!")
	
	# Already dead in this save? → remove immediately
	if WorldStateManager and WorldStateManager.is_regular_dead(unique_id):
		print("[TestDummy] Already killed in save → removing ", unique_id)
		queue_free()
		return
	
	if health:
		health.died.connect(_on_died)
	else:
		push_error("[TestDummy] Missing HealthComponent!")

func _on_died() -> void:
	if WorldStateManager:
		WorldStateManager.mark_regular_dead(unique_id)
		print("[TestDummy] Death registered → ", unique_id)
	
	# Optional: death VFX / sound / particles here later
	queue_free()
