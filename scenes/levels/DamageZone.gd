# DamageZone.gd
extends Area2D

@export var damage_per_sec: float = 30.0          # lowered so you can see it tick
@export var damage_interval: float = 0.5

# Per-body tracking to avoid timer interference
var damage_timers: Dictionary = {}  # Node → float (accumulated time)

func _physics_process(delta: float) -> void:
	var bodies = get_overlapping_bodies()
	if bodies.is_empty():
		return

	for body in bodies:
		var health = body.get_node_or_null("HealthComponent")
		if not health:
			continue  # skip anything without health

		# Initialize timer for this body if new
		if not damage_timers.has(body):
			damage_timers[body] = 0.0

		damage_timers[body] += delta

		if damage_timers[body] >= damage_interval:
			var actual_damage = damage_per_sec * damage_interval
			health.take_damage(actual_damage)
			
			print("[DamageZone] Dealt ", actual_damage, " damage to ", 
				  body.name if body.has_method("get_name") else str(body), 
				  " (group: ", "player" if body.is_in_group("player") else "enemy/other", ") ",
				  "HP now: ", health.current_health)
			
			damage_timers[body] = 0.0

	# Cleanup invalid entries (prevents memory leak when bodies die/queue_free)
	var to_remove: Array[Node] = []
	for body in damage_timers.keys():
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			to_remove.append(body)
	
	for body in to_remove:
		damage_timers.erase(body)
		print("[DamageZone] Cleaned up dead body reference")
