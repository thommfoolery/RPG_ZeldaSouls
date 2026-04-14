# scripts/components/DynamicStatBar.gd
extends Node
class_name DynamicStatBar

@export var progress_bar: ProgressBar
@export var min_width: float = 280.0
@export var max_width: float = 620.0
@export var base_max_value: float = 122.0
@export var max_expected_value: float = 800.0   # ← NEW: the real cap for THIS bar
@export var growth_aggression: float = 1.0      # 1.0 = linear, >1 = more dramatic early growth

func _ready() -> void:
	if not progress_bar:
		push_error("[DynamicStatBar] No ProgressBar assigned!")
		return
	
	progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	progress_bar.size.x = min_width
	progress_bar.custom_minimum_size.x = min_width
	
	print("[DynamicStatBar] Initialized — min ", min_width, " max ", max_width,
		  " base ", base_max_value, " expected_max ", max_expected_value)


func update_bar(new_max_value: float) -> void:
	if not progress_bar:
		return
	
	# Normalize against the bar's ACTUAL range (fixes the huge first-jump)
	var range_total = max_expected_value - base_max_value
	var t = clamp((new_max_value - base_max_value) / range_total, 0.0, 1.0)
	
	# Optional aggression curve (Stamina can use 1.0 for perfectly even steps)
	if growth_aggression != 1.0:
		t = pow(t, 1.0 / growth_aggression)
	
	var new_width = lerp(min_width, max_width, t)
	
	progress_bar.size.x = new_width
	progress_bar.custom_minimum_size.x = new_width
	
