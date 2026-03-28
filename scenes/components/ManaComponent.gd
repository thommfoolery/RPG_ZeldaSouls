# scripts/components/ManaComponent.gd
extends Node
class_name ManaComponent

@export var base_mana: float = 80.0
@export var attunement_scaling: float = 12.0

var current_mana: float = 80.0
var max_mana: float = 80.0

signal mana_changed(current: float, max_mana: float)

func _ready() -> void:
	update_max_mana_from_stats()
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)

func update_max_mana_from_stats() -> void:
	var attunement = 10
	if PlayerStats and "attunement" in PlayerStats:
		attunement = PlayerStats.attunement
	
	max_mana = base_mana + (attunement * attunement_scaling)
	mana_changed.emit(current_mana, max_mana)

func spend_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

# Called from bonfire
func restore_full() -> void:
	current_mana = max_mana
	mana_changed.emit(current_mana, max_mana)
