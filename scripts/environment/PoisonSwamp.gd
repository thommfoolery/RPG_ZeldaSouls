# scripts/environment/PoisonSwamp.gd
extends Area2D

@export var build_up_per_second: float = 45.0   # visual helper only

var _poison_effect: StatusEffect = null
var _player_inside: bool = false   # ← This is the correct, simple flag

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_poison_effect = load("res://resources/statuseffect/PoisonEffect.tres") as StatusEffect
	if not _poison_effect:
		push_error("[PoisonSwamp] Failed to load PoisonEffect.tres!")
	
	set_process(false)   # start disabled


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[PoisonSwamp] Player ENTERED")
		_player_inside = true
		if _poison_effect:
			StatusEffectManager.apply_effect(_poison_effect, self)
		set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[PoisonSwamp] Player LEFT")
		_player_inside = false
		set_process(false)


func _process(_delta: float) -> void:
	if _poison_effect and _player_inside:
		StatusEffectManager.apply_effect(_poison_effect, self)


# Public method the manager expects
func is_player_inside() -> bool:
	return _player_inside
