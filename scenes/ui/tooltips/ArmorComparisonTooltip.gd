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

func show_weapon_comparison(current: GameItem, hovered: GameItem) -> void:
	if not hovered or not hovered.weapon_stats:
		hide_comparison()
		return
	
	title_label.text = "Weapon Comparison"
	
	# Clear old entries
	for child in stats_container.get_children():
		child.queue_free()
	
	var ws = hovered.weapon_stats
	var current_ws = current.weapon_stats if current and current.weapon_stats else null
	
	# === GROUP 1: Attack Rating ===
	# === GROUP 1: Attack Rating — now using real calculated value ===
	var ar_current = StatCalculator.get_attack_rating(current) if current else 0.0
	var ar_hovered = StatCalculator.get_attack_rating(hovered)
	
	var ar_hbox = HBoxContainer.new()
	ar_hbox.add_theme_constant_override("separation", 20)
	
	var ar_name = Label.new()
	ar_name.text = "Attack Rating"
	ar_name.custom_minimum_size.x = 160
	ar_hbox.add_child(ar_name)
	
	var ar_curr_label = Label.new()
	ar_curr_label.text = str(ar_current)
	ar_curr_label.modulate = Color(0.7, 0.7, 0.7)
	ar_hbox.add_child(ar_curr_label)
	
	var arrow = Label.new()
	arrow.text = "→"
	arrow.modulate = Color(0.6, 0.6, 0.6)
	ar_hbox.add_child(arrow)
	
	var ar_new_label = Label.new()
	ar_new_label.text = str(ar_hovered)
	if ar_hovered > ar_current:
		ar_new_label.modulate = Color(0.3, 1.0, 0.3)
	elif ar_hovered < ar_current:
		ar_new_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		ar_new_label.modulate = Color(1.0, 1.0, 1.0)
	ar_hbox.add_child(ar_new_label)
	
	stats_container.add_child(ar_hbox)
	
	# === GROUP 2: Damage Types ===
	var damage_types = ["physical", "magic", "fire", "lightning", "holy"]
	for dtype in damage_types:
		var base_val = 0.0
		match dtype:
			"physical": base_val = ws.base_physical
			"magic":    base_val = ws.base_magic
			"fire":     base_val = ws.base_fire
			"lightning":base_val = ws.base_lightning
			"holy":     base_val = ws.base_holy
		
		var curr_val = 0.0
		if current_ws:
			match dtype:
				"physical": curr_val = current_ws.base_physical
				"magic":    curr_val = current_ws.base_magic
				"fire":     curr_val = current_ws.base_fire
				"lightning":curr_val = current_ws.base_lightning
				"holy":     curr_val = current_ws.base_holy
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var name_label = Label.new()
		name_label.text = dtype.capitalize() + " Damage"
		name_label.custom_minimum_size.x = 160
		hbox.add_child(name_label)
		
		var curr_label = Label.new()
		curr_label.text = str(curr_val)
		curr_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(curr_label)
		
		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(arrow_label)
		
		var new_label = Label.new()
		new_label.text = str(base_val)
		if base_val > curr_val:
			new_label.modulate = Color(0.3, 1.0, 0.3)
		elif base_val < curr_val:
			new_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			new_label.modulate = Color(1.0, 1.0, 1.0)
		hbox.add_child(new_label)
		
		stats_container.add_child(hbox)
	
	# Gap between groups
	var gap2 = Control.new()
	gap2.custom_minimum_size = Vector2(0, 12)
	stats_container.add_child(gap2)
	
	# === GROUP 3: Scaling ===
	var scaling_stats = [
		["STR", ws.str_scaling, current_ws.str_scaling if current_ws else WeaponStats.ScalingGrade.NONE],
		["DEX", ws.dex_scaling, current_ws.dex_scaling if current_ws else WeaponStats.ScalingGrade.NONE],
		["INT", ws.int_scaling, current_ws.int_scaling if current_ws else WeaponStats.ScalingGrade.NONE],
		["FTH", ws.faith_scaling, current_ws.faith_scaling if current_ws else WeaponStats.ScalingGrade.NONE]
	]
	
	for entry in scaling_stats:
		var stat_name = entry[0]
		var new_grade = entry[1]
		var curr_grade = entry[2]
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var name_label = Label.new()
		name_label.text = stat_name + " Scaling"
		name_label.custom_minimum_size.x = 160
		hbox.add_child(name_label)
		
		var curr_label = Label.new()
		curr_label.text = ws.get_scaling_display(curr_grade)
		curr_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(curr_label)
		
		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(arrow_label)
		
		var new_label = Label.new()
		new_label.text = ws.get_scaling_display(new_grade)
		
		if new_grade > curr_grade and new_grade != WeaponStats.ScalingGrade.NONE:
			new_label.modulate = Color(0.3, 1.0, 0.3)
		elif new_grade < curr_grade and curr_grade != WeaponStats.ScalingGrade.NONE:
			new_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			new_label.modulate = Color(1.0, 1.0, 1.0)
		
		hbox.add_child(new_label)
		stats_container.add_child(hbox)
	
	# Gap between groups
	var gap3 = Control.new()
	gap3.custom_minimum_size = Vector2(0, 12)
	stats_container.add_child(gap3)
	
	# === GROUP 4: Spell Scaling Power & Weight ===
	var extra_stats = [
		["Spell Scaling Power", ws.spell_scaling_power, current_ws.spell_scaling_power if current_ws else 0.0],
		["Weight", ws.weight, current_ws.weight if current_ws else 0.0]
	]
	
	for entry in extra_stats:
		var name_str = entry[0]
		var new_val = entry[1]
		var curr_val = entry[2]
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var name_label = Label.new()
		name_label.text = name_str
		name_label.custom_minimum_size.x = 160
		hbox.add_child(name_label)
		
		var curr_label = Label.new()
		curr_label.text = str(curr_val)
		curr_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(curr_label)
		
		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(arrow_label)
		
		var new_label = Label.new()
		new_label.text = str(new_val)
		
		# Special reverse coloring for Weight
		if name_str == "Weight":
			if new_val < curr_val:
				new_label.modulate = Color(0.3, 1.0, 0.3)  # green = lighter = better
			elif new_val > curr_val:
				new_label.modulate = Color(1.0, 0.3, 0.3)  # red = heavier = worse
			else:
				new_label.modulate = Color(1.0, 1.0, 1.0)
		else:
			# Normal coloring for Spell Scaling Power
			if new_val > curr_val:
				new_label.modulate = Color(0.3, 1.0, 0.3)
			elif new_val < curr_val:
				new_label.modulate = Color(1.0, 0.3, 0.3)
			else:
				new_label.modulate = Color(1.0, 1.0, 1.0)
		
		hbox.add_child(new_label)
		stats_container.add_child(hbox)
	
	# Gap between groups
	var gap4 = Control.new()
	gap4.custom_minimum_size = Vector2(0, 12)
	stats_container.add_child(gap4)
	
	# === GROUP 5: Stat Requirements — each on its own line ===
	var reqs = [
		["Strength", ws.required_strength, current_ws.required_strength if current_ws else 0],
		["Dexterity", ws.required_dexterity, current_ws.required_dexterity if current_ws else 0],
		["Intelligence", ws.required_intelligence, current_ws.required_intelligence if current_ws else 0],
		["Faith", ws.required_faith, current_ws.required_faith if current_ws else 0]
	]
	
	for entry in reqs:
		var stat_name = entry[0]
		var new_req = entry[1]
		var curr_req = entry[2]
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		
		var name_label = Label.new()
		name_label.text = stat_name + " Req"
		name_label.custom_minimum_size.x = 160
		hbox.add_child(name_label)
		
		var curr_label = Label.new()
		curr_label.text = str(curr_req)
		curr_label.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(curr_label)
		
		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(arrow_label)
		
		var new_label = Label.new()
		new_label.text = str(new_req)
		new_label.modulate = Color(1.0, 1.0, 1.0)  # no color for now
		hbox.add_child(new_label)
		
		stats_container.add_child(hbox)
	
	visible = true
