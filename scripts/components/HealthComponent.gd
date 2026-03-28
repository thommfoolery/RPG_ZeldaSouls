# scripts/components/HealthComponent.gd
extends Node
class_name HealthComponent

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_invincible: bool = false

signal health_changed(current: float, max: float)
signal died()

func _ready() -> void:
	if Global:
		current_health = Global.current_health
		print("[Health-DEBUG] Loaded persisted health from Global: ", current_health)
		health_changed.emit(current_health, max_health)

func _process(delta: float) -> void:
	pass  # No longer needed for i-frames

# Single source of truth for temporary invincibility
func grant_iframes(duration: float = 0.5) -> void:
	is_invincible = true
	print("[HealthComponent] I-frames granted for ", duration, " seconds")
	
	await get_tree().create_timer(duration).timeout
	
	is_invincible = false
	print("[HealthComponent] I-frames ended")

# Returns true if damage was actually applied
func take_damage(amount: float) -> bool:
	if is_invincible or current_health <= 0:
		print("[Health] Ignored damage — invincible or already dead")
		return false

	current_health -= amount
	current_health = max(current_health, 0.0)

	# Flash red
	var anim = get_parent().get_node_or_null("AnimationComponent")
	if anim and anim.has_method("flash_damage"):
		anim.flash_damage()
		anim.flash_impact_damage()

	Global.current_health = current_health
	print("[Health] Took ", amount, " damage → ACTUAL current: ", current_health)

	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		print("[Health] HP <= 0 → EMITTING died!")
		died.emit()
		return false

	return true

# Healing
func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	Global.current_health = current_health
	health_changed.emit(current_health, max_health)

func get_normalized() -> float:
	return current_health / max_health if max_health > 0 else 0.0
