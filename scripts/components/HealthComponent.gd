# scripts/components/HealthComponent.gd
extends Node
class_name HealthComponent

var max_health: float = 122.0
var current_health: float = 122.0
var is_invincible: bool = false

signal health_changed(current: float, max: float)
signal died()

func _ready() -> void:
	if StatCalculator:
		max_health = StatCalculator.get_max_health(PlayerStats.vitality)
	else:
		max_health = 122.0
	
	if Global and Global.current_health > 0:
		current_health = clamp(Global.current_health, 0, max_health)
	else:
		current_health = max_health
	
	health_changed.emit(current_health, max_health)
	print("[HealthComponent] Initialized — Max HP = ", max_health, " | Current HP = ", current_health)
	
	# Safe delayed update
	call_deferred("_update_dynamic_bar")


func _enter_tree() -> void:
	# Extra safety for when player is added to the scene
	call_deferred("_update_dynamic_bar")


func grant_iframes(duration: float = 0.5) -> void:
	is_invincible = true
	await get_tree().create_timer(duration).timeout
	is_invincible = false


func take_damage(amount: float) -> bool:
	if is_invincible or current_health <= 0:
		return false

	current_health -= amount
	current_health = max(current_health, 0.0)
	Global.current_health = current_health

	var anim = get_parent().get_node_or_null("AnimationComponent")
	if anim:
		anim.flash_damage()
		anim.flash_impact_damage()

	health_changed.emit(current_health, max_health)
	call_deferred("_update_dynamic_bar")

	if current_health <= 0:
		died.emit()
		return false

	return true


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	Global.current_health = current_health
	health_changed.emit(current_health, max_health)
	call_deferred("_update_dynamic_bar")


func get_normalized() -> float:
	return current_health / max_health if max_health > 0 else 0.0


# ── Dynamic Bar Growth ─────────────────────────────────────────────
func _update_dynamic_bar() -> void:
	if not is_inside_tree():
		return
	
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		print("[Health DEBUG] HUD not found in group 'hud'")
		return
	
	var dynamic_bar = hud.get_node_or_null("HUDContainer/HealthBar/DynamicStatBar") as DynamicStatBar
	if dynamic_bar:
		dynamic_bar.update_bar(max_health)
		print("[Health DEBUG] Called DynamicStatBar.update_bar with max = ", max_health)
	else:
		print("[Health DEBUG] Could not find DynamicStatBar at HUDContainer/HealthBar/DynamicStatBar")
