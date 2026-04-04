# scripts/components/StaminaComponent.gd
extends Node
class_name StaminaComponent

@export var regen_rate: float = 30.0
@export var regen_delay: float = 1.5

var max_stamina: float = 90.0
var current_stamina: float = 90.0
var time_since_last_drain: float = 0.0

signal stamina_changed(current: float, max_stamina: float)

func _ready() -> void:
	if StatCalculator:
		max_stamina = StatCalculator.get_max_stamina(PlayerStats.endurance)
	else:
		max_stamina = 90.0
	
	if Global:
		current_stamina = clamp(Global.current_stamina, 0, max_stamina)
		print("[Feature-DEBUG] Stamina loaded from Global → ", current_stamina)
	else:
		current_stamina = max_stamina
	
	stamina_changed.emit(current_stamina, max_stamina)
	call_deferred("_update_dynamic_bar")   # ← This was missing


func _enter_tree() -> void:
	call_deferred("_update_dynamic_bar")


func _process(delta: float) -> void:
	if current_stamina < max_stamina:
		if time_since_last_drain >= regen_delay:
			var regen_this_frame = regen_rate * delta
			current_stamina = min(current_stamina + regen_this_frame, max_stamina)
			stamina_changed.emit(current_stamina, max_stamina)
			if Global:
				Global.current_stamina = current_stamina
	
	time_since_last_drain += delta


func drain(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		time_since_last_drain = 0.0
		stamina_changed.emit(current_stamina, max_stamina)
		if Global:
			Global.current_stamina = current_stamina
		call_deferred("_update_dynamic_bar")   # ← Force update
		return true
	return false


func get_normalized() -> float:
	return current_stamina / max_stamina if max_stamina > 0 else 0.0


# ── Dynamic Bar Growth ─────────────────────────────────────────────
func _update_dynamic_bar() -> void:
	if not is_inside_tree():
		return
	
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	
	var dynamic_bar = hud.get_node_or_null("HUDContainer/StaminaBar/DynamicStaminaBar") as DynamicStatBar
	if dynamic_bar:
		dynamic_bar.update_bar(max_stamina)
		print("[Stamina DEBUG] Called DynamicStaminaBar.update_bar with max = ", max_stamina)
	else:
		print("[Stamina DEBUG] Could not find DynamicStaminaBar")
