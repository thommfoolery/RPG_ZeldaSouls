# autoload/WorldTimeManager.gd
extends Node

# Signal sent every frame so UI and lighting can react
signal time_updated(phase_name: String, progress: float)

@export var day_length_seconds: float = 300.0   # Total length of one full day/night cycle (5 minutes)

# ─── Phase Thresholds (named constants - easy to tweak) ───
const DAWN_END  : float = 0.18   # Dawn lasts from 0% to 18% of the day
const DAY_END   : float = 0.55   # Day lasts from 18% to 55%
const DUSK_END  : float = 0.72   # Dusk lasts from 55% to 72%
const NIGHT_END : float = 0.88   # Night lasts from 72% to 88%
# Everything after 88% is Late Night until the day loops

# The five phases of the day
enum Phase { DAWN, DAY, DUSK, NIGHT, LATE_NIGHT }

var current_phase: Phase = Phase.DAWN
var time_in_day: float = 0.0           # Seconds passed in the current day
var phase_progress: float = 0.0        # 0.0 to 1.0 — how far we are in the current phase

# Screen tint colors for each phase (creates mood lighting)
var phase_colors = {
	Phase.DAWN:     Color(0.85, 0.75, 0.95),
	Phase.DAY:      Color(1.0, 1.0, 0.98),
	Phase.DUSK:     Color(1.0, 0.65, 0.45),
	Phase.NIGHT:    Color(0.06, 0.10, 0.40),
	Phase.LATE_NIGHT: Color(0.03, 0.05, 0.25)
}

var canvas_modulate: CanvasModulate = null
var last_phase: Phase = Phase.DAWN

func _ready() -> void:
	# Load saved time or start slightly into the day
	if Global and "world_time" in Global:
		time_in_day = Global.world_time
	else:
		time_in_day = day_length_seconds * 0.1   # Start at 10% of the day

	# Create CanvasModulate to tint the entire screen
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "CanvasModulate"
	get_tree().root.add_child.call_deferred(canvas_modulate)

	call_deferred("_update_lighting")


func _process(delta: float) -> void:
	# Advance time
	time_in_day += delta
	
	# Loop back to start of day when we reach the end
	if time_in_day >= day_length_seconds:
		time_in_day = 0.0
	
	# Save current time for persistence across scenes
	if Global:
		Global.world_time = time_in_day
	
	# Calculate normalized progress (0.0 to 1.0)
	var normalized = time_in_day / day_length_seconds
	_update_phase(normalized)


func _update_phase(normalized: float) -> void:
	# Determine current phase using clear thresholds
	if normalized < DAWN_END:
		current_phase = Phase.DAWN
	elif normalized < DAY_END:
		current_phase = Phase.DAY
	elif normalized < DUSK_END:
		current_phase = Phase.DUSK
	elif normalized < NIGHT_END:
		current_phase = Phase.NIGHT
	else:
		current_phase = Phase.LATE_NIGHT
	
	phase_progress = normalized
	
	# If we just entered a new phase, smoothly transition the lighting
	if current_phase != last_phase:
		last_phase = current_phase
		_apply_smooth_transition()
	
	# Notify listeners (UI, lighting, etc.)
	time_updated.emit(Phase.keys()[current_phase], phase_progress)


func _apply_smooth_transition() -> void:
	if not canvas_modulate:
		return
	
	var target_color = phase_colors[current_phase]
	
	# Long, cinematic transition between phases
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", target_color, 15.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _update_lighting() -> void:
	if canvas_modulate:
		canvas_modulate.color = phase_colors[current_phase]


# Helper functions used by other scripts
func get_current_phase_name() -> String:
	return Phase.keys()[current_phase]

func get_phase_progress() -> float:
	return phase_progress
