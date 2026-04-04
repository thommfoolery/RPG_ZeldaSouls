extends CharacterBody2D

@export var speed: float = 80.0  # fallback if component missing

@onready var player = get_parent().get_node("Player") if get_parent().has_node("Player") else null
@onready var sprite: AnimatedSprite2D = $SpriteContainer.get_node_or_null("AnimatedSprite2D")
@onready var camera: Camera2D = $Camera2D  # ← added for debug/camera check

@onready var movement: MovementComponent = $MovementComponent



var last_dir := Vector2.RIGHT  # default facing right
var input_dir := Vector2.ZERO

func _ready() -> void:
	print("[PLAYER-LIFECYCLE] player.gd _ready() START | Instance ID: ", get_instance_id(), " | Path: ", get_path())
	if not sprite:
		push_error("[Player] AnimatedSprite2D child MISSING! Check player.tscn")
	if not camera:
		push_error("[Player] Camera2D child MISSING! Check player.tscn")
	
	print("[Player] _ready() started | Path:", get_path())
	add_to_group("player")
	print("[Player] Groups after add:", get_groups())
	
	# Debug sprite node
	if sprite:
		print("[Player] Sprite found:", sprite.name, " | Animations:", sprite.sprite_frames.get_animation_names())
	else:
		push_error("[Player] $AnimatedSprite2D is NULL! Check scene tree naming/path")
	
	# Self-register with PlayerManager
	print("[PLAYER-LIFECYCLE] player.gd _ready() FINISHED | Instance ID: ", get_instance_id())

	
	# ─── NEW: Deferred position check after everything settles ───
	call_deferred("_debug_final_position_after_ready")
	# ─── End debug addition ───

	if not movement:
		push_warning("[Player] MovementComponent missing - sprint speed won't increase")

func _debug_final_position_after_ready() -> void:
	await get_tree().create_timer(0.1).timeout  # give engine/camera one more frame
	if is_instance_valid(self):
		print("[Player DEBUG] Final pos after _ready + 0.1s → global: ", global_position.round())
		print(" └─ Local pos: ", position.round())
		print(" └─ Velocity: ", velocity.round())
		print(" └─ Camera global pos: ", camera.global_position.round() if camera else "[no camera]")
	else:
		print("[Player DEBUG] Player instance invalid in deferred check!")

func _physics_process(delta: float) -> void:
	# ── HARD GLOBAL LOCK ──
	# Respect InputManager.blocked from ANY menu (Bonfire, Character, etc.)
	if InputManager.input_blocked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# RESPECT SPECIAL ANIMATIONS - Highest priority
	if sprite and (sprite.animation == "drink" or sprite.animation == "death" or sprite.animation.begins_with("roll")):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Normal movement and animation logic
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		last_dir = input_dir.normalized()

	var actual_speed = movement.current_speed if movement else speed
	velocity = input_dir * actual_speed

	var angle = last_dir.angle()
	if abs(angle) <= PI/4 or abs(angle) >= 3*PI/4:
		if sprite: sprite.play("walk_side" if velocity.length() > 0 else "idle_side")
		if sprite: sprite.flip_h = angle > 0
	elif angle > PI/4 and angle < 3*PI/4:
		if sprite: sprite.play("walk_front" if velocity.length() > 0 else "idle_front")
		if sprite: sprite.flip_h = false
	else:
		if sprite: sprite.play("walk_back" if velocity.length() > 0 else "idle_back")
		if sprite: sprite.flip_h = false

	if input_dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		if abs(last_dir.x) > abs(last_dir.y):
			if sprite: sprite.play("idle_side")
			if sprite: sprite.flip_h = last_dir.x < 0
		elif last_dir.y > 0:
			if sprite: sprite.play("idle_front")
		else:
			if sprite: sprite.play("idle_back")

	move_and_slide()
func _on_scene_loaded() -> void:
	# Reset animation lock when new scene is loaded
	if sprite:
		sprite.play("idle_front")  # Force reset to idle
	velocity = Vector2.ZERO
	print("[Player] Reset animation and velocity on scene load")
