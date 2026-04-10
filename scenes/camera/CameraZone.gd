# scenes/camera/CameraZone.gd
extends Area2D

@export var target_zoom: Vector2 = Vector2(1.5, 1.5)   # Zoom in = bigger number, Zoom out = smaller number
@export var transition_time: float = 0.6               # How smooth the transition is

func _ready() -> void:
	monitoring = true
	# Optional: make it visible only in editor
	if Engine.is_editor_hint():
		modulate.a = 0.3

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[CameraZone] ENTERED - zooming to ", target_zoom)
		CameraManager.enter_camera_zone(target_zoom, transition_time)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[CameraZone] EXITED - returning to default zoom")
		CameraManager.exit_camera_zone()

# Connect these signals in the editor:
# body_entered → _on_body_entered
# body_exited → _on_body_exitedextends Area2D
