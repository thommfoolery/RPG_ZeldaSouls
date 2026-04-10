# autoload/VendorManager.gd
extends Node

var registry: VendorRegistry

# Runtime cache only
var _vendor_stock: Dictionary = {}  # key = "vendor_id_listing_index" → current_stock

signal shop_opened(vendor_id: String)
signal shop_closed

func _ready() -> void:
	registry = preload("res://resources/vendors/VendorRegistry.tres")
	if not registry:
		push_error("[VendorManager] Failed to load VendorRegistry.tres!")
		return
	
	_load_persisted_stock()
	print("[VendorManager] Loaded with ", registry.entries.size(), " vendors")

# ─── Open Shop ───
func open_vendor(vendor_id: String) -> void:
	if not _get_vendor(vendor_id):
		push_error("[VendorManager] Unknown vendor: " + vendor_id)
		return
	
	print("[VendorManager] Opening shop for ", vendor_id)
	shop_opened.emit(vendor_id)
	
	# ← THIS WAS MISSING — we still need to actually create the menu!
	var shop_scene = preload("res://scenes/ui/menus/ShopMenu.tscn").instantiate()
	get_tree().root.add_child(shop_scene)
	shop_scene.open_for_vendor(vendor_id)

# ─── Stock Access ───
func get_current_stock(vendor_id: String, listing_index: int) -> int:
	var key = vendor_id + "_" + str(listing_index)
	return _vendor_stock.get(key, 0)

func buy_item(vendor_id: String, listing_index: int, qty: int) -> bool:
	var vendor = _get_vendor(vendor_id)
	if not vendor or listing_index >= vendor.shop_listings.size():
		return false
	
	var listing = vendor.shop_listings[listing_index]
	var key = vendor_id + "_" + str(listing_index)
	var current = _vendor_stock.get(key, listing.current_stock)
	
	if current < qty:
		print("[VendorManager] Not enough stock for ", listing.item.display_name, " (", current, " available)")
		return false
	
	var price = listing.buy_price if listing.buy_price > 0 else int(listing.item.value * 1.8)
	if PlayerStats.souls_carried < price * qty:
		print("[VendorManager] Not enough souls")
		return false
	
	# Purchase
	PlayerStats.souls_carried -= price * qty
	PlayerInventory.add_item(listing.item, qty)
	PlayerStats.souls_changed.emit(PlayerStats.souls_carried)  # HUD fix
	
	_vendor_stock[key] = current - qty
	
	# Persist
	WorldStateManager.set_vendor_stock(vendor_id, listing_index, _vendor_stock[key])
	SaveManager.request_save()
	
	print("[VendorManager] Bought ", qty, "x ", listing.item.display_name, " | remaining: ", _vendor_stock[key])
	return true

# ─── Persistence ───
func _load_persisted_stock() -> void:
	_vendor_stock.clear()
	for vendor in registry.entries:
		for i in vendor.shop_listings.size():
			var key = vendor.vendor_id + "_" + str(i)
			var saved_stock = WorldStateManager.get_vendor_stock(vendor.vendor_id, i)
			_vendor_stock[key] = saved_stock if saved_stock != -1 else vendor.shop_listings[i].current_stock
	print("[VendorManager] Loaded persisted stock for all vendors")

# Helper
func _get_vendor(vendor_id: String) -> VendorEntry:
	for v in registry.entries:
		if v.vendor_id == vendor_id:
			return v
	return null
