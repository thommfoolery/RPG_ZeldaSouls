# autoload/StatusEffectManager.gd
extends Node

signal effect_applied(effect: StatusEffect, active: ActiveEffect)
signal effect_removed(effect_id: String)

var active_effects: Array[ActiveEffect] = []
var _is_player_dead: bool = false   # Prevents re-applying effects during death/respawn

class ActiveEffect:
	var effect: StatusEffect
	var build_up: float = 0.0
	var is_poisoned: bool = false
	var remaining_time: float = 0.0
	var source: Node

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)

func _on_player_died(_death_pos: Vector2, _dropped_souls: int) -> void:
	_is_player_dead = true
	clear_all_effects()
	print("[StatusEffectManager] Player died — effects locked until respawn")

func apply_effect(effect: StatusEffect, source: Node = null) -> void:
	if _is_player_dead:
		print("[StatusEffectManager] BLOCKED apply_effect during death/respawn: ", effect.display_name)
		return
	
	if not effect:
		return
	
	# Defensive: Never allow poison to be applied without a valid source on fresh load
	if effect.id == "poison" and not source:
		print("[StatusEffectManager] BLOCKED: Poison applied with no source on load — ignoring")
		return
	
	# Update existing effect if already active
	for ae in active_effects:
		if ae.effect.id == effect.id:
			ae.source = source
			effect_applied.emit(effect, ae)
			return
	
	# Create new active effect
	var new_ae = ActiveEffect.new()
	new_ae.effect = effect
	new_ae.source = source
	active_effects.append(new_ae)
	effect_applied.emit(effect, new_ae)
	print("[StatusEffectManager] Applied effect: ", effect.display_name, " | source: ", source.name if source else "NONE")

func _process(delta: float) -> void:
	if _is_player_dead:
		return  # Extra safety during death sequence
	
	var new_active_effects: Array[ActiveEffect] = []
	
	for ae in active_effects:
		var e = ae.effect
		var was_below_threshold = ae.build_up < e.build_up_required

		# Determine if inside source
		var is_inside_source := false
		if ae.source and is_instance_valid(ae.source):
			if ae.source.has_method("is_player_inside"):
				is_inside_source = ae.source.is_player_inside()
			else:
				is_inside_source = ae.source.get("_player_inside") == true

		# Build-up / Decay
		if is_inside_source:
			ae.build_up += delta * e.build_up_rate
		else:
			ae.build_up -= delta * e.decay_rate

		ae.build_up = clamp(ae.build_up, 0.0, e.build_up_required)

		# ─── INSTADEATH / MORTAL SPECIAL CASE ───
		if e.is_mortal and was_below_threshold and ae.build_up >= e.build_up_required:
			print("[StatusEffectManager] MORTAL EFFECT FULLY BUILT UP: ", e.display_name)
			var health = PlayerManager.current_player.get_node_or_null("HealthComponent")
			if health:
				health.died.emit()
			effect_removed.emit(e.id)
			continue

		# ─── BLEED SPECIAL CASE ───
		if e.id == "bleed" and was_below_threshold and ae.build_up >= e.build_up_required:
			var health = PlayerManager.current_player.get_node_or_null("HealthComponent")
			if health:
				var damage = health.max_health * e.on_full_damage_percent
				health.take_damage(damage)
				print("[StatusEffectManager] BLEED PROC! ", damage, " damage")
			effect_removed.emit(e.id)
			continue

		# Normal poisoned state
		if ae.is_poisoned:
			ae.remaining_time -= delta
			if ae.remaining_time <= 0.0:
				effect_removed.emit(e.id)
				continue

			if e.tick_rate > 0.0 and int(ae.remaining_time / e.tick_rate) != int((ae.remaining_time + delta) / e.tick_rate):
				var health = PlayerManager.current_player.get_node_or_null("HealthComponent")
				if health and e.tick_value < 0.0:
					health.take_damage(-e.tick_value)

		# Trigger normal poisoned state
		elif ae.build_up >= e.build_up_required:
			ae.is_poisoned = true
			ae.remaining_time = e.max_duration
			ae.build_up = 0.0
			print("[StatusEffectManager] ", e.display_name, " ACTIVATED!")
			effect_applied.emit(e, ae)

		# Keep the effect for next frame
		new_active_effects.append(ae)

	# Replace old array (no index shifting issues)
	active_effects = new_active_effects

func clear_all_effects() -> void:
	print("[StatusEffectManager] clear_all_effects() called — purging ", active_effects.size(), " effects")
	
	for i in range(active_effects.size() - 1, -1, -1):
		var ae = active_effects[i]
		# Force-reset every field so nothing can leak into HUD or damage
		ae.build_up = 0.0
		ae.is_poisoned = false
		ae.remaining_time = 0.0
		active_effects.remove_at(i)
		effect_removed.emit(ae.effect.id)
	
	active_effects.clear()
	print("[StatusEffectManager] All status effects cleared (states forcibly reset)")

# Call this after respawn is fully complete
func on_player_respawned() -> void:
	_is_player_dead = false
	print("[StatusEffectManager] Player respawned — effects unlocked")
