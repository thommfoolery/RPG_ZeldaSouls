# scenes/ui/menus/ShopMenu.gd
extends CanvasLayer

# Node references
@onready var item_grid: GridContainer = $Content/MainContainer/ItemScroll/ItemGrid
@onready var details_name: Label = $Content/MainContainer/DetailsPanel/NameLabel
@onready var details_icon: TextureRect = $Content/MainContainer/DetailsPanel/Icon
@onready var details_desc: Label = $Content/MainContainer/DetailsPanel/DescriptionLabel

@onready var quantity_selector: Control = $Content/QuantitySelector
@onready var qty_label: Label = $Content/QuantitySelector/QTYLabel
@onready var qty_confirm: Button = $Content/QuantitySelector/HBoxContainer/ConfirmButton
@onready var qty_cancel: Button = $Content/QuantitySelector/HBoxContainer/CancelButton

# Runtime
var current_vendor_id: String = ""
var current_listings: Array[ShopListing] = []
var current_item_index: int = 0
var _pending_listing: ShopListing = null
var _selected_qty: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	
	quantity_selector.visible = false
	
	if qty_confirm:
		qty_confirm.pressed.connect(_confirm_quantity)
	if qty_cancel:
		qty_cancel.pressed.connect(_cancel_quantity)
	
	print("[ShopMenu] Ready — Single All Items grid (direct buy)")

func open_for_vendor(vendor_id: String) -> void:
	if Global.is_in_menu and visible:
		return
	
	current_vendor_id = vendor_id
	visible = true
	Global.is_in_menu = true
	InputManager.input_blocked = true
	
	print("[ShopMenu] Shop opened for vendor: ", vendor_id)
	_populate_grid()

func _populate_grid() -> void:
	_clear_grid()
	var vendor = VendorManager._get_vendor(current_vendor_id)
	if not vendor: return
	
	current_listings.clear()
	for listing in vendor.shop_listings:
		if _should_show_listing(listing):
			current_listings.append(listing)
	
	for i in current_listings.size():
		var listing = current_listings[i]
		var live_stock = VendorManager.get_current_stock(current_vendor_id, i)   # ← this is correct, inside the loop
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.icon = listing.item.icon
		btn.text = listing.item.display_name + "\nx" + str(live_stock if listing.max_stock != -1 else "∞")
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 18)
		item_grid.add_child(btn)
		btn.pressed.connect(_on_item_selected.bind(i))
	
	if current_listings.size() > 0:
		current_item_index = 0
		_update_details(0)
		_highlight_current_item()

func _clear_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()

# ─── Navigation (D-Pad) ─────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible: return
	get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		if quantity_selector and quantity_selector.visible:
			_cancel_quantity()
		else:
			_close_shop()
		return
	
	if quantity_selector and quantity_selector.visible:
		_handle_quantity_input(event)
		return
	
	# Grid navigation
	if event.is_action_pressed("cycle_left_hand") or event.is_action_pressed("cycle_item_up"):
		current_item_index = wrapi(current_item_index - 1, 0, current_listings.size())
		_refresh_current_item()
	elif event.is_action_pressed("cycle_right_hand") or event.is_action_pressed("cycle_item_down"):
		current_item_index = wrapi(current_item_index + 1, 0, current_listings.size())
		_refresh_current_item()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_open_quantity_selector()

func _handle_quantity_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("cycle_item_up"):
		_change_quantity(1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("cycle_item_down"):
		_change_quantity(-1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_confirm_quantity()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_quantity()

func _change_quantity(direction: int) -> void:
	if not _pending_listing: return
	
	# Use LIVE stock from VendorManager
	var live_stock = VendorManager.get_current_stock(current_vendor_id, current_listings.find(_pending_listing))
	var max_available = live_stock if _pending_listing.max_stock != -1 else 99
	
	_selected_qty = wrapi(_selected_qty + direction, 1, max_available + 1)
	_update_quantity_display()

func _update_quantity_display() -> void:
	if not _pending_listing or not qty_label: return
	
	var live_stock = VendorManager.get_current_stock(current_vendor_id, current_listings.find(_pending_listing))
	var max_available = live_stock if _pending_listing.max_stock != -1 else 99
	var price_per_item = _pending_listing.buy_price if _pending_listing.buy_price > 0 else int(_pending_listing.item.value * 1.8)
	var total_price = price_per_item * _selected_qty
	
	qty_label.text = "Quantity: " + str(_selected_qty) + " / " + str(max_available) + "\nTotal: " + str(total_price) + " souls"

func _open_quantity_selector() -> void:
	if current_item_index >= current_listings.size(): return
	_pending_listing = current_listings[current_item_index]
	_selected_qty = 1
	_update_quantity_display()
	quantity_selector.visible = true

func _confirm_quantity() -> void:
	if not _pending_listing: return
	VendorManager.buy_item(current_vendor_id, current_listings.find(_pending_listing), _selected_qty)
	quantity_selector.visible = false
	_pending_listing = null
	_populate_grid()
	_highlight_current_item()

func _cancel_quantity() -> void:
	quantity_selector.visible = false
	_pending_listing = null

# ─── Details & Highlight ────────────────────────────────────────────────
func _update_details(index: int) -> void:
	if index >= current_listings.size(): return
	var listing = current_listings[index]
	if details_name: details_name.text = listing.item.display_name
	if details_icon: details_icon.texture = listing.item.icon
	if details_desc: details_desc.text = listing.item.description if listing.item.description else "No description."

func _refresh_current_item() -> void:
	_update_details(current_item_index)
	_highlight_current_item()

func _highlight_current_item() -> void:
	for i in item_grid.get_child_count():
		var btn = item_grid.get_child(i) as Button
		if btn:
			btn.modulate = Color(1.0, 0.9, 0.4) if i == current_item_index else Color(1.0, 1.0, 1.0)

func _on_item_selected(index: int) -> void:
	current_item_index = index
	_update_details(index)
	_open_quantity_selector()

# ─── Helper ─────────────────────────────────────────────────────────────
func _should_show_listing(listing: ShopListing) -> bool:
	if listing.max_stock != -1 and listing.current_stock <= 0:
		return false
	return true

# ─── Close ──────────────────────────────────────────────────────────────
func _close_shop() -> void:
	Global.menu_close_cooldown_until = Time.get_ticks_msec() + 250
	
	visible = false
	Global.is_in_menu = false
	InputManager.input_blocked = false
	queue_free()
	print("[ShopMenu] Shop closed cleanly")
