extends Panel

@onready var stats_container: VBoxContainer = $MainVBox/StatsScroll/StatsContainer
@onready var title_label: Label = $MainVBox/TitleLabel

var current_item: GameItem = null
var hovered_item: GameItem = null

func show_comparison(current: GameItem, hovered: GameItem) -> void:
	current_item = current
	hovered_item = hovered
	title_label.text = "Armor Comparison"
	_rebuild_stats_list()
	visible = true

func hide_comparison() -> void:
	visible = false

func _rebuild_stats_list() -> void:
	for child in stats_container.get_children():
		child.queue_free()
	
	var stats_to_compare = [
		"physical_defense", "magic_defense", "fire_defense",
		"lightning_defense", "holy_defense", "status_resistance", "poise"
	]
	
	for stat_key in stats_to_compare:
		var current_val = _get_stat_value(current_item, stat_key)
		var hovered_val = _get_stat_value(hovered_item, stat_key)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		# Stat name
		var name_label = Label.new()
		name_label.text = _get_stat_display_name(stat_key)
		name_label.custom_minimum_size.x = 160
		hbox.add_child(name_label)
		
		# Current value
		var curr_label = Label.new()
		curr_label.text = "%.1f" % current_val
		curr_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(curr_label)
		
		# Arrow
		var arrow = Label.new()
		arrow.text = "→"
		arrow.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(arrow)
		
		# Hovered value with color
		var new_label = Label.new()
		new_label.text = "%.1f" % hovered_val
		if hovered_val > current_val:
			new_label.modulate = Color(0.3, 1.0, 0.3)  # green
		elif hovered_val < current_val:
			new_label.modulate = Color(1.0, 0.3, 0.3)  # red
		else:
			new_label.modulate = Color(1.0, 1.0, 1.0)  # white
		hbox.add_child(new_label)
		
		stats_container.add_child(hbox)

func _get_stat_value(item: GameItem, stat_key: String) -> float:
	if not item or not item.armor_stats:
		return 0.0
	match stat_key:
		"physical_defense": return item.armor_stats.physical_defense
		"magic_defense": return item.armor_stats.magic_defense
		"fire_defense": return item.armor_stats.fire_defense
		"lightning_defense": return item.armor_stats.lightning_defense
		"holy_defense": return item.armor_stats.holy_defense
		"status_resistance": return item.armor_stats.status_resistance
		"poise": return item.armor_stats.poise
	return 0.0

func _get_stat_display_name(stat_key: String) -> String:
	match stat_key:
		"physical_defense": return "Physical Defense"
		"magic_defense": return "Magic Defense"
		"fire_defense": return "Fire Defense"
		"lightning_defense": return "Lightning Defense"
		"holy_defense": return "Holy Defense"
		"status_resistance": return "Status Resistance"
		"poise": return "Poise"
	return stat_key.capitalize()
