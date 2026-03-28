# scripts/components/AnimationComponent.gd
extends Node
class_name AnimationComponent

@onready var sprite: AnimatedSprite2D = $"../SpriteContainer/AnimatedSprite2D"
@onready var movement: MovementComponent = get_parent().get_node_or_null("MovementComponent")

var last_nonzero_dir: Vector2 = Vector2.RIGHT
var is_in_special_animation: bool = false

signal death_anim_completed
signal drink_anim_completed
signal roll_anim_completed   # New

func _ready() -> void:
	if not sprite:
		push_error("[AnimationComponent] AnimatedSprite2D not found!")
	if not movement:
		push_warning("[AnimationComponent] MovementComponent missing!")
		
	# Force ImpactLight off on startup
	var impact_light = get_parent().get_node_or_null("ImpactLight")
	if impact_light:
		impact_light.energy = 0.0

func _process(_delta: float) -> void:
	if not sprite or not movement:
		return
	
	# Skip normal logic during special animations
	if is_in_special_animation:
		return
	
	# Normal idle/walk logic
	var current_dir = movement.move_direction
	if current_dir.length_squared() > 0.01:
		last_nonzero_dir = current_dir.normalized()
	
	var is_moving = get_parent().velocity.length_squared() > 1.0
	var base = "walk" if is_moving else "idle"
	var target_anim = _get_direction_anim(base)
	
	if sprite.animation != target_anim:
		if sprite.sprite_frames.has_animation(target_anim):
			sprite.play(target_anim)
	
	if target_anim.ends_with("_side"):
		sprite.flip_h = last_nonzero_dir.x < 0
	else:
		sprite.flip_h = false

func _get_direction_anim(base: String) -> String:
	var angle = last_nonzero_dir.angle()
	if abs(angle) <= deg_to_rad(45) or abs(angle) >= deg_to_rad(135):
		return base + "_side"
	elif angle > deg_to_rad(45) and angle < deg_to_rad(135):
		return base + "_front"
	else:
		return base + "_back"


# ====================== SPECIAL ANIMATIONS ======================

func play_drink() -> void:
	is_in_special_animation = true
	if sprite and sprite.sprite_frames.has_animation("drink"):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop("drink", false)
		sprite.play("drink")
		await sprite.animation_finished
	is_in_special_animation = false
	drink_anim_completed.emit()

func play_death() -> void:
	is_in_special_animation = true
	print("[AnimationComponent] play_death() started")

	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop("death", false)
		sprite.animation = "death"
		sprite.frame = 0
		
		# Tunable timing - 3 frames
		var frame_time = 0.22   # ← CHANGE THIS to adjust speed (seconds per frame)
		
		for i in range(1, 3):
			await get_tree().create_timer(frame_time).timeout
			sprite.frame = i
		
		await get_tree().create_timer(frame_time * 0.8).timeout   # slight linger on last frame
		
		print("[AnimationComponent] Death animation completed")
	else:
		print("[AnimationComponent] WARNING: No 'death' animation found")
		await get_tree().create_timer(0.8).timeout

	is_in_special_animation = false
	death_anim_completed.emit()

func play_roll(roll_dir: Vector2) -> void:
	is_in_special_animation = true
	
	var anim_name = "roll_side"
	var flip = false
	
	if roll_dir.length_squared() > 0.01:
		last_nonzero_dir = roll_dir.normalized()
	
	var angle = last_nonzero_dir.angle()
	
	if abs(angle) <= deg_to_rad(45) or abs(angle) >= deg_to_rad(135):
		# Side roll
		anim_name = "roll_side"
		flip = last_nonzero_dir.x > 0     # Changed from < 0 to > 0 because your art faces left
	elif angle > deg_to_rad(45) and angle < deg_to_rad(135):
		# Front roll
		anim_name = "roll_front"
	else:
		# Back roll
		anim_name = "roll_back"
	
	if sprite and sprite.sprite_frames.has_animation(anim_name):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop(anim_name, false)
		sprite.flip_h = flip
		sprite.play(anim_name)
		await sprite.animation_finished
	
	is_in_special_animation = false
	roll_anim_completed.emit()
# Flash red when taking damage - stronger at night
func flash_damage() -> void:
	if not sprite or not sprite.material:
		return
	
	var mat = sprite.material as ShaderMaterial
	if not mat: return
	
	var is_dark = false
	if WorldTimeManager:
		var phase = WorldTimeManager.get_current_phase_name()
		is_dark = phase in ["NIGHT", "LATE_NIGHT"]
	
	if is_dark:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.3, 0.3, 1.0))  # Bright red
		mat.set_shader_parameter("flash_intensity", 1.0)
	else:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.15, 0.15, 1.0))
		mat.set_shader_parameter("flash_intensity", 0.85)
	
	await get_tree().create_timer(0.1).timeout
	mat.set_shader_parameter("flash_intensity", 0.0)


# Flash golden when healing - stronger at night
func flash_heal() -> void:
	if not sprite or not sprite.material:
		return
	
	var mat = sprite.material as ShaderMaterial
	if not mat: return
	
	var is_dark = false
	if WorldTimeManager:
		var phase = WorldTimeManager.get_current_phase_name()
		is_dark = phase in ["NIGHT", "LATE_NIGHT"]
	
	if is_dark:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.95, 0.4, 1.0))  # Bright gold
		mat.set_shader_parameter("flash_intensity", 0.95)
	else:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.85, 0.25, 1.0))
		mat.set_shader_parameter("flash_intensity", 0.75)
	
	await get_tree().create_timer(0.25).timeout
	mat.set_shader_parameter("flash_intensity", 0.0)

# Bright impact flash when taking damage
func flash_impact_damage() -> void:
	var light = get_parent().get_node_or_null("ImpactLight")
	if not light: return
	
	light.energy = 3.8
	light.color = Color(1.0, 0.3, 0.25)  # Reddish for damage
	
	var tween = create_tween()
	tween.tween_property(light, "energy", 0.0, 0.35).set_trans(Tween.TRANS_QUAD)


# Golden healing flash
func flash_impact_heal() -> void:
	var light = get_parent().get_node_or_null("ImpactLight")
	if not light: return
	
	light.energy = 3.2
	light.color = Color(1.0, 0.95, 0.45)  # Golden
	
	var tween = create_tween()
	tween.tween_property(light, "energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD)

# ====================== BONFIRE ANIMATIONS ======================

func play_sit() -> void:
	is_in_special_animation = true
	if sprite and sprite.sprite_frames.has_animation("sit"):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop("sit", true)   # sit should usually loop
		sprite.play("sit")
		print("[AnimationComponent] play_sit() started")
	else:
		push_warning("[AnimationComponent] 'sit' animation not found!")
		is_in_special_animation = false


func play_stand() -> void:
	is_in_special_animation = true
	if sprite and sprite.sprite_frames.has_animation("stand"):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop("stand", false)
		sprite.play("stand")
		print("[AnimationComponent] play_stand() started")
		await sprite.animation_finished
	else:
		push_warning("[AnimationComponent] 'stand' animation not found!")
	
	is_in_special_animation = false
