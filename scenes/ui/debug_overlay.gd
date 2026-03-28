# scripts/ui/debug_overlay.gd
extends Control

@onready var phase_label: Label = $PhaseLabel
@onready var fps_label: Label = $FPSLabel

var fps_update_timer: float = 0.0

func _ready() -> void:
	visible = false  # Start hidden
	
	if WorldTimeManager:
		WorldTimeManager.time_updated.connect(_on_time_updated)
		_on_time_updated(WorldTimeManager.get_current_phase_name(), WorldTimeManager.get_phase_progress())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):   # Press F12 to toggle
		visible = !visible


func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= 0.5:  # Update FPS every 0.5 seconds
		fps_update_timer = 0.0
		var fps = Engine.get_frames_per_second()
		
		fps_label.text = "FPS: %d" % fps
		
		if fps >= 55:
			fps_label.modulate = Color(0.3, 1.0, 0.4)   # Green
		elif fps >= 40:
			fps_label.modulate = Color(1.0, 0.9, 0.2)   # Yellow
		else:
			fps_label.modulate = Color(1.0, 0.3, 0.3)   # Red


func _on_time_updated(phase_name: String, progress: float) -> void:
	if phase_label:
		phase_label.text = "Phase: %s (%.0f%%)" % [phase_name.capitalize(), progress * 100]
