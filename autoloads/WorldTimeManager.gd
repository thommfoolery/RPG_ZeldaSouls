# autoload/WorldTimeManager.gd
extends Node
# Signal sent every frame so UI and lighting can react
signal time_updated(phase_name: String, progress: float)
@export var day_length_seconds: float = 300.0 # Total length of one full day/night cycle (5 minutes)
# ─── Phase Thresholds (named constants - easy to tweak) ───
const DAWN_END : float = 0.18
const DAY_END : float = 0.55
const DUSK_END : float = 0.72
const NIGHT_END : float = 0.88
# The five phases of the day
enum Phase { DAWN, DAY, DUSK, NIGHT, LATE_NIGHT }
var current_phase: Phase = Phase.DAWN
var time_in_day: float = 0.0
var phase_progress: float = 0.0
# Screen tint colors for each phase (creates mood lighting)
var phase_colors = {
Phase.DAWN: Color(0.85, 0.75, 0.95),
Phase.DAY: Color(1.0, 1.0, 0.98),
Phase.DUSK: Color(1.0, 0.651, 0.451, 0.98),
Phase.NIGHT: Color(0.238, 0.352, 0.909, 1.0),
Phase.LATE_NIGHT: Color(0.192, 0.257, 0.815, 1.0)
}
var canvas_modulate: CanvasModulate = null
var last_phase: Phase = Phase.DAWN

# ─── INDOOR OVERRIDE (minimal & safe) ─────────────────────
@export var indoor_mode: bool = false
@export var indoor_base_color: Color = Color(0.08, 0.08, 0.15, 1.0) # default dark cave

func _ready() -> void:
	# Load saved time or start slightly into the day
	if Global and "world_time" in Global:
		time_in_day = Global.world_time
	else:
		time_in_day = day_length_seconds * 0.1
	# Create CanvasModulate to tint the entire screen
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "CanvasModulate"
	get_tree().root.add_child.call_deferred(canvas_modulate)
	call_deferred("_update_lighting")

func _process(delta: float) -> void:
	# Time ALWAYS runs - even when inside the cave (this fixes the outside lighting issue)
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

# ─── PUBLIC API FOR IndoorZone.gd ─────────────────────────────
func set_indoor_mode(enabled: bool, base_color: Color = Color(0.08, 0.08, 0.15, 1.0)) -> void:
	if indoor_mode == enabled and indoor_base_color == base_color:
		return
	print("[WorldTimeManager] set_indoor_mode → ", enabled, " | color=", base_color)
	indoor_mode = enabled
	indoor_base_color = base_color
	_refresh_active_lighting(true) # immediate for responsive cave feel

# ─── CORE LIGHTING REFRESH ───────────────────────────────────
func _refresh_active_lighting(immediate: bool = false) -> void:
	if not canvas_modulate:
		return
	var target = indoor_base_color if indoor_mode else phase_colors[current_phase]
	if immediate:
		canvas_modulate.color = target
	else:
		var tween = create_tween()
		tween.tween_property(canvas_modulate, "color", target, 1.2)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	print("[WorldTimeManager-DEBUG] Lighting refreshed → ", target)

# ─── RESTORED: Original long cinematic outdoor transitions ─────
func _apply_smooth_transition() -> void:
	if indoor_mode:
		return # Only block while indoors - outdoor day/night stays cinematic
	# Original long 15.5s smooth transition fully restored
	var target_color = phase_colors[current_phase]
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", target_color, 15.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func _update_lighting() -> void:
	if not canvas_modulate:
		return
	_refresh_active_lighting(true) # immediate on load / indoor switches

# Helper functions used by other scripts
func get_current_phase_name() -> String:
	return Phase.keys()[current_phase]
func get_phase_progress() -> float:
	return phase_progress
