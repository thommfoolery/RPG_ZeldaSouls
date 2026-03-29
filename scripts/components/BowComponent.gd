# scripts/components/BowComponent.gd
extends Node
class_name BowComponent

@onready var player = get_parent() as CharacterBody2D
var cross_hud: CrossHUD = null

# ─── Cooldown + Held flags for triggers ───
var can_fire: bool = true
const FIRE_COOLDOWN: float = 0.25

# Prevent double-fire on release
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
		print("[BowComponent] Connected to RB/RT/LB/LT (tap-to-fire only)")

func _process(_delta: float) -> void:
	# Reset held flags when trigger is released
	if not Input.is_action_pressed("right_hand_heavy"):
		right_heavy_held = false
	if not Input.is_action_pressed("left_hand_heavy"):
		left_heavy_held = false

# ─── RIGHT HAND ───
func _on_right_primary() -> void:
	print("[BowComponent-DEBUG] RB pressed")
	if cross_hud:
		_fire_from_hand(cross_hud.active_right_index, 9)

func _on_right_heavy(charge_time: float = 0.0) -> void:
	print("[BowComponent-DEBUG] RT pressed (charge_time=", charge_time, ")")
	if cross_hud and not right_heavy_held:
		right_heavy_held = true
		_fire_from_hand(cross_hud.active_right_index, 10)

# ─── LEFT HAND ───
func _on_left_primary() -> void:
	print("[BowComponent-DEBUG] LB pressed")
	if cross_hud:
		_fire_from_hand(cross_hud.active_left_index, 9)

func _on_left_heavy(charge_time: float = 0.0) -> void:
	print("[BowComponent-DEBUG] LT pressed (charge_time=", charge_time, ")")
	if cross_hud and not left_heavy_held:
		left_heavy_held = true
		_fire_from_hand(cross_hud.active_left_index, 10)

# ─── Core logic — only fires if bow is in the currently active slot ───
func _fire_from_hand(active_slot: int, ammo_slot: int) -> void:
	if Global.is_death_respawn or Global.is_in_menu or not player or not can_fire:
		return

	# Only check the currently active hand slot
	var bow_item = EquipmentManager.get_equipped_item(active_slot)
	if not bow_item or bow_item.weapon_type != "Bow":
		return

	# Get ammo
	var ammo_item = EquipmentManager.get_equipped_item(ammo_slot)
	if not ammo_item or ammo_item.category != "Ammo":
		print("[BowComponent] No ammo in slot ", ammo_slot)
		return

	_fire_projectile(ammo_item, ammo_slot)

	can_fire = false
	await get_tree().create_timer(FIRE_COOLDOWN).timeout
	can_fire = true

# ─── Fire through spawner ───
func _fire_projectile(ammo_item: GameItem, ammo_slot: int) -> void:
	if not ProjectileSpawner:
		push_error("[BowComponent] ProjectileSpawner missing!")
		return

	var dir: Vector2 = Vector2.RIGHT
	if player.has_method("get_last_facing_direction"):
		dir = player.get_last_facing_direction()
	elif player and "last_dir" in player and player.last_dir != Vector2.ZERO:
		dir = player.last_dir.normalized()
	elif player and "last_nonzero_dir" in player:
		dir = player.last_nonzero_dir
	elif player:
		dir = Vector2.RIGHT if player.scale.x > 0 else Vector2.LEFT

	var spawn_offset: Vector2 = Vector2(1, -1) * dir * -2
	var spawn_pos: Vector2 = player.global_position + spawn_offset

	ProjectileSpawner.spawn_projectile(ammo_item, spawn_pos, dir)

	var stam = player.get_node_or_null("StaminaComponent")
	if stam:
		stam.drain(6.0)

	if ammo_item.consumes_on_use:
		PlayerInventory.consume_item(ammo_item.id, 1)

		var equipped_copy = EquipmentManager.get_equipped_item(ammo_slot)
		if equipped_copy:
			equipped_copy.quantity = max(0, equipped_copy.quantity - 1)

		EquipmentManager.equipped_changed.emit(ammo_slot, equipped_copy)

	print("[BowComponent] Fired ", ammo_item.display_name, " from bow")
