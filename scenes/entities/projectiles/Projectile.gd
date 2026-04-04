# entities/projectiles/Projectile.gd
extends Area2D
class_name Projectile

@export var game_item: GameItem = null

var velocity: Vector2 = Vector2.ZERO
var lifetime_timer: Timer
var launch_dir: Vector2 = Vector2.RIGHT
var trail_vfx: Node2D = null

# ─── GENTLER FAKE-3D ARC ───
var height: float = 0.0
var height_velocity: float = 0.0
const GRAVITY: float = 850.0
const INITIAL_UP_FORCE: float = 180.0
const HEIGHT_VISUAL_SCALE: float = 0.45

var is_arc_trajectory: bool = false

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
	else:
		print("[Projectile] Using default sprite")
	
	# Shadow
	var shadow = $Shadow
	if shadow and $Sprite2D.texture:
		shadow.texture = $Sprite2D.texture
		shadow.modulate = Color(0, 0, 0, 0.65)
		shadow.z_index = -1
	
	# Trail VFX
	if game_item.get("projectile_trail_vfx") and game_item.projectile_trail_vfx is PackedScene:
		trail_vfx = game_item.projectile_trail_vfx.instantiate()
		add_child(trail_vfx)
		trail_vfx.position = Vector2.ZERO
		print("[Projectile] Attached trail VFX for ", game_item.display_name)
	
	# Lifetime
	lifetime_timer = $LifetimeTimer
	var lifetime = game_item.get("lifetime") if "lifetime" in game_item else 5.0
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var traj: String = game_item.get("trajectory_type") if "trajectory_type" in game_item else "Straight"
	is_arc_trajectory = (traj == "Arc")
	print("[Projectile] Spawned → ", game_item.display_name, " | trajectory=", traj)

func _deferred_launch(spawn_pos: Vector2, dir: Vector2) -> void:
	if not is_instance_valid(self): return
	launch_dir = dir.normalized()
	global_position = spawn_pos
	launch(dir, spawn_pos)

func launch(direction: Vector2, spawn_pos: Vector2) -> void:
	print("[Projectile] LAUNCH() CALLED | pos=", spawn_pos.round(), " | dir=", direction)
	global_position = spawn_pos
	var speed: float = game_item.get("speed") if "speed" in game_item else 600.0
	velocity = direction.normalized() * speed
	rotation = direction.angle()
	
	if is_arc_trajectory:
		height = 18.0
		height_velocity = INITIAL_UP_FORCE
		$Sprite2D.position.y = -height * HEIGHT_VISUAL_SCALE

func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO: return
	
	if is_arc_trajectory:
		global_position += velocity * delta
		height_velocity -= GRAVITY * delta
		height += height_velocity * delta
		if height <= 0:
			height = 0
			height_velocity = 0
		$Sprite2D.position.y = -height * HEIGHT_VISUAL_SCALE
	else:
		global_position += velocity * delta
	
	var shadow = $Shadow
	if shadow:
		shadow.global_position = global_position + Vector2(0, 12)

# ─── SAFE TRAIL DETACH (bulletproof version) ───
func _detach_trail() -> void:
	if not trail_vfx or not is_instance_valid(trail_vfx):
		return
	
	print("[Projectile] Detaching trail VFX so it survives projectile death")
	
	# Find the best parent safely
	var new_parent: Node = get_tree().current_scene
	
	var ysort = get_tree().current_scene.get_node_or_null("ysort")
	if not ysort:
		ysort = get_tree().current_scene.get_node_or_null("YSort")
	if not ysort:
		ysort = get_tree().current_scene.get_node_or_null("Ysort")
	
	if ysort:
		new_parent = ysort
	
	# Final safety - only reparent if we have a valid parent
	if new_parent and is_instance_valid(new_parent):
		trail_vfx.reparent(new_parent)
		trail_vfx.global_position = global_position
		
		# Auto-cleanup after short linger
		var death_timer = Timer.new()
		death_timer.wait_time = 0.8
		death_timer.one_shot = true
		death_timer.timeout.connect(trail_vfx.queue_free)
		trail_vfx.add_child(death_timer)
		death_timer.start()
	else:
		print("[Projectile] WARNING: Could not find valid parent for trail VFX - freeing immediately")
		trail_vfx.queue_free()

func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

func _hit_target(target: Node) -> void:
	if target == get_tree().get_first_node_in_group("player"): return
	
	if target.is_in_group("enemy") or target.is_in_group("breakable"):
		if target.has_method("take_damage"):
			var dmg: float = game_item.get("damage") if "damage" in game_item else 0.0
			target.take_damage(dmg, game_item)
	
	_detach_trail()
	_spawn_explosion()
	queue_free()

func _on_lifetime_timeout() -> void:
	_detach_trail()
	_spawn_explosion()
	queue_free()

func _spawn_explosion() -> void:
	if not game_item or not game_item.get("explosion_scene"): return
	
	var explosion = game_item.explosion_scene.instantiate()
	var parent = get_parent() if get_parent() else get_tree().current_scene
	parent.add_child(explosion)
	explosion.global_position = global_position
	print("[Projectile] *** SPAWNED EXPLOSION at ", global_position.round(), " for ", game_item.display_name, " ***")
	explosion.call_deferred("_start_one_shot_particles")
	
	var life_timer = Timer.new()
	life_timer.wait_time = 0.75
	life_timer.one_shot = true
	life_timer.timeout.connect(explosion.queue_free)
	explosion.add_child(life_timer)
	life_timer.start()
