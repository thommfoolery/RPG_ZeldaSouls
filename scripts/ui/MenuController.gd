# scripts/ui/MenuController.gd
extends CanvasLayer
signal menu_closed

@onready var tab_container: TabContainer = $Content

# ── Hold-to-close settings ──
@export var close_hold_time: float = 0.25
var b_hold_timer: float = 0.0
var is_holding_b: bool = false

# ── Data-driven tab configuration (single source of truth) ──
const TAB_CONFIG = {
	0: { "name": "Inventory",  "refresh_method": "_refresh_current_category" },
	1: { "name": "Equipment",  "refresh_method": "_refresh_all_slot_visuals" },
	2: { "name": "Stats",      "refresh_method": null },
	3: { "name": "System",     "refresh_method": "_update_selection" },
	# Add new DLC tabs here in the future without touching any other code
}

# ── Remember last used tab (preferred behavior) ──
var last_tab_index: int = 0

# ── Safety flags ──
var _just_closed_this_frame: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	
	visibility_changed.connect(_on_visibility_changed)
	
	if InputManager:
		InputManager.menu_toggled.connect(_on_menu_toggled)
	
	# Debug: show tab mapping once at startup
	print("[MENU-DEBUG] MenuController _ready() — data-driven tabs + last-tab memory + ghost-A protection")
	for idx in TAB_CONFIG:
		var cfg = TAB_CONFIG[idx]
		print("[MENU-DEBUG]   Tab #", idx, " → ", cfg.name, " | refresh: ", cfg.refresh_method)
	
	print("[MENU-DEBUG] Ready — fully centralized and future-proof")


func _on_menu_toggled() -> void:
	print("[MENU-DEBUG] _on_menu_toggled() SIGNAL fired → visible was ", visible)
	visible = not visible


func _on_visibility_changed() -> void:
	print("[MENU-DEBUG] visibility_changed() → visible=", visible, " | blocked=", InputManager.input_blocked if InputManager else "null")
	Global.is_in_menu = visible
	if InputManager:
		InputManager.input_blocked = visible
	
	if visible:
		_enable_all_tabs()
		print("[MENU-DEBUG] [", Time.get_ticks_msec(), "] === MENU OPENED - ALL tabs re-enabled ===")
	else:
		_disable_all_tabs()
		_just_closed_this_frame = true
		call_deferred("_final_focus_flush")
		print("[MENU-DEBUG] [", Time.get_ticks_msec(), "] === MENU CLOSED ===")
		menu_closed.emit()


# ────────────────────────────────────────────────────────────────
#  ENABLE / DISABLE — ALL tabs + delayed tab restore
# ────────────────────────────────────────────────────────────────

func _enable_all_tabs() -> void:
	print("[MENU-DEBUG] _enable_all_tabs() START")
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	tab_container.process_mode = Node.PROCESS_MODE_ALWAYS
	tab_container.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_container.focus_mode = Control.FOCUS_ALL
	
	# Enable every tab page
	for i in tab_container.get_tab_count():
		var tab_page = tab_container.get_tab_control(i)
		if tab_page:
			tab_page.visible = true
			tab_page.process_mode = Node.PROCESS_MODE_ALWAYS
			tab_page.mouse_filter = Control.MOUSE_FILTER_STOP
			tab_page.focus_mode = Control.FOCUS_ALL
			_recursive_enable(tab_page)
			print("[MENU-DEBUG]   → Enabled tab page #", i, ": ", tab_page.name)
	
	# Restore last tab after enabling (double defer for TabContainer stability)
	call_deferred("_apply_last_tab_index")
	print("[MENU-DEBUG] _enable_all_tabs() FINISHED")


func _apply_last_tab_index() -> void:
	tab_container.current_tab = last_tab_index
	print("[MENU-DEBUG]   → Restored last_tab_index = ", last_tab_index, 
		  " (tab name: ", tab_container.get_tab_control(last_tab_index).name if tab_container.get_tab_control(last_tab_index) else "???")
	call_deferred("_wake_up_current_tab")


func _disable_all_tabs() -> void:
	print("[MENU-DEBUG] _disable_all_tabs() START")
	# Save current tab before disabling
	last_tab_index = tab_container.current_tab
	print("[MENU-DEBUG]   → Saved last_tab_index = ", last_tab_index)
	
	tab_container.process_mode = Node.PROCESS_MODE_DISABLED
	tab_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.focus_mode = Control.FOCUS_NONE
	
	for i in tab_container.get_tab_count():
		var tab_page = tab_container.get_tab_control(i)
		if tab_page:
			tab_page.process_mode = Node.PROCESS_MODE_DISABLED
			tab_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tab_page.focus_mode = Control.FOCUS_NONE
			_recursive_disable(tab_page)
			print("[MENU-DEBUG]   → Disabled tab page #", i, ": ", tab_page.name)
	print("[MENU-DEBUG] _disable_all_tabs() FINISHED")


func _recursive_enable(node: Node) -> void:
	if node is Control:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.focus_mode = Control.FOCUS_ALL
	for child in node.get_children():
		_recursive_enable(child)


func _recursive_disable(node: Node) -> void:
	if node is Control:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
		node.release_focus()
	for child in node.get_children():
		_recursive_disable(child)


func _wake_up_current_tab() -> void:
	print("[MENU-DEBUG] _wake_up_current_tab() — forcing current tab refresh + focus")
	tab_container.grab_focus()
	
	var current_tab_content = tab_container.get_current_tab_control()
	if not current_tab_content:
		print("[MENU-DEBUG]   → WARNING: No current tab content!")
		return
	
	print("[MENU-DEBUG]   → Current tab is: ", current_tab_content.name)
	
	# Data-driven refresh
	var config = TAB_CONFIG.get(tab_container.current_tab, {})
	var method = config.get("refresh_method")
	if method and current_tab_content.has_method(method):
		current_tab_content.call_deferred(method)
		print("[MENU-DEBUG]   → Called data-driven method: ", method)
	else:
		print("[MENU-DEBUG]   → No refresh method for this tab (or null)")
	
	call_deferred("_force_inner_focus", current_tab_content)


func _force_inner_focus(tab_content: Control) -> void:
	print("[MENU-DEBUG] _force_inner_focus() on ", tab_content.name)
	var first = _find_first_focusable(tab_content)
	if first:
		first.grab_focus()
		print("[MENU-DEBUG]   → Grabbed focus on first interactive child: ", first.name)
	else:
		tab_content.grab_focus()
		print("[MENU-DEBUG]   → No child found — grabbed focus on tab root")


func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node
	for child in node.get_children():
		var found = _find_first_focusable(child)
		if found:
			return found
	return null


func _final_focus_flush() -> void:
	get_viewport().gui_release_focus()
	_clear_all_focus()
	_just_closed_this_frame = false
	print("[MENU-DEBUG] Final focus flush completed — ghost A protection active")


func _clear_all_focus() -> void:
	tab_container.release_focus()
	_recursive_disable(tab_container)


# ────────────────────────────────────────────────────────────────
#  INPUT
# ────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		if _just_closed_this_frame and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
			get_viewport().set_input_as_handled()
			print("[MENU-DEBUG] Ate ghost ui_accept / interact")
			return
		return
	
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_cancel"):
		Global.menu_close_cooldown_until = Time.get_ticks_msec() + 250
		print("[MENU-DEBUG] B pressed while menu open → closing")
		_on_menu_toggled()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("lb"):
		tab_container.current_tab = wrapi(tab_container.current_tab - 1, 0, tab_container.get_tab_count())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rb"):
		tab_container.current_tab = wrapi(tab_container.current_tab + 1, 0, tab_container.get_tab_count())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not is_holding_b:
		return
	b_hold_timer += delta
	if b_hold_timer >= close_hold_time:
		is_holding_b = false
		b_hold_timer = 0.0
		_on_menu_toggled()
		get_viewport().set_input_as_handled()
