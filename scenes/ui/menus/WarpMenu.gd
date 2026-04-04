#WarpMenu.gd
extends Control

# Signals used by BonfireMenu
signal warp_selected(bonfire_id: String)
signal menu_closed

# UI Nodes
@onready var tab_bar: HBoxContainer = %TabBar
@onready var bonfire_list: VBoxContainer = %BonfireList
@onready var preview_texture_rect: TextureRect = %PreviewTexture

# Runtime data
var area_buttons: Array[Button] = []
var bonfire_buttons: Array[Button] = []
var current_sorted_bonfires: Array[BonfireEntry] = []

var current_area_index: int = 0
var selected_bonfire_index: int = 0

var current_bonfire_id: String = ""

func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_tabs()

func set_current_bonfire(bonfire_id: String) -> void:
	current_bonfire_id = bonfire_id
	if area_buttons.size() > 0:
		_select_area_of_current_bonfire()
		build_current_tab_list()

func _select_area_of_current_bonfire() -> void:
	if current_bonfire_id.is_empty():
		return
	var current_entry = BonfireManager.get_entry(current_bonfire_id)
	if not current_entry:
		return
	for i in area_buttons.size():
		if area_buttons[i].text == current_entry.area_name:
			current_area_index = i
			_highlight_tab()
			return

func build_tabs() -> void:
	# Clear everything
	for child in tab_bar.get_children():
		child.queue_free()
	for child in bonfire_list.get_children():
		child.queue_free()
	
	area_buttons.clear()
	bonfire_buttons.clear()
	current_sorted_bonfires.clear()

	var discovered = PlayerStats.discovered_bonfires

	print("=== WARP MENU BUILD TABS START ===")
	print("Discovered bonfires count: ", discovered.size())

	# 1. Collect UNIQUE area names
	var unique_areas: Array[String] = []
	for bonfire_id in discovered:
		var entry = BonfireManager.get_entry(bonfire_id)
		if not entry: continue
		var area_name = entry.area_name.strip_edges()
		if area_name.is_empty(): area_name = "Unknown Area"
		if not unique_areas.has(area_name):
			unique_areas.append(area_name)

	print("Unique areas (in collection order): ", unique_areas)

	# 2. Build AreaEntry list + debug registry lookup
	var area_entries: Array[AreaEntry] = []
	for area_name in unique_areas:
		var area_entry = null
		if AreaReg and AreaReg.registry:
			area_entry = AreaReg.registry.get_area(area_name)

		print("→ Area: '", area_name, "' | Registry hit: ", area_entry != null)

		if area_entry:
			print("   Real AreaEntry → sort_order=", area_entry.sort_order, 
				  " | area_id='", area_entry.area_id, 
				  "' | title='", area_entry.title, "'")
			area_entries.append(area_entry)
		else:
			var dummy = AreaEntry.new()
			dummy.area_id = area_name
			dummy.title = area_name
			dummy.sort_order = 999
			print("   Using DUMMY → sort_order=999")
			area_entries.append(dummy)

	# 3. Sort and show before/after
	print("Before sorting - order:", area_entries.map(func(e): return e.title + "(" + str(e.sort_order) + ")"))

	area_entries.sort_custom(func(a: AreaEntry, b: AreaEntry) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.area_id < b.area_id
	)

	print("AFTER sorting  - order:", area_entries.map(func(e): return e.title + "(" + str(e.sort_order) + ")"))

	# 4. Create buttons
	print("Creating tabs in final order:")
	for area_entry in area_entries:
		var btn = Button.new()
		btn.text = area_entry.title if not area_entry.title.is_empty() else area_entry.area_id
		btn.custom_minimum_size = Vector2(180, 60)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_tab_pressed.bind(area_entry.area_id))
		tab_bar.add_child(btn)
		area_buttons.append(btn)

		print("   Tab created: '", btn.text, "' (sort_order was ", area_entry.sort_order, ")")

	if area_buttons.size() > 0:
		_highlight_tab()
		build_current_tab_list()

	print("=== WARP MENU BUILD TABS END ===\n")

# Rest of your functions remain unchanged...
func build_current_tab_list() -> void:
	for child in bonfire_list.get_children():
		child.queue_free()
	bonfire_buttons.clear()
	current_sorted_bonfires.clear()

	if current_area_index >= area_buttons.size():
		return

	var current_area = area_buttons[current_area_index].text

	var bonfires_in_area: Array[BonfireEntry] = []
	for bonfire_id in PlayerStats.discovered_bonfires.keys():
		var entry = BonfireManager.get_entry(bonfire_id)
		if entry and entry.area_name == current_area:
			bonfires_in_area.append(entry)

	bonfires_in_area.sort_custom(func(a: BonfireEntry, b: BonfireEntry) -> bool:
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.bonfire_id < b.bonfire_id
	)

	current_sorted_bonfires = bonfires_in_area.duplicate()

	for entry in bonfires_in_area:
		var btn = Button.new()
		btn.text = " " + entry.title
		if entry.bonfire_id == current_bonfire_id:
			btn.text += " (Current)"
			btn.modulate = Color(0.85, 0.7, 0.25)
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 24)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_bonfire_selected.bind(entry.bonfire_id))
		bonfire_list.add_child(btn)
		bonfire_buttons.append(btn)

	if bonfire_buttons.size() > 0:
		selected_bonfire_index = 0
		for i in bonfire_buttons.size():
			if bonfire_buttons[i].text.ends_with("(Current)"):
				selected_bonfire_index = i
				break
		_highlight_selected()
		_update_preview_for_current_bonfire()

func _highlight_tab() -> void:
	for i in area_buttons.size():
		area_buttons[i].modulate = Color(1.0, 0.9, 0.4) if i == current_area_index else Color.WHITE

func _highlight_selected() -> void:
	for i in bonfire_buttons.size():
		var btn = bonfire_buttons[i]
		if btn.text.ends_with("(Current)"):
			btn.modulate = Color(1.0, 0.95, 0.6) if i == selected_bonfire_index else Color(0.85, 0.7, 0.25)
		else:
			btn.modulate = Color(1.0, 0.9, 0.4) if i == selected_bonfire_index else Color.WHITE

func _on_tab_pressed(area_name: String) -> void:
	for i in area_buttons.size():
		if area_buttons[i].text == area_name:
			current_area_index = i
			_highlight_tab()
			build_current_tab_list()
			break

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_closed.emit()
		return

	if event.is_action_pressed("ui_left") or event.is_action_pressed("cycle_left_hand"):
		current_area_index = wrapi(current_area_index - 1, 0, area_buttons.size())
		_highlight_tab()
		build_current_tab_list()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("cycle_right_hand"):
		current_area_index = wrapi(current_area_index + 1, 0, area_buttons.size())
		_highlight_tab()
		build_current_tab_list()
		get_viewport().set_input_as_handled()
		return

	elif event.is_action_pressed("cycle_item_down") or event.is_action_pressed("ui_down"):
		selected_bonfire_index = (selected_bonfire_index + 1) % bonfire_buttons.size()
		_highlight_selected()
		_update_preview_for_current_bonfire()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cycle_item_up") or event.is_action_pressed("ui_up"):
		selected_bonfire_index = (selected_bonfire_index - 1 + bonfire_buttons.size()) % bonfire_buttons.size()
		_highlight_selected()
		_update_preview_for_current_bonfire()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if selected_bonfire_index < bonfire_buttons.size():
			bonfire_buttons[selected_bonfire_index].pressed.emit()

func _update_preview_for_current_bonfire() -> void:
	if not preview_texture_rect:
		return
	if selected_bonfire_index >= current_sorted_bonfires.size():
		preview_texture_rect.texture = null
		return

	var entry = current_sorted_bonfires[selected_bonfire_index]
	preview_texture_rect.texture = entry.preview_texture

	if preview_texture_rect.texture:
		var tex = preview_texture_rect.texture
		var ratio = min(600.0 / tex.get_width(), 400.0 / tex.get_height())
		preview_texture_rect.custom_minimum_size = Vector2(tex.get_width() * ratio, tex.get_height() * ratio)

func _on_bonfire_selected(bonfire_id: String) -> void:
	warp_selected.emit(bonfire_id)
	menu_closed.emit()
