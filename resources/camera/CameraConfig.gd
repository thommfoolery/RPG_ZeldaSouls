# resources/camera/CameraConfig.gd
class_name CameraConfig
extends Resource

@export var default_zoom: Vector2 = Vector2(1.0, 1.0)

@export_group("Camera Limits")
@export var limit_left: float = -10000
@export var limit_right: float = 10000
@export var limit_top: float = -10000
@export var limit_bottom: float = 10000

@export_group("Zoom Zones (optional)")
@export var use_dynamic_zoom: bool = false
