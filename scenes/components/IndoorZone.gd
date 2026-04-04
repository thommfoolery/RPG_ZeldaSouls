# scripts/zones/IndoorZone.gd
extends Area2D
class_name IndoorZone

@export var roof_node_path: NodePath = NodePath("../CaveRoof")   # Adjust if your roof is elsewhere

@onready var roof: Node = get_node_or_null(roof_node_path)

func _ready() -> void:
	# Safety: only detect player
	collision_layer = 0
	collision_mask = 1 << 0   # assuming player is on layer 0
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("[IndoorZone] Ready — monitoring ", name, " | roof path: ", roof_node_path)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	print("[IndoorZone] Player ENTERED cave — hiding roof + enabling indoor lighting")
	_fade_roof(0.0)   # fully transparent

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	print("[IndoorZone] Player EXITED cave — showing roof + disabling indoor lighting")
	_fade_roof(1.0)   # fully visible

func _fade_roof(target_alpha: float) -> void:
	if not roof:
		push_warning("[IndoorZone] Roof node not found at path: " + str(roof_node_path))
		return
	
	var tween = create_tween()
	tween.tween_property(roof, "modulate:a", target_alpha, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	print("[IndoorZone] Roof fade started → alpha = ", target_alpha)
