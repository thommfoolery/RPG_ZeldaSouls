# GrassPatch.gd
extends Node2D

@export var grass_blade_scene: PackedScene
@export var blade_count: int = 18
@export var patch_radius: float = 55.0      # NEW: How far blades can spread from center
@export var push_radius: float = 85.0       # How close player needs to be to push blades
@export var min_scale: float = 0.85
@export var max_scale: float = 1.18

var blades: Array[Node2D] = []

func _ready() -> void:
	if not grass_blade_scene:
		return
	
	for i in blade_count:
		var blade = grass_blade_scene.instantiate()
		
		# Better circular spreading using radius
		var angle = randf() * TAU                    # random angle 0 to 360 degrees
		var distance = randf_range(0, patch_radius)  # random distance from center
		
		blade.position.x = cos(angle) * distance
		blade.position.y = sin(angle) * distance * 0.6   # flatten a bit so it feels more ground-level
		
		# Random scale for natural variation
		var scale_var = randf_range(min_scale, max_scale)
		blade.scale = Vector2(scale_var, scale_var)
		
		# Slight random rotation
		blade.rotation_degrees = randf_range(-8, 8)
		
		add_child(blade)
		blades.append(blade)
	


func _physics_process(_delta: float) -> void:
	if not PlayerManager or not PlayerManager.current_player:
		return
	
	var player_pos = PlayerManager.current_player.global_position
	
	var pushed_count = 0
	for blade in blades:
		var dist = blade.global_position.distance_to(player_pos)
		
		if dist < push_radius:
			var direction = (blade.global_position - player_pos).normalized()
			blade.push_away(direction)
			pushed_count += 1
		else:
			if blade.has_method("release"):
				blade.release()
	
