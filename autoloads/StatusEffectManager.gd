# autoload/StatusEffectManager.gd
extends Node
signal effect_applied(effect: StatusEffect, active: ActiveEffect)
signal effect_removed(effect_id: String)

var active_effects: Array[ActiveEffect] = []

class ActiveEffect:
	var effect: StatusEffect
	var build_up: float = 0.0
	var is_poisoned: bool = false
	var remaining_time: float = 0.0
	var source: Node

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	print("[StatusEffectManager] _ready() - active_effects initialized, size = ", active_effects.size())

func _on_player_died(_death_pos: Vector2, _dropped_souls: int) -> void:
	clear_all_effects(true) # keep permanent equipment buffs on death
	print("[StatusEffectManager] Player died — cleared only non-permanent effects")

func apply_effect(effect: StatusEffect, source: Node = null) -> void:
	if not effect:
		return
	
	# Defensive: Never allow poison to be applied without a valid source on fresh load
	if effect.id == "poison" and not source:
		print("[StatusEffectManager] BLOCKED: Poison applied with no source on load — ignoring")
		return

	print("[StatusEffectManager] Active effects count BEFORE apply for '", effect.id, "': ", active_effects.size())

	# Check if this exact buff ID is already active → only update, do NOT replace other buffs
	for ae in active_effects:
		if ae.effect.id == effect.id:
			ae.source = source
			effect_applied.emit(effect, ae)
			print("[StatusEffectManager] Updated existing effect: ", effect.display_name)
			return

	# Create brand new ActiveEffect (this allows multiple different buffs)
	var new_ae = ActiveEffect.new()
	new_ae.effect = effect
	new_ae.source = source
	active_effects.append(new_ae)
	effect_applied.emit(effect, new_ae)
	print("[StatusEffectManager] Added NEW effect: ", effect.display_name, " | source: NONE")
	print("[StatusEffectManager] Active effects count AFTER apply: ", active_effects.size())

	# Debug what is actually stored
	for ae in active_effects:
		print(" - Stored: ", ae.effect.id, " (permanent: ", ae.effect.is_permanent, ")")

func _process(delta: float) -> void:
	# Extra safety during scene transitions
	if not is_instance_valid(get_tree()) or get_tree().current_scene == null:
		return

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

	# Replace old array (safe, no index shifting issues)
	active_effects = new_active_effects

func clear_all_effects(skip_permanent: bool = false) -> void:
	print("[StatusEffectManager] clear_all_effects() called — purging ", active_effects.size(), " effects | skip_permanent=", skip_permanent)
	print("[DEBUG] Call stack: ", get_stack())

	for i in range(active_effects.size() - 1, -1, -1):
		var ae = active_effects[i]
		if skip_permanent and ae.effect.is_permanent:
			continue
		ae.build_up = 0.0
		ae.is_poisoned = false
		ae.remaining_time = 0.0
		active_effects.remove_at(i)
		effect_removed.emit(ae.effect.id)

	if not skip_permanent:
		active_effects.clear()

	print("[StatusEffectManager] Clear finished — remaining effects: ", active_effects.size())
