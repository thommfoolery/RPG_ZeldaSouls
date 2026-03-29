# ExplosionFlash.gd
extends Node2D

@onready var point_light: PointLight2D = $PointLight2D

func _ready() -> void:
	if not point_light:
		push_warning("[ExplosionFlash] No PointLight2D found on root")
		return

	# Big initial flash (like we had before)
	point_light.energy = 2.2

	# Start particles immediately (this is what made them look perfect)
	_start_one_shot_particles()

	# Light fade — exactly like your original version
	var tween = create_tween()
	tween.tween_property(point_light, "energy", 0.0, 0.75) \
		 .set_trans(Tween.TRANS_QUAD) \
		 .set_ease(Tween.EASE_OUT)

	# Cleanup after the light has faded
	await tween.finished
	queue_free()


# Required by Projectile.gd
func _start_one_shot_particles() -> void:
	for child in get_children():
		if child is GPUParticles2D or child is CPUParticles2D:
			child.emitting = true
			print("[Explosion] One-shot particles STARTED → ", child.name)
