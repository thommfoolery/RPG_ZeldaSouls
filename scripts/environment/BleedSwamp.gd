# scripts/environment/BleedSwamp.gd
extends Area2D

@export var build_up_per_second: float = 55.0   # visual helper

var _bleed_effect: StatusEffect = null
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_bleed_effect = load("res://resources/statuseffect/BleedEffect.tres") as StatusEffect
	if not _bleed_effect:
		push_error("[BleedSwamp] Failed to load BleedEffect.tres!")
	
	set_process(false)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[BleedSwamp] Player ENTERED")
		_player_inside = true
		if _bleed_effect:
			StatusEffectManager.apply_effect(_bleed_effect, self)
		set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[BleedSwamp] Player LEFT")
		_player_inside = false
		set_process(false)


func _process(_delta: float) -> void:
	if _bleed_effect and _player_inside:
		StatusEffectManager.apply_effect(_bleed_effect, self)


func is_player_inside() -> bool:
	return _player_inside
