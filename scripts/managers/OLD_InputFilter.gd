extends Node
class_name InputFilter

func _ready() -> void:
	print("[InputFilter] Ready — now guarding menu inputs")

func _input(event: InputEvent) -> void:
	if not Global.is_in_menu:
		return  # let everything through to gameplay
	
	# We're in a menu — only allow menu actions
	if event.is_action_pressed("ui_cancel"):
		print("[InputFilter-DEBUG] ui_cancel pressed while in menu | active menus: ", UIManager.active_menus.size() if UIManager else "UIManager missing")
		if UIManager and UIManager.active_menus.size() > 0:
			UIManager.close_top_menu()
			get_viewport().set_input_as_handled()
		else:
			print("[InputFilter-WARNING] ui_cancel in menu but no active menus or UIManager missing")
	
	# Optional: handle ui_accept the same way later
	#if event.is_action_pressed("ui_accept"):
	#    if UIManager and UIManager.active_menus.size() > 0:
	#        UIManager.confirm_focused()
	#        get_viewport().set_input_as_handled()
