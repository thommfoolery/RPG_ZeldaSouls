#WarpMenu.gd
extends Control

# Signals used by BonfireMenu
signal warp_selected(bonfire_id: String)   # Emitted when player chooses a bonfire to warp to
signal menu_closed                         # Emitted when player presses B to go back

# UI Nodes
@onready var tab_bar: HBoxContainer = %TabBar              # Horizontal container for area tabs
@onready var bonfire_list: VBoxContainer = %BonfireList    # Vertical list of bonfires in current area
@onready var preview_texture_rect: TextureRect = %PreviewTexture  # Right-side preview image

# Runtime data
var area_buttons: Array[Button] = []       # All area tab buttons
var bonfire_buttons: Array[Button] = []    # All bonfire buttons in the current tab
var current_area_index: int = 0            # Currently selected area tab
var selected_bonfire_index: int = 0        # Currently highlighted bonfire in the list

# Remembers which bonfire the player is physically sitting at
var current_bonfire_id: String = ""

func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	build_tabs()

# Called from BonfireMenu when opening the Warp menu
# This tells us which bonfire the player is currently resting at
func set_current_bonfire(bonfire_id: String) -> void:
	current_bonfire_id = bonfire_id
	
	# Force a full refresh so the correct tab + (Current) both appear immediately
	if area_buttons.size() > 0:
		_select_area_of_current_bonfire()
		build_current_tab_list()

# NEW: Forces the correct area tab to be selected based on current_bonfire_id
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
	# Clear previous content
	for child in tab_bar.get_children():
		child.queue_free()
	for child in bonfire_list.get_children():
		child.queue_free()
	
	area_buttons.clear()
	bonfire_buttons.clear()

	var discovered = PlayerStats.discovered_bonfires
	var grouped: Dictionary = {}   # area_name → Array[BonfireEntry]

	# Group discovered bonfires
	for bonfire_id in discovered.keys():
		var entry = BonfireManager.get_entry(bonfire_id)
		if not entry: continue
		var area = entry.area_name.strip_edges()
		if area.is_empty(): area = "Unknown Area"
		if not grouped.has(area):
			grouped[area] = []
		grouped[area].append(entry)

	# Get AreaEntry for each area so we can sort by sort_order
	var area_entries: Array[AreaEntry] = []
	for area_name in grouped.keys():
		var area_entry = AreaReg.registry.get_area(area_name) if AreaReg and AreaReg.registry else null
		if area_entry:
			area_entries.append(area_entry)
		else:
			# Fallback if no AreaEntry found
			var dummy = AreaEntry.new()
			dummy.area_id = area_name
			dummy.title = area_name
			dummy.sort_order = 999
			area_entries.append(dummy)

	# Sort areas by sort_order
	area_entries.sort_custom(func(a, b): return a.sort_order < b.sort_order)

	# Create tabs in sorted order
	for area_entry in area_entries:
		var btn = Button.new()
		btn.text = area_entry.title if area_entry.title else area_entry.area_id
		btn.custom_minimum_size = Vector2(180, 60)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_tab_pressed.bind(area_entry.area_id))
		tab_bar.add_child(btn)
		area_buttons.append(btn)

	if area_buttons.size() > 0:
		_highlight_tab()
		build_current_tab_list()

func build_current_tab_list() -> void:
	# Clear old bonfire buttons
	for child in bonfire_list.get_children():
		child.queue_free()
	bonfire_buttons.clear()

	if current_area_index >= area_buttons.size():
		return

	var current_area = area_buttons[current_area_index].text

	# ── COLLECT ALL BONFIRES IN THIS AREA ──
	var bonfires_in_area: Array[BonfireEntry] = []
	for bonfire_id in PlayerStats.discovered_bonfires.keys():
		var entry = BonfireManager.get_entry(bonfire_id)
		if entry and entry.area_name == current_area:
			bonfires_in_area.append(entry)

	# ── SORT BY sort_order (Golden Order) ──
	# Lower sort_order appears first in the list
	bonfires_in_area.sort_custom(func(a: BonfireEntry, b: BonfireEntry) -> bool:
		return a.sort_order < b.sort_order
	)

	# ── CREATE BUTTONS IN SORTED ORDER ──
	for entry in bonfires_in_area:
		var btn = Button.new()
		btn.text = "     " + entry.title
		
		# Special styling for the bonfire the player is currently sitting at
		if entry.bonfire_id == current_bonfire_id:
			btn.text += "  (Current)"
			btn.modulate = Color(0.85, 0.7, 0.25)   # Darker gold for "Current"

		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 24)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		btn.pressed.connect(_on_bonfire_selected.bind(entry.bonfire_id))
		bonfire_list.add_child(btn)
		bonfire_buttons.append(btn)

	# ── Highlight the correct bonfire (including Current) ──
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
			# Dark gold when not selected, bright when highlighted
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

	# Block left thumbstick completely (same as EquipmentTab / InventoryTab)
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		menu_closed.emit()
		return

	# Left / Right = Switch area tabs
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

	# Up / Down = Navigate bonfires in current tab
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

	# A = Select highlighted bonfire
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if selected_bonfire_index < bonfire_buttons.size():
			bonfire_buttons[selected_bonfire_index].pressed.emit()

# Updates the preview image when moving through bonfires
func _update_preview_for_current_bonfire() -> void:
	if not preview_texture_rect:
		return
	
	if selected_bonfire_index >= bonfire_buttons.size():
		preview_texture_rect.texture = null
		return

	var current_area = area_buttons[current_area_index].text
	var count = 0
	for bonfire_id in PlayerStats.discovered_bonfires.keys():
		var entry = BonfireManager.get_entry(bonfire_id)
		if entry and entry.area_name == current_area:
			if count == selected_bonfire_index:
				preview_texture_rect.texture = entry.preview_texture
				# Enforce max 400x400 while keeping aspect ratio
				if preview_texture_rect.texture:
					var tex = preview_texture_rect.texture
					var ratio = min(400.0 / tex.get_width(), 400.0 / tex.get_height())
					preview_texture_rect.custom_minimum_size = Vector2(tex.get_width() * ratio, tex.get_height() * ratio)
				return
			count += 1
	
	preview_texture_rect.texture = null

func _on_bonfire_selected(bonfire_id: String) -> void:
	warp_selected.emit(bonfire_id)
	menu_closed.emit()
	
