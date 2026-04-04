# GrassBlade.gd
extends Node2D

@export var push_strength: float = 32.0
@export var recovery_speed: float = 6.0

@onready var blade_back: Sprite2D = $BladeBack
@onready var blade_front: Sprite2D = $BladeFront
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var base_rotation: float = 0.0
var target_rotation: float = 0.0
var is_pushed: bool = false

func _ready() -> void:
	base_rotation = rotation_degrees
	target_rotation = base_rotation
	
	if anim_player and anim_player.has_animation("wind_sway"):
		anim_player.play("wind_sway")
		anim_player.seek(randf() * anim_player.current_animation_length, true)
	


func _process(delta: float) -> void:
	if is_pushed:
		rotation_degrees = lerp(rotation_degrees, target_rotation, recovery_speed * delta)
	else:
		rotation_degrees = lerp(rotation_degrees, base_rotation, recovery_speed * delta)


func push_away(player_direction: Vector2) -> void:
	is_pushed = true
	var bend = sign(player_direction.x) * push_strength
	target_rotation = base_rotation + bend
	if anim_player:
		anim_player.pause()


func release() -> void:
	is_pushed = false
	if anim_player and anim_player.has_animation("wind_sway"):
		anim_player.play("wind_sway")
	#print("[GrassBlade] Released: ", name)   # comment out for now to reduce spam
