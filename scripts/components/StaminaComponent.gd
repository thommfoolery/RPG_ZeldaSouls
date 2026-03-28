# scripts/components/StaminaComponent.gd
extends Node
class_name StaminaComponent

@export var max_stamina: float = 100.0
@export var regen_rate: float = 30.0          # stamina per second
@export var regen_delay: float = 1.5          # seconds before regen starts after last use

var current_stamina: float = 100.0
var time_since_last_drain: float = 0.0

signal stamina_changed(current: float, max_stamina: float)

func _ready() -> void:
	# ─── STAMINA PERSISTENCE: Load from Global on every spawn/scene load ───
	# Exactly parallel to HealthComponent. Regen only natural, no reset on change.
	if Global:
		current_stamina = Global.current_stamina
		print("[Feature-DEBUG] Stamina loaded from Global → ", current_stamina)
	else:
		current_stamina = max_stamina
		print("[Feature-DEBUG] Global missing — using default max stamina")
	
	stamina_changed.emit(current_stamina, max_stamina)

func _process(delta: float) -> void:
	if current_stamina < max_stamina:
		if time_since_last_drain >= regen_delay:
			var regen_this_frame = regen_rate * delta
			current_stamina = min(current_stamina + regen_this_frame, max_stamina)
			stamina_changed.emit(current_stamina, max_stamina)
			
			# ─── FIXED: Sync during regen so full refill persists across scene loads ───
			if Global:
				Global.current_stamina = current_stamina
	
	time_since_last_drain += delta

func drain(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		time_since_last_drain = 0.0
		stamina_changed.emit(current_stamina, max_stamina)
		
		# ─── SYNC BACK TO GLOBAL on every drain (persists through scene changes) ───
		Global.current_stamina = current_stamina
		print("[Feature-DEBUG] Stamina drained → synced to Global: ", current_stamina)
		
		return true
	return false

# For HUD / future checks
func get_normalized() -> float:
	return current_stamina / max_stamina if max_stamina > 0 else 0.0
