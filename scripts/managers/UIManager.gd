# autoload/UIManager.gd
extends CanvasLayer
signal ui_closed(menu_type: String)

@export var rest_menu_scene: PackedScene

# ─── Dynamic UI Elements (pickup + prompt) ─────────────────────────────
var interact_prompt: Label
var pickup_notification: Control
var pickup_icon: TextureRect
var pickup_name: Label
var pickup_qty: Label
var active_menus: Dictionary = {}

# ── B BUTTON SAFETY (centralized) ──
var ignore_b_release_until: int = 0   # timestamp in msec - eats the B release after closing any menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[UIManager] Ready - managing UI now")
	
	_create_ui_elements() # Creates prompt + notification safely
	
	if not rest_menu_scene:
		rest_menu_scene = preload("res://scenes/ui/rest_menu.tscn")


func _create_ui_elements() -> void:
	# Interact Prompt
	if not has_node("InteractPrompt"):
		interact_prompt = Label.new()
		interact_prompt.name = "InteractPrompt"
		interact_prompt.add_theme_font_size_override("font_size", 28)
		interact_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interact_prompt.position = Vector2(440, 620)
		add_child(interact_prompt)
	else:
		interact_prompt = $InteractPrompt
	interact_prompt.visible = false
	
	# Pickup Notification (independent popups)
	if not has_node("PickupNotification"):
		pickup_notification = Control.new()
		pickup_notification.name = "PickupNotification"
		pickup_notification.position = Vector2(440, 280)
		add_child(pickup_notification)
		
		var bg = Panel.new()
		bg.name = "Background"
		bg.custom_minimum_size = Vector2(420, 110)
		pickup_notification.add_child(bg)
		
		var hbox = HBoxContainer.new()
		hbox.name = "HBoxContainer"
		hbox.add_theme_constant_override("separation", 20)
		bg.add_child(hbox)
		
		pickup_icon = TextureRect.new()
		pickup_icon.name = "Icon"
		pickup_icon.custom_minimum_size = Vector2(80, 80)
		hbox.add_child(pickup_icon)
		
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		hbox.add_child(vbox)
		
		pickup_name = Label.new()
		pickup_name.name = "ItemName"
		pickup_name.add_theme_font_size_override("font_size", 32)
		vbox.add_child(pickup_name)
		
		pickup_qty = Label.new()
		pickup_qty.name = "Quantity"
		pickup_qty.add_theme_font_size_override("font_size", 24)
		vbox.add_child(pickup_qty)
	else:
		pickup_notification = $PickupNotification
		pickup_icon = $PickupNotification/Background/HBoxContainer/Icon
		pickup_name = $PickupNotification/Background/HBoxContainer/VBoxContainer/ItemName
		pickup_qty = $PickupNotification/Background/HBoxContainer/VBoxContainer/Quantity
	
	pickup_notification.visible = false
	print("[UIManager-DEBUG] UI elements ready")


# ─── Interact Prompt ─────────────────────────────────────────────────
func show_interact_prompt(text: String = "Pick up item") -> void:
	if interact_prompt:
		interact_prompt.text = "A " + text
		interact_prompt.visible = true


func hide_interact_prompt() -> void:
	if interact_prompt:
		interact_prompt.visible = false


# ─── Pickup Notification (independent popups) ─────────────────────────────
func show_pickup_notification(picked_item: GameItem, qty: int = 1) -> void:
	if not picked_item:
		return
	
	var popup = pickup_notification.duplicate()
	popup.name = "TempPickup_" + str(Time.get_ticks_msec())
	
	var icon = popup.get_node("Background/HBoxContainer/Icon")
	var name_label = popup.get_node("Background/HBoxContainer/VBoxContainer/ItemName")
	var qty_label = popup.get_node("Background/HBoxContainer/VBoxContainer/Quantity")
	
	icon.texture = picked_item.icon
	name_label.text = picked_item.display_name
	qty_label.text = "x" + str(qty)
	
	add_child(popup)
	popup.visible = true
	popup.modulate.a = 1.0
	
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(popup):
			var tween = create_tween()
			tween.tween_property(popup, "modulate:a", 0.0, 0.8)
			tween.tween_callback(popup.queue_free)
	)


# ─── Rest Menu (legacy - still kept for safety) ─────────────────────────────
func show_rest_menu() -> void:
	print("[UIManager-DEBUG] show_rest_menu CALLED from bonfire")
	if active_menus.has("rest"):
		print("[UIManager] Rest already open — ignoring")
		return
	if not rest_menu_scene:
		push_error("[UIManager] rest_menu_scene is missing!")
		return
	
	var menu = rest_menu_scene.instantiate()
	menu.layer = 100
	get_tree().root.add_child(menu)
	active_menus["rest"] = menu
	menu.visible = true
	menu.menu_closed.connect(_on_rest_closed.bind(menu), CONNECT_ONE_SHOT)
	print("[UIManager] Rest menu instantiated and forced visible (layer 100)")


func _on_rest_closed(menu_instance: CanvasLayer) -> void:
	print("[UIManager-DEBUG] _on_rest_closed triggered")
	get_tree().paused = false
	if is_instance_valid(menu_instance):
		menu_instance.queue_free()
	active_menus.erase("rest")
	ui_closed.emit("rest")
	print("[UIManager] Rest menu closed and cleaned up")


# ─────────────────────────────────────────────────────────────────────────────
# ─── NEW: INTEGRATED BONFIRE MENU (full-screen, non-floating) ───────────────
# ─────────────────────────────────────────────────────────────────────────────

func show_bonfire_menu(bonfire_id: String) -> void:
	print("[UIManager-DEBUG] show_bonfire_menu called for ", bonfire_id)
	
	if active_menus.has("bonfire"):
		print("[UIManager] Bonfire menu already open — ignoring")
		return
	
	var bonfire_menu_scene = preload("res://scenes/ui/BonfireMenu.tscn")
	if not bonfire_menu_scene:
		push_error("[UIManager] BonfireMenu.tscn is missing!")
		return
	
	var menu = bonfire_menu_scene.instantiate()
	get_tree().root.add_child(menu)
	active_menus["bonfire"] = menu
	
	menu.show_menu(bonfire_id)
	menu.bonfire_menu_closed.connect(_on_bonfire_closed.bind(menu), CONNECT_ONE_SHOT)
	
	print("[UIManager] BonfireMenu opened successfully (layer 110)")


func _on_bonfire_closed(menu_instance: CanvasLayer) -> void:
	print("[UIManager-DEBUG] _on_bonfire_closed triggered")
	
	if is_instance_valid(menu_instance):
		menu_instance.queue_free()
	
	active_menus.erase("bonfire")
	ui_closed.emit("bonfire")
	print("[UIManager] Bonfire menu cleaned up")


# ─── Rest of your original code (unchanged) ─────────────────────────────
