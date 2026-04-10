# autoload/CameraManager.gd
extends Node

var active_camera: Camera2D = null
var target: Node2D = null
var current_config: CameraConfig = null
var tween: Tween

func _ready() -> void:
	PlayerManager.player_changed.connect(_on_player_changed)
	tween = create_tween()
	tween.stop()
	print("[CameraManager] Ready")

func _on_player_changed(new_player: Node) -> void:
	target = new_player

# ── Activation ───────────────────────────────────────────────────────────
func activate_player_camera() -> void:
	if not target:
		push_error("[CameraManager] No player target!")
		return
	
	var cam = target.get_node_or_null("Camera2D")
	if not cam or not cam is Camera2D:
		push_error("[CameraManager] No Camera2D found on player!")
		return
	
	call_deferred("set_active_camera", cam)

func set_active_camera(cam: Camera2D) -> void:
	if not cam or not cam is Camera2D:
		push_error("[CameraManager] Invalid camera passed!")
		return
	
	# Safely deactivate previous camera without touching .current directly
	if active_camera and is_instance_valid(active_camera) and active_camera != cam:
		active_camera.clear_current()
	
	# Activate the new camera
	active_camera = cam
	cam.make_current()
	
	print("[CameraManager] Camera activated: ", cam.get_path())
	
	_load_scene_config()

# ── Per-Scene Config ─────────────────────────────────────────────────────
func _load_scene_config() -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		print("[CameraManager] ERROR: No current_scene")
		return
	
	# Look for the attached CameraConfig property on the root node
	if scene_root.has_meta("camera_config") or "camera_config" in scene_root:
		var config = scene_root.get("camera_config")
		if config and config is CameraConfig:
			current_config = config
			_apply_config(current_config)
			print("[CameraManager] Loaded attached CameraConfig from scene root")
			return
	
	# Fallback
	var fallback = CameraConfig.new()
	current_config = fallback
	_apply_config(fallback)
	print("[CameraManager] No attached CameraConfig found - using fallback")

func _apply_config(config: CameraConfig) -> void:
	if not active_camera or not config:
		return
	
	active_camera.zoom = config.default_zoom
	
	active_camera.limit_left = config.limit_left
	active_camera.limit_right = config.limit_right
	active_camera.limit_top = config.limit_top
	active_camera.limit_bottom = config.limit_bottom
	active_camera.limit_smoothed = true
	
	print("[CameraManager] Applied config → Zoom: ", config.default_zoom, 
		  " | Limits L:", config.limit_left, " R:", config.limit_right)

# ── Smooth Zoom (for later) ──────────────────────────────────────────────
func smooth_zoom_to(new_zoom: Vector2, duration: float = 0.8) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.tween_property(active_camera, "zoom", new_zoom, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# Add these at the bottom of CameraManager.gd

func enter_camera_zone(new_zoom: Vector2, duration: float = 0.6) -> void:
	if not active_camera: return
	smooth_zoom_to(new_zoom, duration)
	print("[CameraManager] ENTER zone → target zoom ", new_zoom)

func exit_camera_zone() -> void:
	if not active_camera or not current_config: return
	smooth_zoom_to(current_config.default_zoom, 0.9)
	print("[CameraManager] EXIT zone → returning to default zoom ", current_config.default_zoom)
