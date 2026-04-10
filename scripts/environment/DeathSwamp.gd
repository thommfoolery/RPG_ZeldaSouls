# scripts/environment/DeathSwamp.gd
extends Area2D

@export var build_up_per_second: float = 40.0   # visual helper

var _death_effect: StatusEffect = null
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_death_effect = load("res://resources/statuseffect/InstadeathEffect.tres") as StatusEffect
	if not _death_effect:
		push_error("[DeathSwamp] Failed to load InstadeathEffect.tres!")
	
	set_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[DeathSwamp] Player ENTERED")
		_player_inside = true
		if _death_effect:
			StatusEffectManager.apply_effect(_death_effect, self)
		set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[DeathSwamp] Player LEFT")
		_player_inside = false
		set_process(false)


func _process(_delta: float) -> void:
	if _death_effect and _player_inside:
		StatusEffectManager.apply_effect(_death_effect, self)


func is_player_inside() -> bool:
	return _player_inside
