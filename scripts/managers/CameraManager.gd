# autoload/CameraManager.gd
extends Node

var active_camera: Camera2D = null
var target: Node2D = null  # the player

signal camera_changed(new_camera: Camera2D)

func _ready() -> void:
	PlayerManager.player_changed.connect(_on_player_changed)
	print("[CameraManager] Ready — will follow player once camera is activated")

func _on_player_changed(new_player: Node) -> void:
	target = new_player
	if active_camera:
		_snap_to_target()

# ── CONTINUOUS FOLLOW (this is what was missing) ─────────────────────
func _physics_process(delta: float) -> void:
	if active_camera and target:
		smooth_follow(delta)

# ── PUBLIC METHODS ───────────────────────────────────────────────────
func set_active_camera(cam: Camera2D) -> void:
	if not cam or not cam is Camera2D:
		push_error("[CameraManager] Invalid camera passed!")
		return
	
	if active_camera:
		active_camera.current = false
	
	active_camera = cam
	active_camera.current = true
	
	if target:
		active_camera.global_position = target.global_position
	
	print("[CameraManager] SUCCESS - camera current = true at ", cam.get_path())

func activate_player_camera() -> void:
	if not target:
		push_error("[CameraManager] No player target!")
		return
	
	var cam_node = target.get_node_or_null("%Camera2D") or target.get_node_or_null("Camera2D")
	if not cam_node or not cam_node is Camera2D:
		push_error("[CameraManager] No valid Camera2D found on player!")
		return
	
	print("[CameraManager] Found camera, activating...")
	call_deferred("_really_activate_camera", cam_node as Camera2D)

func smooth_follow(delta: float) -> void:
	if not target or not active_camera:
		return
	
	# Classic Souls-like feel — camera leads the player slightly
	var target_pos = target.global_position
	active_camera.global_position = active_camera.global_position.lerp(target_pos, 0.12)

func _snap_to_target() -> void:
	if target and active_camera:
		active_camera.global_position = target.global_position

func _really_activate_camera(cam: Camera2D) -> void:
	if not cam or not is_instance_valid(cam):
		push_error("[CameraManager] Camera is invalid!")
		return
	
	if active_camera:
		active_camera.current = false
	
	active_camera = cam
	
	# THIS is the important change
	cam.make_current()                    # ← use the method, not .current = true
	
	if target:
		cam.global_position = target.global_position
	
	print("[CameraManager] CAMERA ACTIVATED with make_current() → ", cam.get_path())
