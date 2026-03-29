# scenes/entities/bonfire/bonfire.gd
extends Node2D

@export var bonfire_id: String = "default_bonfire"
@export var spawn_offset_y: float = 24.0
@export var prompt_hide_distance: float = 40.0

@onready var flame: AnimatedSprite2D = $Flame
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

# VFX Nodes
@onready var smoke1: GPUParticles2D = $Effects/SmokeLayer1
@onready var smoke2: GPUParticles2D = $Effects/SmokeLayer2
@onready var embers: GPUParticles2D = $Effects/EmbersBurst
@onready var warm_light: PointLight2D = $Effects/WarmLight
@onready var flash_light: PointLight2D = $Effects/FlashLight

var is_lit: bool = false
var player_near: bool = false
var player_node: Node2D = null
var is_resting: bool = false
var just_lit: bool = false
var _has_refreshed: bool = false

func _ready() -> void:
	# Force lights off immediately
	if warm_light: warm_light.energy = 0.0
	if flash_light: flash_light.energy = 0.0
	if embers: embers.emitting = false

	var entry = BonfireManager.get_entry(bonfire_id)
	if entry:
		is_lit = PlayerStats.discovered_bonfires.has(bonfire_id)
		flame.play("lit" if is_lit else "unlit")
	else:
		push_warning("[Bonfire] No registry entry found for ID: " + bonfire_id)
		flame.play("unlit")

	_update_vfx_state()
	
	if is_lit and warm_light:
		_start_warm_light_breathing()
		
	prompt_label.visible = false
	update_prompt()

	if not _has_refreshed:
		is_lit = PlayerStats.discovered_bonfires.has(bonfire_id) if PlayerStats else false
		flame.play("lit" if is_lit else "unlit")
		print("[Bonfire INITIAL] ", bonfire_id, " → lit = ", is_lit, " (fallback)")
		_has_refreshed = true
	else:
		print("[Bonfire] Skip initial lit set — refresh already ran")

func _update_vfx_state() -> void:
	# SmokeLayer1 = subtle trail when unlit, full when lit
	if smoke1:
		smoke1.emitting = true
		smoke1.amount = 8 if not is_lit else 24
		smoke1.speed_scale = 0.4 if not is_lit else 0.7

	# SmokeLayer2 = rich smoke only when lit
	if smoke2:
		smoke2.emitting = is_lit

	# Warm light - stronger at night
	if warm_light:
		var base_energy = 1.3
		if WorldTimeManager:
			var phase = WorldTimeManager.get_current_phase_name()
			if phase in ["NIGHT", "LATE_NIGHT"]:
				base_energy = 1.8  # warmer and brighter at night
			elif phase == "DUSK":
				base_energy = 1.5
		warm_light.energy = base_energy if is_lit else 0.0

	# Flash always starts off
	if flash_light:
		flash_light.energy = 0.0

	# Embers only burst on events
	if embers:
		embers.emitting = false
		embers.emitting = false

# Gentle breathing effect when lit
func _start_warm_light_breathing() -> void:
	if not warm_light: return
	var tween = create_tween().set_loops()
	tween.tween_property(warm_light, "energy", 0.95, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(warm_light, "energy", 1.55, 2.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if not player_near: return
	if player_node and player_node.global_position.distance_to(global_position) > prompt_hide_distance:
		player_near = false
		prompt_label.visible = false
		update_prompt()

func update_prompt() -> void:
	if not player_near:
		prompt_label.visible = false
		return
	prompt_label.text = "Press A to Rest" if is_lit else "Press A to Light"
	prompt_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if is_resting or not player_near or just_lit:
		return
	if not event.is_action_pressed("interact"):
		return
	
	get_viewport().set_input_as_handled()
	
	if not is_lit:
		light_bonfire()
	else:
		rest_at_bonfire()

func light_bonfire() -> void:
	if is_lit: return
	
	is_lit = true
	just_lit = true
	
	flame.play("lighting")
	
	# Dramatic lighting burst
	if embers: embers.emitting = true
	if flash_light:
		flash_light.energy = 4.5
		var tween = create_tween()
		tween.tween_property(flash_light, "energy", 0.0, 0.55).set_trans(Tween.TRANS_QUAD)
	
	await flame.animation_finished
	flame.play("lit")
	
	_update_vfx_state()
	if warm_light:
		_start_warm_light_breathing()
	
	BonfireManager.discover_bonfire(bonfire_id)
	update_prompt()
	print("[Bonfire] Lit → ", bonfire_id)
	
	if SaveManager:
		SaveManager.request_save()
	
	await get_tree().create_timer(0.4).timeout
	just_lit = false

func rest_at_bonfire() -> void:
	if is_resting or just_lit: 
		return
	
	is_resting = true
	print("[Bonfire] Rest initiated → ", bonfire_id)

	# Nice burst on rest too
	if embers: 
		embers.emitting = true
	if flash_light:
		flash_light.energy = 3.8
		var tween = create_tween()
		tween.tween_property(flash_light, "energy", 0.0, 0.5).set_trans(Tween.TRANS_QUAD)

	# Set checkpoint
	var spawn_pos := global_position + Vector2(0, spawn_offset_y)
	var scene_path := get_tree().current_scene.scene_file_path
	var entry = BonfireManager.get_entry(bonfire_id)
	if entry and entry.spawn_position != Vector2.ZERO:
		spawn_pos = entry.spawn_position

	if CheckpointManager:
		CheckpointManager.set_checkpoint(bonfire_id, scene_path, spawn_pos)

	# ─── RESTORE PLAYER RESOURCES ───
	var player = PlayerManager.current_player
	if player:
		# Health
		var health = player.get_node_or_null("HealthComponent")
		if health:
			health.heal(health.max_health)

		# Stamina
		var stamina = player.get_node_or_null("StaminaComponent")
		if stamina:
			stamina.current_stamina = stamina.max_stamina
			stamina.stamina_changed.emit(stamina.current_stamina, stamina.max_stamina)

		# MANA - NEW
		var mana = player.get_node_or_null("ManaComponent")
		if mana:
			if mana.has_method("restore_full"):
				mana.restore_full()
			else:
				# Fallback if restore_full doesn't exist yet
				mana.current_mana = mana.max_mana
				if mana.has_signal("mana_changed"):
					mana.mana_changed.emit(mana.current_mana, mana.max_mana)
			print("[Bonfire] Mana fully restored")

	# Reset enemies
	if WorldStateManager:
		WorldStateManager.reset_regular_enemies()

	# Show the proper bonfire menu
	if UIManager:
		UIManager.show_bonfire_menu(bonfire_id)

	await get_tree().create_timer(0.1).timeout
	is_resting = false  # safety fallback

func _on_rest_ui_closed(menu_type: String) -> void:
	if menu_type != "rest": return
	print("[Bonfire] _on_rest_ui_closed RECEIVED — processing once")
	get_tree().paused = false
	is_resting = false
	update_prompt()
	
	if PlayerStats:
		PlayerStats.rest_at_bonfire(bonfire_id)
	
	if SaveManager:
		SaveManager.request_save()
	
	if UIManager.ui_closed.is_connected(_on_rest_ui_closed):
		UIManager.ui_closed.disconnect(_on_rest_ui_closed)

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_node = body
		player_near = true
		update_prompt()
		print("[Bonfire] Player entered interaction range → ", bonfire_id)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_node = null
		player_near = false
		prompt_label.visible = false
		update_prompt()
		print("[Bonfire] Player exited interaction range → ", bonfire_id)
