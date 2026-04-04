# autoload/QuickUseHandler.gd
extends Node

signal item_used(item: GameItem, slot_index: int)
signal item_use_failed(reason: String)

var cross_hud: CrossHUD = null
var player: Node = null
var player_inventory: PlayerInventory = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[QUICK-USE] QuickUseHandler ready — data-driven dispatcher online")
	await get_tree().process_frame
	_connect_to_systems()
	print("[QUICK-USE] Initialization complete — listening for D-pad input")

func _connect_to_systems() -> void:
	print("[QUICK-USE-DEBUG] _connect_to_systems() called — one-time only")
	if not cross_hud and player and player.has_node("../HUD/CrossHUD"):
		cross_hud = player.get_node("../HUD/CrossHUD")
		print("[QUICK-USE-DEBUG] Found CrossHUD via direct path")
	
	if cross_hud and not cross_hud.quick_use_changed.is_connected(_on_quick_slot_changed):
		cross_hud.quick_use_changed.connect(_on_quick_slot_changed)
		print("[QUICK-USE] Connected to CrossHUD quick_use_changed signal")
	
	if PlayerInventory:
		player_inventory = PlayerInventory
		print("[QUICK-USE-DEBUG] Connected to PlayerInventory")
	
	if PlayerManager and not PlayerManager.player_changed.is_connected(_on_player_changed):
		PlayerManager.player_changed.connect(_on_player_changed)

func use_current_quick_slot() -> void:
	if Global.is_death_respawn:
		print("[QUICK-USE] Blocked quick use — Global.is_death_respawn is true")
		return
	
	var slot_index := 2
	if is_instance_valid(cross_hud):
		slot_index = cross_hud.active_quick_index
		print("[QUICK-USE-DEBUG] Using LIVE cross_hud.active_quick_index = ", slot_index)
	else:
		print("[QUICK-USE-DEBUG] No cross_hud — falling back to slot 2")
	
	var item: GameItem = EquipmentManager.get_equipped_item(slot_index)  # ← Fixed type
	
	print("[QUICK-USE] use_current_quick_slot() called — slot ", slot_index, " | item = ", item.display_name if item else "EMPTY")
	
	if not item:
		print("[QUICK-USE] No item in slot ", slot_index)
		return
	
	# Cost checks
	if item.stamina_cost > 0:
		if not player or not player.has_node("StaminaComponent"):
			emit_signal("item_use_failed", "no_stamina_component")
			return
		var stam = player.get_node("StaminaComponent") as StaminaComponent
		if stam.current_stamina < item.stamina_cost:
			emit_signal("item_use_failed", "not_enough_stamina")
			print("[QUICK-USE] Not enough stamina")
			return
		stam.current_stamina -= item.stamina_cost
	
	if item.mana_cost > 0:
		if not player or not player.has_node("ManaComponent"):
			emit_signal("item_use_failed", "no_mana_component")
			return
		var mana = player.get_node("ManaComponent") as ManaComponent
		if mana.current_mana < item.mana_cost:
			emit_signal("item_use_failed", "not_enough_mana")
			print("[QUICK-USE] Not enough mana")
			return
		mana.current_mana -= item.mana_cost
	
	# === PROJECTILE SPAWNING ===
	if item.effect_type == "Damage" and item.trajectory_type != "Instant":
		print("[QUICK-USE] Spawning projectile for ", item.display_name, " | type=", item.trajectory_type)
		spawn_projectile(item, slot_index)
		return
	
	# Dispatch for non-projectile effects
	match item.effect_type:
		"Heal":
			_handle_heal(item, slot_index)
		"Teleport":
			_handle_teleport(item, slot_index)   # ← FULL TELEPORT LOGIC
		"Buff":
			_handle_buff(item)
		"StatusClear":
			_handle_status_clear(item)
		"Cast":
			_handle_cast(item)
		_:
			print("[QUICK-USE] Unknown effect_type '", item.effect_type, "'")
	
	# Generic consumption (only for normal non-special, non-projectile items)
	if item.consumes_on_use and item.special_component_ref == "":
		if player_inventory:
			print("[QUICK-USE-DEBUG] Telling PlayerInventory to consume 1 of id=", item.id)
			player_inventory.consume_item(item.id, 1)
		else:
			print("[QUICK-USE-DEBUG] No PlayerInventory reference — only reducing equipped copy")
		
		if item.quantity > 1:
			item.quantity -= 1
			print("[QUICK-USE] Consumed 1 from equipped copy → remaining ", item.quantity)
		else:
			EquipmentManager.unequip_slot(slot_index)
			print("[QUICK-USE] Last item used → slot emptied")
		
		EquipmentManager.equipped_changed.emit(slot_index, item)
		item_used.emit(item, slot_index)

# ─────────────────────────────────────────────────────────────
# HANDLE_TELEPORT — Boneward Bone (now consumes correctly after reload)
# ─────────────────────────────────────────────────────────────
func _handle_teleport(item: GameItem, slot_index: int) -> void:
	print("[QUICK-USE] === BONEWARD BONE START ===")
	
	if Global.is_death_respawn or Global.is_in_menu or InputManager.input_blocked:
		print("[QUICK-USE] Blocked by death/menu/input")
		return
	
	var bonfire_id = CheckpointManager.current_bonfire_id if CheckpointManager else ""
	print("[QUICK-USE] CheckpointManager.current_bonfire_id = '", bonfire_id, "'")
	
	if bonfire_id.is_empty() or bonfire_id == "initial_start":
		print("[QUICK-USE] No real bonfire → showing message")
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_center_message"):
			hud.show_center_message("No bonfire found", 2.0)
		else:
			print("[HUD FALLBACK] No bonfire found")
		return
	
	# ─── CONSUME IMMEDIATELY ───
	print("[QUICK-USE] Real bonfire found — consuming item")
	if player_inventory:
		player_inventory.consume_item(item.id, 1)
	else:
		print("[QUICK-USE] No player_inventory — reducing equipped copy only")
		if item.quantity <= 1:
			EquipmentManager.unequip_slot(slot_index)
		else:
			item.quantity -= 1
	
	EquipmentManager.equipped_changed.emit(slot_index, item)
	item_used.emit(item, slot_index)
	print("[QUICK-USE] Item consumption complete")
	
	print("[QUICK-USE] Bone consumed. Starting 2.0s cast.")
	
	# Lock player
	InputManager.input_blocked = true
	var movement = player.get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.can_move = false
	
	# VFX
	var particles = player.get_node_or_null("Effects/EstusHealParticles")
	if particles and particles is GPUParticles2D:
		particles.modulate = Color(0.85, 0.9, 1.0, 0.85)
		particles.emitting = true
	
	# Animation
	var anim = player.get_node_or_null("AnimationComponent")
	if anim and anim.has_method("play_teleport_cast"):
		anim.play_teleport_cast()
	
	# 2.0 second cast
	await get_tree().create_timer(0.5).timeout
	
	print("[QUICK-USE] Cast finished — warping to bonfire: ", bonfire_id)
	AreaTransitionService.warp_to_bonfire(bonfire_id)
	
	# Unlock
	InputManager.input_blocked = false
	if movement:
		movement.can_move = true

# ─────────────────────────────────────────────────────────────
# HANDLE_HEAL — special items only (unchanged)
# ─────────────────────────────────────────────────────────────
func _handle_heal(item: GameItem, slot_index: int) -> void:
	print("[QUICK-USE] HEAL triggered — value ", item.effect_value, " | special_ref = ", item.special_component_ref)
	
	if item.special_component_ref != "":
		print("[QUICK-USE] Special component detected → delegating and STOPPING")
		if player and player.has_node(item.special_component_ref):
			var component = player.get_node(item.special_component_ref)
			if component.has_method("_on_use_item_pressed"):
				component._on_use_item_pressed()
				print("[QUICK-USE] Delegated to ", item.special_component_ref)
				return
		push_warning("[QUICK-USE] Special component not found or missing method")
		return
	
	print("[QUICK-USE] Generic heal — using standard consumption")
	if player and player.has_node("HealthComponent"):
		var hc = player.get_node("HealthComponent") as HealthComponent
		hc.current_health = min(hc.current_health + item.effect_value, hc.max_health)
		hc.health_changed.emit(hc.current_health, hc.max_health)
		print("[QUICK-USE] Health updated to ", hc.current_health)

# (rest of your file unchanged)
func spawn_projectile(item: GameItem, slot_index: int) -> void:
	if not ProjectileSpawner:
		push_error("[QUICK-USE] ProjectileSpawner autoload missing!")
		return
	
	var dir: Vector2 = Vector2.RIGHT
	if player and player.has_method("get_last_facing_direction"):
		dir = player.get_last_facing_direction()
	elif player and "last_dir" in player and player.last_dir != Vector2.ZERO:
		dir = player.last_dir.normalized()
	elif player and "last_nonzero_dir" in player:
		dir = player.last_nonzero_dir
	elif player:
		dir = Vector2.RIGHT if player.scale.x > 0 else Vector2.LEFT
	
	var spawn_offset: Vector2 = Vector2(1, -1) * dir
	var spawn_pos: Vector2 = player.global_position + spawn_offset
	
	print("[QUICK-USE] Spawning projectile → ", item.display_name, " | dir=", dir, " | spawn=", spawn_pos.round())
	ProjectileSpawner.spawn_projectile(item, spawn_pos, dir)
	
	if item.consumes_on_use:
		if player_inventory:
			player_inventory.consume_item(item.id, 1)
		if item.quantity <= 1:
			EquipmentManager.unequip_slot(slot_index)
		else:
			item.quantity -= 1
		EquipmentManager.equipped_changed.emit(slot_index, item)

func _handle_damage(_item: GameItem) -> void:
	print("[QUICK-USE] DAMAGE item — will spawn projectile in Step 5")

func _handle_buff(_item: GameItem) -> void:
	print("[QUICK-USE] BUFF triggered")

func _handle_status_clear(_item: GameItem) -> void:
	print("[QUICK-USE] STATUS CLEAR triggered")

func _handle_cast(_item: GameItem) -> void:
	print("[QUICK-USE] CAST triggered")

func _on_quick_slot_changed(new_index: int) -> void:
	print("[QUICK-USE-DEBUG] Received quick_use_changed signal → slot ", new_index, " (via signal)")

func _on_player_changed(new_player: Node) -> void:
	player = new_player
	if player:
		print("[QUICK-USE] Player reference updated")
