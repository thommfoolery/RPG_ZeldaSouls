# scripts/components/DeathHandler.gd
extends Node

@onready var health: HealthComponent = get_parent().get_node("HealthComponent")
@onready var player_body: CharacterBody2D = get_parent()

func _ready() -> void:
	if not health:
		push_error("[DeathHandler] HealthComponent MISSING!")
		return
	print("[DeathHandler] Ready - connected to died on ", health)
	health.died.connect(_on_player_died)


func _on_player_died() -> void:
	print("=== DEATH SIGNAL RECEIVED IN DeathHandler ===")
	print("[DeathHandler] Player died at: ", player_body.global_position)
	
	# IMMEDIATELY freeze movement and collision
	player_body.collision_layer = 0
	player_body.collision_mask = 0
	player_body.process_mode = Node.PROCESS_MODE_DISABLED
	
	# ─── Use AnimationComponent for death animation ───
	var anim = player_body.get_node_or_null("AnimationComponent")
	if anim and anim.has_method("play_death"):
		print("[DeathHandler] Requesting death animation through AnimationComponent...")
		anim.play_death()
		await anim.death_anim_completed
		print("[DeathHandler] Death animation finished")
	else:
		print("[DeathHandler] WARNING: No AnimationComponent or play_death method")
		# Safe fallback
		var sprite = player_body.get_node_or_null("SpriteContainer/AnimatedSprite2D")
		if sprite and sprite.sprite_frames.has_animation("death"):
			sprite.stop()
			sprite.sprite_frames.set_animation_loop("death", false)
			sprite.play("death")
			await sprite.animation_finished
	
	# Safe scene path
	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	else:
		scene_path = "res://scenes/_testroom.tscn"
		print("[DeathHandler] WARNING: get_tree().current_scene was null during death")
	
	# Emit via EventBus
	var death_pos = player_body.global_position
	var dropped_souls = PlayerStats.souls_carried
	print("[DeathHandler] Emitting player_died via EventBus")
	print(" └─ Position: ", death_pos)
	print(" └─ Souls dropped: ", dropped_souls)
	print(" └─ Scene: ", scene_path.get_file())
	EventBus.player_died.emit(death_pos, dropped_souls)
	
	# Rest of your original logic (unchanged)
	Global.last_death_pos = death_pos
	Global.dropped_souls = dropped_souls
	Global.has_pending_bloodstain = true
	Global.last_death_scene = scene_path
	Global.locked_death_pos = death_pos
	Global.is_death_respawn = true
	
	if BloodstainManager:
		BloodstainManager._spawned_this_death = false
	
	Global.death_timestamp = Time.get_unix_time_from_system()
	print("[DeathHandler] Death timestamp recorded: ", Global.death_timestamp, " (real-world time)")
	print("[DeathHandler] Death recorded → pos: ", Global.locked_death_pos,
		  " | scene: ", scene_path.get_file(), " | souls: ", Global.dropped_souls,
		  " | is_death_respawn = true")
	
	PlayerStats.souls_carried = 0
	PlayerStats.souls_changed.emit(0)
	
	if SaveManager:
		SaveManager.request_save()
	
	# DEATH SCREEN & TIMING
	await get_tree().create_timer(2.0).timeout
	var death_screen_scene = preload("res://scenes/ui/death_screen.tscn")
	var death_screen = death_screen_scene.instantiate()
	get_tree().root.add_child(death_screen)
	if death_screen.has_method("play_death_fade"):
		death_screen.play_death_fade()
	await get_tree().create_timer(5.0).timeout
	
	player_body.process_mode = Node.PROCESS_MODE_INHERIT
	health.current_health = health.max_health
	health.is_invincible = false
	health.health_changed.emit(health.current_health, health.max_health)
	
	if PlayerStats:
		PlayerStats.respawn_full_heal()
		print("[Feature-DEBUG] Called PlayerStats.respawn_full_heal() → estus should now refill")
	
	var stamina_comp = player_body.get_node_or_null("StaminaComponent")
	if stamina_comp:
		stamina_comp.current_stamina = stamina_comp.max_stamina
		stamina_comp.stamina_changed.emit(stamina_comp.current_stamina, stamina_comp.max_stamina)
		stamina_comp.time_since_last_drain = 0.0
		if Global:
			Global.current_stamina = stamina_comp.current_stamina
			print("[Feature-DEBUG] Full stamina restored on death respawn → ", Global.current_stamina)
	
	print("[DeathHandler] Respawn triggered")
	if CheckpointManager and CheckpointManager.has_valid_checkpoint():
		print("[DeathHandler] → using CheckpointManager.respawn()")
		Global.current_health = health.max_health
		CheckpointManager.respawn()
		Global.current_health = 122.0
		if SaveManager:
			SaveManager.request_save()
			print("[DeathHandler] Autosave triggered after respawn — bonfire position now persisted to disk")
	else:
		print("[DeathHandler] → no checkpoint, reloading scene")
		get_tree().reload_current_scene()

	if SaveManager:
		SaveManager.request_save()
