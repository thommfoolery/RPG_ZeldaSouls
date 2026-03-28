# TransitionPoint.gd  ← this file stays almost unchanged
extends Area2D
class_name TransitionPoint

@export var target_area_id: String = ""
@export var spawn_marker_name: String = "PlayerEntranceMarker"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("[TransitionPoint] Ready → target=", target_area_id, " marker=", spawn_marker_name)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_area_id.is_empty():
		push_warning("[TransitionPoint] No target_area_id set!")
		return
	
	print("[TransitionPoint] Triggered → ", target_area_id, " @ marker ", spawn_marker_name)
	AreaTransitionService.change_to_area(target_area_id, spawn_marker_name)
