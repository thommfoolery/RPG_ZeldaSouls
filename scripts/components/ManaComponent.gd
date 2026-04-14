# scripts/components/ManaComponent.gd
extends Node
class_name ManaComponent

var max_mana: float = 80.0
var current_mana: float = 80.0
var mana_regen_rate: float = 0.0 # base mana regen per second

signal mana_changed(current: float, max_mana: float)

func _ready() -> void:
	if StatCalculator:
		max_mana = StatCalculator.get_max_mana(PlayerStats.attunement)
	else:
		max_mana = 80.0
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
	call_deferred("_update_dynamic_bar")

func _process(delta: float) -> void:
	if mana_regen_rate > 0.0 and current_mana < max_mana:   # only regen if we have a positive rate
		var regen_this_frame = mana_regen_rate * delta
		current_mana = min(current_mana + regen_this_frame, max_mana)
		mana_changed.emit(current_mana, max_mana)
		call_deferred("_update_dynamic_bar")

func spend_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		call_deferred("_update_dynamic_bar")
		return true
	return false

func drain(amount: float) -> bool:
	return spend_mana(amount)

func restore_full() -> void:
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
	call_deferred("_update_dynamic_bar")

func fill_to_new_max() -> void:
	if StatCalculator:
		max_mana = StatCalculator.get_max_mana(PlayerStats.attunement)
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
	call_deferred("_update_dynamic_bar")
	print("[ManaComponent] Filled to new max: ", max_mana)

func get_normalized() -> float:
	return current_mana / max_mana if max_mana > 0 else 0.0

func _update_dynamic_bar() -> void:
	if not is_inside_tree():
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	var dynamic_bar = hud.get_node_or_null("HUDContainer/ManaBar/DynamicManaBar") as DynamicStatBar
	if dynamic_bar:
		dynamic_bar.update_bar(max_mana)
	else:
		print("[Mana DEBUG] Could not find DynamicManaBar")
