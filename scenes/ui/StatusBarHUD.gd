# ui/hud/StatusBarsHUD.gd
extends Control

@onready var container: VBoxContainer = $VBoxContainer

func _ready() -> void:
	StatusEffectManager.effect_applied.connect(_on_effect_applied)
	StatusEffectManager.effect_removed.connect(_on_effect_removed)
	set_process(true)


func _process(_delta: float) -> void:
	for child in container.get_children():
		var effect_id = child.name.trim_prefix("Bar_")
		var active = _get_active_effect(effect_id)
		if active:
			_update_bar_visual(child, active)


func _on_effect_applied(effect: StatusEffect, active: StatusEffectManager.ActiveEffect) -> void:
	if effect.is_positive: 
		return
	_create_or_update_bar(effect, active)


func _on_effect_removed(effect_id: String) -> void:
	var bar = container.get_node_or_null("Bar_" + effect_id)
	if bar:
		bar.queue_free()


func _create_or_update_bar(effect: StatusEffect, active: StatusEffectManager.ActiveEffect) -> void:
	var bar = container.get_node_or_null("Bar_" + effect.id)
	if not bar:
		bar = Panel.new()
		bar.name = "Bar_" + effect.id
		bar.custom_minimum_size = Vector2(255, 24)
		container.add_child(bar)

		var hbox = HBoxContainer.new()
		hbox.name = "HBox"
		hbox.add_theme_constant_override("separation", 5)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER   # vertical centering
		bar.add_child(hbox)

		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = effect.icon
		icon.custom_minimum_size = Vector2(20, 20)
		hbox.add_child(icon)

		var progress = ProgressBar.new()
		progress.name = "Progress"
		progress.custom_minimum_size = Vector2(220, 24)
		progress.max_value = 100.0
		
		# Force fully opaque + remove percentage text
		progress.show_percentage = false
		
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		style_bg.set_border_width_all(1)
		style_bg.border_color = Color(0.3, 0.3, 0.3, 1.0)

		var style_fg = StyleBoxFlat.new()
		style_fg.bg_color = Color(1, 1, 1, 1.0)

		progress.add_theme_stylebox_override("background", style_bg)
		progress.add_theme_stylebox_override("fill", style_fg)

		hbox.add_child(progress)

	# Update visual + color
	_update_bar_visual(bar, active)


func _update_bar_visual(bar: Node, active: StatusEffectManager.ActiveEffect) -> void:
	var progress_bar = null
	var hbox = bar.get_node_or_null("HBox")
	if hbox:
		progress_bar = hbox.get_node_or_null("Progress")
	if not progress_bar:
		progress_bar = bar.get_node_or_null("Progress")
	if not progress_bar:
		return

	var effect = active.effect
	var percent: float = 0.0

	if active.is_poisoned:
		percent = (active.remaining_time / effect.max_duration) * 100.0
	else:
		percent = (active.build_up / effect.build_up_required) * 100.0

	percent = clamp(percent, 0.0, 100.0)

	bar.visible = percent > 1.0
	progress_bar.value = percent

	# Apply color from StatusEffect.tres
	if effect.color != Color.WHITE:
		progress_bar.modulate = effect.color
	else:
		progress_bar.modulate = Color(1, 1, 1, 1)


func _get_active_effect(effect_id: String) -> StatusEffectManager.ActiveEffect:
	for ae in StatusEffectManager.active_effects:
		if ae.effect.id == effect_id:
			return ae
	return null
