# ui/hud/BuffHUD.gd
extends Control

@onready var container: HBoxContainer = $HBoxContainer

func _ready() -> void:
	_connect_to_equipment()
	call_deferred("rebuild_icons")

func _connect_to_equipment() -> void:
	if EquipmentManager.equipped_changed.is_connected(_on_equipped_changed):
		EquipmentManager.equipped_changed.disconnect(_on_equipped_changed)
	EquipmentManager.equipped_changed.connect(_on_equipped_changed)

func _on_equipped_changed(_slot_index: int, _new_item: GameItem) -> void:
	rebuild_icons()

func rebuild_icons() -> void:
	if not is_instance_valid(container):
		return
	
	# Clear old icons safely
	for child in container.get_children():
		child.queue_free()
	
	# Add icon for every equipped item that has permanent modifiers
	for i in EquipmentManager.SLOT_COUNT:
		var item = EquipmentManager.get_equipped_item(i)
		if not item or item.permanent_modifiers.is_empty():
			continue
		
		# Support multiple modifiers per item (one icon per modifier)
		for modifier in item.permanent_modifiers:
			if not modifier or not modifier.icon:
				continue
				
			var icon = TextureRect.new()
			icon.name = "Icon_" + modifier.display_name
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			icon.texture = modifier.icon
			icon.modulate = modifier.color if modifier.color != Color.WHITE else Color(1, 1, 1, 1)
			icon.tooltip_text = modifier.display_name
			
			container.add_child(icon)

func _exit_tree() -> void:
	if EquipmentManager.equipped_changed.is_connected(_on_equipped_changed):
		EquipmentManager.equipped_changed.disconnect(_on_equipped_changed)
