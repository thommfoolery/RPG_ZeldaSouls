# scripts/components/LampComponent.gd
extends Node
class_name LampComponent

@export var light_intensity: float = 0.4
@export var light_color: Color = Color(1.0, 0.95, 0.7)
@export var light_range_scale: float = 5.0

# NEW: Will be set when the lamp is equipped
var current_item: GameItem = null

func _ready() -> void:
	pass # Do nothing here

func _on_equipped() -> void:
	# Find which hand currently holds a lamp and store the GameItem
	var right_item = EquipmentManager.get_equipped_item(0)
	var left_item  = EquipmentManager.get_equipped_item(7)
	
	if right_item and right_item.is_lamp:
		current_item = right_item
	elif left_item and left_item.is_lamp:
		current_item = left_item
	else:
		current_item = null
		disable_lamp()
		return
	
	enable_lamp()

func _on_unequipped() -> void:
	disable_lamp()

func enable_lamp() -> void:
	if not current_item: return
	
	var light = _find_lamp_light()
	if not light:
		push_error("[LampComponent] CRITICAL: LampLight not found!")
		return

	# Use values from the GameItem (data-driven)
	light.enabled = true
	light.visible = true
	light.energy = current_item.lamp_energy
	light.color = current_item.lamp_color
	light.texture_scale = current_item.lamp_range_scale
	light.queue_redraw()

	print("[Lamp] Equipped ", current_item.display_name, " → energy=", current_item.lamp_energy, " range=", current_item.lamp_range_scale)

func disable_lamp() -> void:
	var light = _find_lamp_light()
	if light:
		light.enabled = false
		light.queue_redraw()
		print("[Lamp] Lantern unequipped → light OFF")

# ─── SAFER FINDER ───
func _find_lamp_light() -> PointLight2D:
	var player = get_parent()
	if not player:
		return null
	
	# Try unique name first (best)
	var light = player.get_node_or_null("%LampLight") as PointLight2D
	if light:
		return light
	
	# Fallback
	light = player.get_node_or_null("LampLight") as PointLight2D
	if light:
		return light
	
	return null
