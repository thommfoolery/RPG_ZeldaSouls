# ui/hud/BuffHUD.gd
extends Control

@onready var container: HBoxContainer = $HBoxContainer

func _ready() -> void:
	StatusEffectManager.effect_applied.connect(_on_effect_applied)
	StatusEffectManager.effect_removed.connect(_on_effect_removed)
	
	# Listen for equipment changes
	if EquipmentManager:
		EquipmentManager.equipped_changed.connect(_on_equipment_changed)


func _on_effect_applied(effect: StatusEffect, active: StatusEffectManager.ActiveEffect) -> void:
	if not effect.is_positive:
		return
	
	_create_or_update_icon(effect)


func _on_effect_removed(effect_id: String) -> void:
	var icon = container.get_node_or_null("Icon_" + effect_id)
	if icon:
		icon.queue_free()


func _create_or_update_icon(effect: StatusEffect) -> void:
	var icon = container.get_node_or_null("Icon_" + effect.id)
	if not icon:
		icon = TextureRect.new()
		icon.name = "Icon_" + effect.id
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(icon)
	
	icon.texture = effect.icon
	icon.modulate = effect.color if effect.color != Color.WHITE else Color(1, 1, 1, 1)
	icon.tooltip_text = effect.display_name


# ─── EQUIPMENT BUFF HANDLING ───
func _on_equipment_changed(slot_index: int, new_item: GameItem) -> void:
	# For now we only care about rings. Expand later for armor/weapons if needed.
	if new_item and new_item.category == "Rings":
		# The actual buff application happens in EquipmentManager / ring scripts
		pass
