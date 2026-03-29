# entities/projectiles/Projectile.gd
extends Area2D
class_name Projectile

@export var game_item: GameItem = null

var velocity: Vector2 = Vector2.ZERO
var lifetime_timer: Timer
var launch_dir: Vector2 = Vector2.RIGHT
var trail_vfx: Node2D = null

func _ready() -> void:
	print("[Projectile] === _ready() STARTED for ", game_item.display_name if game_item else "NO ITEM", " ===")
	if not game_item:
		push_error("[Projectile] No GameItem assigned!")
		queue_free()
		return

	print("[Projectile] GameItem OK → ", game_item.display_name)

	# Sprite
	if game_item.get("projectile_sprite") and game_item.projectile_sprite is Texture2D:
		$Sprite2D.texture = game_item.projectile_sprite
		print("[Projectile] Using custom sprite from GameItem")
	else:
		print("[Projectile] Using default sprite")

	# Shadow
	var shadow = $Shadow
	if shadow and $Sprite2D.texture:
		shadow.texture = $Sprite2D.texture
		shadow.modulate = Color(0, 0, 0, 0.65)

	# Trail VFX
	if game_item.get("projectile_trail_vfx") and game_item.projectile_trail_vfx is PackedScene:
		trail_vfx = game_item.projectile_trail_vfx.instantiate()
		add_child(trail_vfx)
		trail_vfx.position = Vector2.ZERO
		print("[Projectile] Attached trail VFX for ", game_item.display_name)

	# Lifetime timer
	lifetime_timer = $LifetimeTimer
	var lifetime = game_item.get("lifetime") if "lifetime" in game_item else 5.0
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	var traj: String = game_item.get("trajectory_type") if "trajectory_type" in game_item else "Straight"
	print("[Projectile] Spawned → ", game_item.display_name, " | trajectory=", traj)

func _deferred_launch(spawn_pos: Vector2, dir: Vector2) -> void:
	if not is_instance_valid(self):
		return
	launch_dir = dir.normalized()
	global_position = spawn_pos
	launch(dir, spawn_pos)

func launch(direction: Vector2, spawn_pos: Vector2) -> void:
	print("[Projectile] LAUNCH() CALLED | pos=", spawn_pos.round(), " | dir=", direction)
	global_position = spawn_pos
	var speed: float = game_item.get("speed") if "speed" in game_item else 600.0
	velocity = direction.normalized() * speed
	rotation = direction.angle()
	print("[Projectile] LAUNCHED | velocity=", velocity, " | speed=", speed)

func _physics_process(delta: float) -> void:
	if velocity != Vector2.ZERO:
		global_position += velocity * delta
		var traj: String = game_item.get("trajectory_type") if "trajectory_type" in game_item else "Straight"
		if traj == "Arc":
			velocity.y += 380 * delta

	# Shadow
	var shadow = $Shadow
	if shadow:
		var factor = abs(launch_dir.x)
		var offset = Vector2(0, 12 * factor)
		shadow.global_position = global_position + offset
		shadow.z_index = -1

func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

func _hit_target(target: Node) -> void:
	if target == get_tree().get_first_node_in_group("player"):
		return
	if target.is_in_group("enemy") or target.is_in_group("breakable"):
		if target.has_method("take_damage"):
			var dmg: float = game_item.get("damage") if "damage" in game_item else 0.0
			target.take_damage(dmg, game_item)

	_spawn_explosion()
	queue_free()

func _on_lifetime_timeout() -> void:
	_spawn_explosion()
	queue_free()

# ─── BULLETPROOF EXPLOSION SPAWN (fixes one_shot particles) ───
func _spawn_explosion() -> void:
	if not game_item or not game_item.get("explosion_scene"):
		print("[Projectile] No explosion_scene defined on ", game_item.display_name if game_item else "null item")
		return

	var explosion = game_item.explosion_scene.instantiate()
	if not explosion:
		push_error("[Projectile] Failed to instantiate explosion_scene")
		return

	var parent = get_parent() if get_parent() else get_tree().current_scene
	parent.add_child(explosion)
	explosion.global_position = global_position

	print("[Projectile] *** SPAWNED EXPLOSION at ", global_position.round(), " for ", game_item.display_name, " ***")

	# Defer starting one-shot particles so _ready() finishes first
	explosion.call_deferred("_start_one_shot_particles")

	# Guarantee the explosion lives long enough for the burst
	var life_timer = Timer.new()
	life_timer.wait_time = 1.75
	life_timer.timeout.connect(explosion.queue_free)
	explosion.add_child(life_timer)
	life_timer.start()
