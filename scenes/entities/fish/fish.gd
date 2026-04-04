# scripts/entities/fish.gd
extends Node2D
class_name Fish

# ─── MOVEMENT ─────────────────────────────────────────────────────
@export var swim_speed: float = 45.0
@export var turn_speed: float = 1.8
@export var wander_strength: float = 0.35

# ─── CHAIN / SHAPE ────────────────────────────────────────────────
@export var chain_length: int = 14
@export var segment_distance: float = 11.0

# ─── VISUALS ──────────────────────────────────────────────────────
@export var body_color: Color = Color(0.16, 0.48, 0.72)  # nice blue

@export var water_rect: Rect2 = Rect2(50, 50, 700, 400)

var points: Array[Vector2] = []
var velocity: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.RIGHT

@onready var wander_timer: Timer = $WanderTimer

func _ready() -> void:
	_initialize_chain()
	
	if wander_timer:
		wander_timer.timeout.connect(_on_wander_timer_timeout)
		wander_timer.start(randf_range(3.0, 7.0))
	
	target_direction = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()

func _initialize_chain() -> void:
	points.clear()
	var start_pos = global_position
	for i in chain_length:
		points.append(start_pos + Vector2(i * segment_distance * -1, 0))

func _process(delta: float) -> void:
	var wander_force = Vector2(
		randf_range(-wander_strength, wander_strength),
		randf_range(-wander_strength, wander_strength)
	)
	
	target_direction = (target_direction + wander_force).normalized()
	velocity = velocity.lerp(target_direction * swim_speed, turn_speed * delta)
	
	points[0] += velocity * delta
	
	_clamp_to_water_with_bounce()
	_apply_constraints()
	queue_redraw()   # Important: tells Godot to call _draw()

func _clamp_to_water_with_bounce() -> void:
	var margin = 30.0
	var pos = points[0]
	
	if pos.x < water_rect.position.x + margin:
		velocity.x = abs(velocity.x) * 0.7
		points[0].x = water_rect.position.x + margin
	elif pos.x > water_rect.position.x + water_rect.size.x - margin:
		velocity.x = -abs(velocity.x) * 0.7
		points[0].x = water_rect.position.x + water_rect.size.x - margin
	
	if pos.y < water_rect.position.y + margin:
		velocity.y = abs(velocity.y) * 0.7
		points[0].y = water_rect.position.y + margin
	elif pos.y > water_rect.position.y + water_rect.size.y - margin:
		velocity.y = -abs(velocity.y) * 0.7
		points[0].y = water_rect.position.y + water_rect.size.y - margin

func _apply_constraints() -> void:
	for i in range(1, points.size()):
		var dir = points[i] - points[i-1]
		var dist = dir.length()
		if dist > segment_distance:
			points[i] = points[i-1] + (dir.normalized() * segment_distance)
		
		if i > 1:
			var prev_dir = points[i-1] - points[i-2]
			var current_dir = points[i] - points[i-1]
			var angle_diff = prev_dir.angle_to(current_dir)
			if abs(angle_diff) > 0.75:
				var target_angle = prev_dir.angle() + sign(angle_diff) * 0.75
				points[i] = points[i-1] + Vector2.from_angle(target_angle) * segment_distance

func _draw() -> void:
	if points.size() < 2:
		return
	
	# Draw thick body with round caps
	draw_polyline(points, body_color, 18.0, true)

func _on_wander_timer_timeout() -> void:
	if wander_timer:
		wander_strength = randf_range(0.25, 0.55)
		wander_timer.wait_time = randf_range(4.0, 9.0)
		wander_timer.start()

func get_head_direction() -> Vector2:
	if points.size() >= 2:
		return (points[0] - points[1]).normalized()
	return Vector2.RIGHT
