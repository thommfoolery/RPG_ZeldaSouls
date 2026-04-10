# autoload/QuickUseHandler.gd
extends Node

signal item_used(item: GameItem, slot_index: int)
signal item_use_failed(reason: String)
signal item_dropped(item: GameItem, quantity: int)
signal item_discarded(item: GameItem, quantity: int)

var cross_hud: CrossHUD = null
var player: Node = null
var player_inventory: PlayerInventory = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[QUICK-USE] QuickUseHandler ready — single source of truth for Use/Drop/Discard")
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

# ─────────────────────────────────────────────────────────────
# PUBLIC API — used by quick slots AND inventory
# ─────────────────────────────────────────────────────────────

func use_item(item: GameItem, slot_index: int = -1) -> void:
	if not item:
		emit_signal("item_use_failed", "no_item")
		return

	if not item.can_use:
		emit_signal("item_use_failed", "cannot_use")
		print("[QUICK-USE] Item ", item.display_name, " cannot be used")
		return

	print("[QUICK-USE] use_item() called → ", item.display_name, " | slot=", slot_index)

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
		print("[QUICK-USE] Spawning projectile for ", item.display_name)
		spawn_projectile(item, slot_index)
		return

	# Dispatch for non-projectile effects
	match item.effect_type:
		"Heal":
			_handle_heal(item, slot_index)
		"Teleport":
			_handle_teleport(item, slot_index)
		"Buff":
			_handle_buff(item)
		"StatusClear":
			_handle_status_clear(item)
		"Cast":
			_handle_cast(item)
		_:
			print("[QUICK-USE] Unknown effect_type '", item.effect_type, "'")

	if item.consumes_on_use and item.special_component_ref == "":
		_consume_from_inventory(item, slot_index)

	item_used.emit(item, slot_index)

func drop_item(item: GameItem, quantity: int = 1) -> void:
	if not item or not item.can_drop:
		print("[QUICK-USE] Cannot drop item ", item.display_name if item else "null")
		return

	quantity = clamp(quantity, 1, item.quantity if "quantity" in item else 1)

	print("[QUICK-USE] Dropping ", quantity, "x ", item.display_name)

	if player_inventory:
		player_inventory.consume_item(item.id, quantity)

	_spawn_pickup(item, quantity)

	item_dropped.emit(item, quantity)

func discard_item(item: GameItem, quantity: int = 1) -> void:
	if not item or not item.can_discard:
		print("[QUICK-USE] Cannot discard item")
		return

	if item.requires_confirmation:
		print("[QUICK-USE] Discard requires confirmation — TODO UI")
		return

	quantity = clamp(quantity, 1, item.quantity if "quantity" in item else 1)

	print("[QUICK-USE] Discarding ", quantity, "x ", item.display_name)

	if player_inventory:
		player_inventory.consume_item(item.id, quantity)

	item_discarded.emit(item, quantity)

# ─────────────────────────────────────────────────────────────
# Inventory helpers
# ─────────────────────────────────────────────────────────────

func _consume_from_inventory(item: GameItem, slot_index: int) -> void:
	if player_inventory:
		player_inventory.consume_item(item.id, 1)
	else:
		print("[QUICK-USE-DEBUG] No PlayerInventory reference — only reducing equipped copy")

	if slot_index >= 0:
		if item.quantity > 1:
			item.quantity -= 1
		else:
			EquipmentManager.unequip_slot(slot_index)

		EquipmentManager.equipped_changed.emit(slot_index, item)

func _spawn_pickup(item: GameItem, quantity: int) -> void:
	if not player:
		push_warning("[QUICK-USE] No player — cannot spawn pickup")
		return

	var pickup_scene = load("res://scenes/entities/ItemPickup.tscn") as PackedScene
	if not pickup_scene:
		push_error("[QUICK-USE] ItemPickup.tscn not found!")
		return

	var pickup = pickup_scene.instantiate() as ItemPickup
	pickup.item = item.duplicate()
	pickup.quantity = quantity
	pickup.pickup_id = "dropped_" + item.id + "_" + str(Time.get_ticks_msec())

	var offset = Vector2(0, 20)
	pickup.global_position = player.global_position + offset

	get_tree().current_scene.add_child(pickup)

	print("[QUICK-USE] Spawned pickup → ", item.display_name, " x", quantity)

# ─────────────────────────────────────────────────────────────
# QUICK SLOT ENTRY
# ─────────────────────────────────────────────────────────────

func use_current_quick_slot() -> void:
	if Global.is_death_respawn:
		print("[QUICK-USE] Blocked quick use — Global.is_death_respawn is true")
		return

	var slot_index := 2
	if is_instance_valid(cross_hud):
		slot_index = cross_hud.active_quick_index
		print("[QUICK-USE-DEBUG] Using LIVE cross_hud.active_quick_index = ", slot_index)

	var item: GameItem = EquipmentManager.get_equipped_item(slot_index)

	if not item:
		print("[QUICK-USE] No item in slot ", slot_index)
		return

	use_item(item, slot_index)

# ─────────────────────────────────────────────────────────────
# ORIGINAL HANDLERS (UNCHANGED)
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

	print("[QUICK-USE] Real bonfire found — consuming item")

	if player_inventory:
		player_inventory.consume_item(item.id, 1)
	else:
		if item.quantity <= 1:
			EquipmentManager.unequip_slot(slot_index)
		else:
			item.quantity -= 1

	EquipmentManager.equipped_changed.emit(slot_index, item)
	item_used.emit(item, slot_index)

	print("[QUICK-USE] Bone consumed. Starting cast.")

	InputManager.input_blocked = true

	var movement = player.get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.can_move = false

	var particles = player.get_node_or_null("Effects/EstusHealParticles")
	if particles and particles is GPUParticles2D:
		particles.modulate = Color(0.85,0.9,1.0,0.85)
		particles.emitting = true

	var anim = player.get_node_or_null("AnimationComponent")
	if anim and anim.has_method("play_teleport_cast"):
		anim.play_teleport_cast()

	await get_tree().create_timer(0.5).timeout

	print("[QUICK-USE] Warping to bonfire ", bonfire_id)

	AreaTransitionService.warp_to_bonfire(bonfire_id)

	InputManager.input_blocked = false
	if movement:
		movement.can_move = true

func _handle_heal(item: GameItem, slot_index: int) -> void:
	print("[QUICK-USE] HEAL triggered — value ", item.effect_value)

	if item.special_component_ref != "":
		if player and player.has_node(item.special_component_ref):
			var component = player.get_node(item.special_component_ref)
			if component.has_method("_on_use_item_pressed"):
				component._on_use_item_pressed()
				return

	if player and player.has_node("HealthComponent"):
		var hc = player.get_node("HealthComponent") as HealthComponent
		hc.current_health = min(hc.current_health + item.effect_value, hc.max_health)
		hc.health_changed.emit(hc.current_health, hc.max_health)

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

	var spawn_offset: Vector2 = Vector2(1,-1) * dir
	var spawn_pos: Vector2 = player.global_position + spawn_offset

	print("[QUICK-USE] Spawning projectile → ", item.display_name)

	ProjectileSpawner.spawn_projectile(item, spawn_pos, dir)

	if item.consumes_on_use:
		if player_inventory:
			player_inventory.consume_item(item.id,1)

		if item.quantity <= 1:
			EquipmentManager.unequip_slot(slot_index)
		else:
			item.quantity -= 1

		EquipmentManager.equipped_changed.emit(slot_index,item)

func _handle_buff(_item: GameItem) -> void:
	print("[QUICK-USE] BUFF triggered")

func _handle_status_clear(item: GameItem) -> void:
	print("[QUICK-USE-DEBUG] === STATUS CLEAR START ===")
	print("  └─ Item ID: ", item.id if item else "null")
	print("  └─ status_to_clear: '", item.status_to_clear if item else "null", "'")
	
	if not item or item.status_to_clear.is_empty():
		print("[QUICK-USE-DEBUG] FAILED: No status_to_clear defined on item")
		item_use_failed.emit("no_status_to_clear")
		return

	print("[QUICK-USE-DEBUG] Looking for active effect with id: ", item.status_to_clear)
	print("[QUICK-USE-DEBUG] Current active_effects count: ", StatusEffectManager.active_effects.size())

	var removed = false
	for i in range(StatusEffectManager.active_effects.size() - 1, -1, -1):
		var ae = StatusEffectManager.active_effects[i]
		print("  └─ Checking active effect: ", ae.effect.id, " | poisoned=", ae.is_poisoned)
		
		if ae.effect.id == item.status_to_clear:
			print("[QUICK-USE-DEBUG] MATCH FOUND — removing effect ", ae.effect.id)
			StatusEffectManager.active_effects.remove_at(i)
			StatusEffectManager.effect_removed.emit(ae.effect.id)
			removed = true
			break

	if removed:
		print("[QUICK-USE-DEBUG] SUCCESS: Poison cleared via antidote")
		# Optional: visual feedback
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_center_message"):
			hud.show_center_message("Poison cured", 1.5)
	else:
		print("[QUICK-USE-DEBUG] FAILED: No matching active effect found for '", item.status_to_clear, "'")
		item_use_failed.emit("no_effect_to_clear")
	
	print("[QUICK-USE-DEBUG] === STATUS CLEAR END ===\n")
func _handle_cast(_item: GameItem) -> void:
	print("[QUICK-USE] CAST triggered")

func _on_quick_slot_changed(new_index: int) -> void:
	print("[QUICK-USE-DEBUG] Received quick_use_changed signal → slot ", new_index)

func _on_player_changed(new_player: Node) -> void:
	player = new_player
	if player:
		print("[QUICK-USE] Player reference updated")
