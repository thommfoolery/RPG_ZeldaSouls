extends CanvasLayer

@onready var fade_rect: ColorRect = $ColorRect
@onready var died_label: Label = $YouDiedLabel

func play_death_fade() -> void:
	visible = true
	died_label.visible = false
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await tween.finished
	
	died_label.visible = true
	await get_tree().create_timer(4.0).timeout
	
	died_label.visible = false
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
	await tween.finished
	
	# ─── SAFER COLLISION RESTORE ───
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		player.collision_layer = 1
		player.collision_mask = 1
		print("[DeathScreen] Collision restored safely on player ID: ", player.get_instance_id())
	else:
		print("[DeathScreen] WARNING: Could not restore collision — no valid player found")
	
	queue_free()
