# scripts/entities/freefish.gd
extends Node2D
class_name FreeFish

# ─── TUNABLE PARAMS ───────────────────────────────────────────────
@export var swim_speed: float = 45.0
@export var wiggle_strength: float = 18.0
@export var radius: float = 50.0
@export var limb_angle: float = 0.8
@export var fin_pos: int = 8

@export var water_rect: Rect2 = Rect2(100, 100, 800, 400)

var target_pos: Vector2

@onready var body: Line2D = $Body
@onready var limb_right: Line2D = $limb_right
@onready var limb_left: Line2D = $limb_left
@onready var fin: Line2D = $Fin
@onready var wander_timer: Timer = $WanderTimer

func _ready() -> void:
	_initialize_points()
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	_destination()   # pick first random target
	print("[Fish] Ready - ambient wandering mode")

func _initialize_points() -> void:
	# Body
	for i in range(body.points.size()):
		body.points[i] = Vector2(i * 2, 0)
	
	# Limbs
	for i in range(1, limb_left.points.size()):
		limb_left.points[i] = Vector2(i * 2, 0)
	for i in range(1, limb_right.points.size()):
		limb_right.points[i] = Vector2(i * 2, 0)
	
	# Fin
	for i in range(1, fin.points.size()):
		fin.points[i] = Vector2(i * 2, 0)
	
	# Attach limbs and fin to body
	limb_left.points[0] = body.points[1]
	limb_right.points[0] = body.points[1]
	fin.points[0] = body.points[fin_pos]

func _process(delta: float) -> void:
	var pts = body.points
	var lb_lf = limb_left.points
	var lb_rf = limb_right.points
	var fin_pts = fin.points
	
	# Smooth movement toward target
	if pts.size() > 0:
		pts[0] = pts[0].move_toward(target_pos, swim_speed * delta)
		
		if pts[0].distance_to(target_pos) < 15:
			_destination()
	
	# Attach limbs and fin to body
	lb_lf[0] = pts[1]
	lb_rf[0] = pts[1]
	fin_pts[0] = pts[fin_pos]
	
	# Distance constraints on body (keeps it together)
	for i in range(1, pts.size()):
		pts[i] = pts[i-1] + (pts[i] - pts[i-1]).limit_length(radius)
	
	# Constrain left limb with fixed angle offset
	for i in range(1, lb_lf.size()):
		var body_dir = (pts[i] - pts[i-1]).normalized()
		var offset_dir = body_dir.rotated(-limb_angle)
		lb_lf[i] = lb_lf[i-1] + offset_dir * radius
	
	# Constrain right limb
	for i in range(1, lb_rf.size()):
		var body_dir = (pts[i] - pts[i-1]).normalized()
		var offset_dir = body_dir.rotated(limb_angle)
		lb_rf[i] = lb_rf[i-1] + offset_dir * radius
	
	# Constrain fin
	for i in range(1, fin_pts.size()):
		fin_pts[i] = fin_pts[i-1] + (fin_pts[i] - fin_pts[i-1]).limit_length(radius)
	
	# Apply back to nodes
	body.points = pts
	limb_left.points = lb_lf
	limb_right.points = lb_rf
	fin.points = fin_pts
	
	# Keep fish inside water area
	if pts.size() > 0:
		pts[0].x = clamp(pts[0].x, water_rect.position.x, water_rect.position.x + water_rect.size.x)
		pts[0].y = clamp(pts[0].y, water_rect.position.y, water_rect.position.y + water_rect.size.y)

func _destination() -> void:
	# Pick random point inside water area
	target_pos = Vector2(
		randf_range(water_rect.position.x + 50, water_rect.position.x + water_rect.size.x - 50),
		randf_range(water_rect.position.y + 50, water_rect.position.y + water_rect.size.y - 50)
	)

func _on_wander_timer_timeout() -> void:
	wander_timer.wait_time = randf_range(2.0, 6.0)
	_destination()

func set_water_area(rect: Rect2) -> void:
	water_rect = rect
