# scripts/components/HealthComponent.gd
extends Node
class_name HealthComponent

# Regen rate from equipment (default 0)
var hp_regen_rate: float = 0.0:
	set(new_rate):
		var old_rate = hp_regen_rate
		hp_regen_rate = max(0.0, new_rate)
		print("[HealthComponent] HP Regen Rate changed: ", old_rate, " → ", hp_regen_rate)
		
		# Force Stats tab to refresh so "HP Regen Rate" line updates immediately
		var stats_tab = get_tree().get_first_node_in_group("stats_tab")
		if stats_tab and stats_tab.has_method("_refresh_stats_tab"):
			stats_tab.call_deferred("_refresh_stats_tab")

# Max health with setter (already had this, kept for consistency)
var max_health: float = 122.0:
	set(new_max):
		var old_max = max_health
		max_health = clamp(new_max, 1.0, 9999.0)
		health_changed.emit(current_health, max_health)
		call_deferred("_update_dynamic_bar")
		print("[HealthComponent] Max HP changed: ", old_max, " → ", max_health)

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

func _process(delta: float) -> void:
	if hp_regen_rate > 0.0 and current_health < max_health:
		var regen_this_frame = hp_regen_rate * delta
		current_health = min(current_health + regen_this_frame, max_health)
		health_changed.emit(current_health, max_health)
		call_deferred("_update_dynamic_bar")

func _enter_tree() -> void:
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
	if Global:
		Global.current_health = current_health
	health_changed.emit(current_health, max_health)
	call_deferred("_update_dynamic_bar")
	if current_health <= 0:
		died.emit()
	return true

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	if Global:
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
		print("[Health DEBUG] Could not find DynamicStatBar")
