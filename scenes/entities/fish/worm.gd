# scripts/entities/worm.gd
extends Node2D
class_name Worm

# ─── MOVEMENT ─────────────────────────────────────────────────────
@export var swim_speed: float = 55.0
@export var dart_speed: float = 180.0

# ─── CHAIN / SHAPE ────────────────────────────────────────────────
@export var chain_length: int = 12
@export var segment_distance: float = 12.0

# ─── HIDING BEHAVIOR ──────────────────────────────────────────────
@export var hide_duration_min: float = 8.0
@export var hide_duration_max: float = 14.0
@export var hide_speed: float = 1.8          # how fast it burrows (higher = faster)
@export var emerge_speed: float = 3.0        # how fast it grows back

# ─── VISUALS ──────────────────────────────────────────────────────
@export var base_color: Color = Color(0.55, 0.45, 0.35, 0.95)
@export var fade_strength: float = 0.9       # how dark it gets when hiding (0.0 = invisible, 1.0 = still visible)

@export var water_rect: Rect2 = Rect2(100, 100, 600, 300)

var points: Array[Vector2] = []
var velocity: Vector2 = Vector2.ZERO

var is_hiding: bool = false
var hide_progress: float = 0.0   # 0 = fully visible, 1 = fully hidden

@onready var body: Line2D = $Body
@onready var wander_timer: Timer = $WanderTimer
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	_initialize_chain()
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
	

func _initialize_chain() -> void:
	points.clear()
	var start_pos = global_position
	for i in chain_length:
		points.append(start_pos + Vector2(i * segment_distance * -1, 0))
	body.points = PackedVector2Array(points)

func _process(delta: float) -> void:
	if is_hiding:
		hide_progress = move_toward(hide_progress, 1.0, delta * hide_speed)
		if hide_progress >= 0.98:
			_pop_up_nearby()
	else:
		hide_progress = move_toward(hide_progress, 0.0, delta * emerge_speed)
	
	# Normal movement when not hiding
	if not is_hiding:
		velocity = velocity.lerp(Vector2(randf_range(-1,1), randf_range(-1,1)) * swim_speed, 0.12)
		points[0] += velocity * delta
		
		# Keep inside water
		points[0].x = clamp(points[0].x, water_rect.position.x, water_rect.position.x + water_rect.size.x)
		points[0].y = clamp(points[0].y, water_rect.position.y, water_rect.position.y + water_rect.size.y)
	
	_apply_constraints()
	_update_visuals()
	
	if detection_area:
		detection_area.global_position = points[0]

func _apply_constraints() -> void:
	for i in range(1, points.size()):
		var dir = points[i] - points[i-1]
		var dist = dir.length()
		if dist > segment_distance:
			points[i] = points[i-1] + (dir.normalized() * segment_distance)

func _update_visuals() -> void:
	var visible_count = max(2, int(chain_length * (1.0 - hide_progress)))
	var display_points = PackedVector2Array()
	for i in visible_count:
		display_points.append(points[i])
	
	body.points = display_points
	
	# Safer color assignment
	if body.default_color != base_color:
		body.default_color = base_color
	
	body.modulate.a = 1.0 - (hide_progress * fade_strength)

func _on_wander_timer_timeout() -> void:
	wander_timer.wait_time = randf_range(2.0, 6.0)

func _on_detection_body_entered(body_node: Node2D) -> void:
	if body_node.is_in_group("player") and not is_hiding:
		is_hiding = true
		hide_progress = 0.0

func _pop_up_nearby() -> void:
	var offset = Vector2(randf_range(-100, 100), randf_range(-80, 80))
	points[0] += offset
	
	points[0].x = clamp(points[0].x, water_rect.position.x, water_rect.position.x + water_rect.size.x)
	points[0].y = clamp(points[0].y, water_rect.position.y, water_rect.position.y + water_rect.size.y)
	
	for i in range(1, points.size()):
		points[i] = points[0] + Vector2(i * segment_distance * -1, 0)
	
	is_hiding = false
	hide_progress = 0.0
	

func set_water_area(rect: Rect2) -> void:
	water_rect = rect
