# scripts/components/BowComponent.gd
extends Node
class_name BowComponent

@onready var player = get_parent() as CharacterBody2D
var cross_hud: CrossHUD = null

# Cooldown
var can_fire: bool = true
const FIRE_COOLDOWN: float = 0.25

# Prevent double-fire on hold
var right_heavy_held: bool = false
var left_heavy_held: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	cross_hud = get_tree().get_first_node_in_group("cross_hud") as CrossHUD
	if not cross_hud:
		push_error("[BowComponent] Could not find CrossHUD in group 'cross_hud'")

	if InputManager:
		InputManager.right_hand_primary.connect(_on_right_primary)
		InputManager.right_hand_heavy.connect(_on_right_heavy)
		InputManager.left_hand_primary.connect(_on_left_primary)
		InputManager.left_hand_heavy.connect(_on_left_heavy)

func _process(_delta: float) -> void:
	if not Input.is_action_pressed("right_hand_heavy"):
		right_heavy_held = false
	if not Input.is_action_pressed("left_hand_heavy"):
		left_heavy_held = false

# ─── Input Handlers ───
func _on_right_primary() -> void:
	if cross_hud:
		_fire_from_hand(cross_hud.active_right_index, 9)

func _on_right_heavy(charge_time: float = 0.0) -> void:
	if cross_hud and not right_heavy_held:
		right_heavy_held = true
		_fire_from_hand(cross_hud.active_right_index, 10)

func _on_left_primary() -> void:
	if cross_hud:
		_fire_from_hand(cross_hud.active_left_index, 9)

func _on_left_heavy(charge_time: float = 0.0) -> void:
	if cross_hud and not left_heavy_held:
		left_heavy_held = true
		_fire_from_hand(cross_hud.active_left_index, 10)

# ─── Core Fire Logic ───
func _fire_from_hand(active_slot: int, ammo_slot: int) -> void:
	if Global.is_death_respawn or Global.is_in_menu or not player or not can_fire:
		return

	# Check bow
	var bow_item = EquipmentManager.get_equipped_item(active_slot)
	if not bow_item or bow_item.weapon_type != "Bow":
		return

	# Check ammo
	var ammo_item = EquipmentManager.get_equipped_item(ammo_slot)
	if not ammo_item or ammo_item.category != "Ammo":
		print("[BowComponent] No ammo equipped in slot ", ammo_slot)
		return

	# Prevent firing when out of ammo
	if ammo_item.quantity <= 0:
		print("[BowComponent] Out of ", ammo_item.display_name)
		return

	# Check stamina BEFORE firing
	var stam = player.get_node_or_null("StaminaComponent")
	if stam and stam.current_stamina < 6.0:
		print("[BowComponent] Not enough stamina to shoot!")
		return

	# All checks passed → Fire!
	_fire_projectile(ammo_item, ammo_slot)

	can_fire = false
	await get_tree().create_timer(FIRE_COOLDOWN).timeout
	can_fire = true


func _fire_projectile(ammo_item: GameItem, ammo_slot: int) -> void:
	if not ProjectileSpawner:
		push_error("[BowComponent] ProjectileSpawner missing!")
		return

	# Calculate direction
	var dir: Vector2 = Vector2.RIGHT
	if player.has_method("get_last_facing_direction"):
		dir = player.get_last_facing_direction()
	elif player and "last_dir" in player and player.last_dir != Vector2.ZERO:
		dir = player.last_dir.normalized()
	else:
		dir = Vector2.RIGHT if player.scale.x > 0 else Vector2.LEFT

	var spawn_offset: Vector2 = Vector2(1, -1) * dir * -2
	var spawn_pos: Vector2 = player.global_position + spawn_offset

	ProjectileSpawner.spawn_projectile(ammo_item, spawn_pos, dir)

	# Drain stamina
	var stam = player.get_node_or_null("StaminaComponent")
	if stam:
		stam.drain(6.0)

	# Consume ammo + Auto-unequip when reaching 0
	if ammo_item.consumes_on_use:
		PlayerInventory.consume_item(ammo_item.id, 1)

		var equipped_copy = EquipmentManager.get_equipped_item(ammo_slot)
		if equipped_copy:
			equipped_copy.quantity = max(0, equipped_copy.quantity - 1)

			if equipped_copy.quantity <= 0:
				# CORRECT WAY - Use the method that actually exists
				EquipmentManager.unequip_slot(ammo_slot)
				print("[BowComponent] Ammo depleted → unequipped ", ammo_item.display_name, " from slot ", ammo_slot)
			else:
				# Still has ammo left
				EquipmentManager.equipped_changed.emit(ammo_slot, equipped_copy)

	# Debug print
	var current = EquipmentManager.get_equipped_item(ammo_slot)
	var remaining = current.quantity if current else 0
	print("[BowComponent] Fired ", ammo_item.display_name, " (remaining: ", remaining, ")")
