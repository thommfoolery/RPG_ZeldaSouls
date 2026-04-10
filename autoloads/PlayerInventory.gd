# autoload/PlayerInventory.gd
extends Node
signal inventory_changed

var inventory: Dictionary = {
	"Consumables": [], "Keys": [], "Materials": [], "Spells": [],
	"Weapons": [], "Ammo": [], "Armor": [], "Rings": [], "Quest": []
}

func _ready() -> void:
	print("[PlayerInventory] Ready")


func add_item(new_item: GameItem, qty: int = 1) -> void:
	if not new_item or not new_item.category:
		push_warning("[PlayerInventory] Tried to add invalid item")
		return
	
	var cat = new_item.category
	if not inventory.has(cat):
		inventory[cat] = []

	# DEBUG: Tell us what item we're adding and whether it should stack
	print("[DEBUG] add_item() → ", new_item.display_name, " | id=", new_item.id, " | stacks=", new_item.stacks, " | qty=", qty)

	# ─── NEW: Respect stacks flag ───
	if new_item.stacks:
		# Stackable items (consumables, ammo, etc.)
		for entry in inventory[cat]:
			if entry and entry.id == new_item.id:
				entry.quantity += qty
				print("[DEBUG] Stacked → new quantity = ", entry.quantity)
				inventory_changed.emit()
				return
	else:
		# Non-stacking items (bows, unique weapons, etc.)
		print("[DEBUG] Non-stacking item → adding as separate entry")

	# Add as new entry
	var copy = new_item.duplicate()
	copy.quantity = qty
	inventory[cat].append(copy)
	
	print("[DEBUG] Added new separate item: ", new_item.display_name)
	inventory_changed.emit()

func has_enough(item_id: String, qty: int = 1) -> bool:
	for cat in inventory:
		for item in inventory[cat]:
			if item and item.id == item_id and item.quantity >= qty:
				return true
	return false

# ─── SAVE / LOAD ─────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	var save_dict = {}
	for category in inventory:
		save_dict[category] = []
		for item in inventory[category]:
			if item:
				var entry = {
					"id": item.id,
					"quantity": item.quantity
				}
				save_dict[category].append(entry)
				
				#if category == "Keys":
					#print("[KEYS-DEBUG] SAVING Key → id='", item.id, "' | qty=", item.quantity)
	
	return save_dict


func from_save_dict(data: Dictionary) -> void:
	inventory.clear()
	
	print("[INVENTORY-DEBUG] from_save_dict() started — data has ", data.size(), " categories")
	
	for category in data:
		inventory[category] = []
		for entry in data[category]:
			var item_id = entry.get("id", "")
			var qty = entry.get("quantity", 1)
			
			if item_id.is_empty():
				if category == "Keys":
					print("[KEYS-DEBUG] SKIPPED — Key had no id in save data!")
				continue
			
			var resource_path = "res://resources/items/" + item_id + ".tres"
			
			if category == "Keys":
				print("[KEYS-DEBUG] LOADING Key → id='", item_id, "' | path='", resource_path, "'")
			
			var real_item = load(resource_path) as GameItem
			
			if real_item:
				var copy = real_item.duplicate()
				copy.quantity = qty
				inventory[category].append(copy)
				
				if category == "Keys":
					print("[KEYS-DEBUG] SUCCESS — Loaded Key: ", copy.display_name, " x", qty)
				else:
					print("[PlayerInventory] Loaded real item: ", copy.display_name, " x", qty)
			else:
				if category == "Keys":
					push_error("[KEYS-DEBUG] FAILED to load Key resource: " + resource_path + " | id='" + item_id + "'")
				else:
					push_warning("[PlayerInventory] Could not load item resource: " + resource_path)
	
	print("[PlayerInventory] Loaded inventory with ", get_total_item_count(), " items")
	inventory_changed.emit()


func get_total_item_count() -> int:
	var total = 0
	for cat in inventory:
		total += inventory[cat].size()
	return total

# Add this at the very bottom of PlayerInventory.gd
func consume_item(item_id: String, qty: int = 1) -> void:
	print("[INVENTORY-DEBUG] consume_item called → id=", item_id, " qty=", qty)
	for cat in inventory:
		for i in range(inventory[cat].size()):
			var entry = inventory[cat][i]
			if entry and entry.id == item_id:
				if entry.quantity > qty:
					entry.quantity -= qty
					print("[INVENTORY-DEBUG] Reduced ", item_id, " from ", entry.quantity + qty, " to ", entry.quantity)
				else:
					inventory[cat].remove_at(i)
					print("[INVENTORY-DEBUG] Removed last ", item_id, " from inventory")
				inventory_changed.emit()
				return
	print("[INVENTORY-DEBUG] Could not find item ", item_id, " to consume")
