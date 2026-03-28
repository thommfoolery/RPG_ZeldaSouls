# autoload/TransitionManager.gd
extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
@onready var loading_label: Label = $LoadingLabel if has_node("LoadingLabel") else null

var is_fading: bool = false

func _ready() -> void:
	if fade_rect == null:
		push_error("[TransitionManager] CRITICAL: FadeRect MISSING! Check scene tree.")
		return
	
	# Start fully black (safe default for autoload)
	fade_rect.modulate.a = 1.0
	fade_rect.visible = true
	
	if loading_label:
		loading_label.visible = false
	
	print("[TransitionManager] _ready() — autoload ready, screen forced black initially")
	print("  └─ FadeRect visible: ", fade_rect.visible, " | a: ", fade_rect.modulate.a)
	print("  └─ LoadingLabel present: ", loading_label != null)
	# Gentle initial fade-in for game start (covers any engine flash)
	await get_tree().create_timer(0.75).timeout  # tiny delay for stability
	fade_from_black(0.6)  # 0.6s fade — feels natural for startup
	print("[TransitionManager] Initial fade_from_black triggered in _ready()")

# ─── Core Fade Methods ────────────────────────────────────────────────
# Return the Tween so caller can await .finished

func fade_to_black(duration: float = 0.03) -> Tween:
	loading_label.visible = true	
	if fade_rect == null or is_fading:
		return null
	is_fading = true
	fade_rect.visible = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 2.5, duration)
	tween.finished.connect(func():
		is_fading = false
	)
	return tween

func fade_from_black(duration: float = 0.004) -> Tween:
	loading_label.visible = false
	if fade_rect == null or is_fading:
		return null
	is_fading = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	tween.finished.connect(func():
		fade_rect.visible = false
		is_fading = false
		print("[TransitionManager] fade_from_black FINISHED internally")
	)
	print("[TransitionManager] fade_from_black STARTED (%.2fs)" % duration)
	return tween

# ─── Helpers ──────────────────────────────────────────────────────────

func force_black() -> void:
	if fade_rect == null: return
	fade_rect.modulate.a = 1.0
	fade_rect.visible = true
	print("[TransitionManager] force_black() — screen forced black")

# blackout_then(callback: Callable, to_duration: float = 0.25, from_duration: float = 0.35)
func blackout_then(callback: Callable, to_duration: float = 0.03, from_duration: float = 0.5) -> void:
	force_black()
	var to_tween = fade_to_black(to_duration)
	if to_tween:
		await to_tween.finished
	callback.call()
	await get_tree().create_timer(0.05).timeout
	var from_tween = fade_from_black(from_duration)
	if from_tween:
		await from_tween.finished

# Optional: full scene change helper
func change_scene(path: String, tip: String = "Loading...") -> void:
	if loading_label:
		loading_label.text = tip
		loading_label.visible = true
	await blackout_then(func():
		get_tree().change_scene_to_file(path)
	, 0.03, 0.05)
	if loading_label:
		loading_label.visible = false
