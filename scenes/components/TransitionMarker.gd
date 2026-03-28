# res://scenes/components/TransitionMarker.gd
@tool
class_name TransitionMarker
extends Marker2D

@export var marker_id: String = "PlayerEntranceMarker" :
	set(value):
		marker_id = value
		if Engine.is_editor_hint():
			name = "Marker_" + value   # optional: auto-rename in editor for clarity

@export var one_shot: bool = false          # optional: disable after first use
@export var direction_facing: Vector2 = Vector2.RIGHT  # optional: force player facing on spawn

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("transition_markers")
	print("[TransitionMarker] Ready → id:", marker_id, " pos:", global_position.round())
	# optional debug shape in editor only
	if Engine.is_editor_hint():
		var shape = CollisionShape2D.new()
		var circ = CircleShape2D.new()
		circ.radius = 8
		shape.shape = circ
		add_child(shape)
