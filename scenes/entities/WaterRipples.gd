# WaterRipples.gd
# Attach this to the WaterRipples (GPUParticles2D) node
extends GPUParticles2D

@onready var player := get_parent() as CharacterBody2D
@onready var water_detector := player.get_node_or_null("WaterDetector") as Area2D

var is_on_water := false

func _ready() -> void:
	print("[WaterRipples] READY - Water ripple system starting...")
	
	# Basic particle settings (you can still change these in the inspector)
	amount = 12
	lifetime = 1.4
	explosiveness = 0.0
	randomness = 0.35
	speed_scale = 0.9
	
	if not water_detector:
		push_error("[WaterRipples] CRITICAL: WaterDetector node not found on player!")
		print("[WaterRipples] Make sure you named it exactly 'WaterDetector'")
		return
	
	# Connect signals with debug
	water_detector.body_entered.connect(_on_water_body_entered)
	water_detector.body_exited.connect(_on_water_body_exited)
	
	print("[WaterRipples] Successfully connected to WaterDetector")


func _process(_delta: float) -> void:
	var moving = player.velocity.length() > 35.0
	
	var should_emit = is_on_water and moving
	
	if emitting != should_emit:
		emitting = should_emit
		print("[WaterRipples] Emitting changed → ", emitting, " | On water: ", is_on_water, " | Moving: ", moving)


# ====================== DEBUG HEAVY ======================
func _on_water_body_entered(body: Node2D) -> void:
	print("[WaterRipples] body_entered → ", body.name, " (path: ", body.get_path(), ")")
	
	# Extra safety checks
	if body.name == "Water" or body.get_parent().name == "Water" or "WaterArea" in body.name:
		is_on_water = true
		print("[WaterRipples] ✅ PLAYER ENTERED WATER")
	else:
		print("[WaterRipples] Ignored body (not water): ", body.name)


func _on_water_body_exited(body: Node2D) -> void:
	print("[WaterRipples] body_exited → ", body.name)
	
	if body.name == "Water" or body.get_parent().name == "Water" or "WaterArea" in body.name:
		is_on_water = false
		print("[WaterRipples] ❌ PLAYER LEFT WATER")
	else:
		print("[WaterRipples] Ignored exit (not water): ", body.name)
