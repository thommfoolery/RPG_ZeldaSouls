# scenes/interactables/VendorTrigger.gd
extends Node2D

@export var vendor_id: String = "blacksmith_01"

@onready var prompt_label: Label = $PromptLabel
@onready var interaction_area: Area2D = $InteractionArea

var player_in_range: bool = false

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	print("[VendorTrigger] Ready for vendor: ", vendor_id)

# Called from InteractionArea signals
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if prompt_label:
			prompt_label.visible = true
		print("[VendorTrigger] Player entered range → ", vendor_id)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func _input(event: InputEvent) -> void:
	if not player_in_range: return
	if event.is_action_pressed("interact"):
		print("[VendorTrigger] A pressed → opening talk menu for ", vendor_id)
		_open_talk_menu()
		get_viewport().set_input_as_handled()

func _open_talk_menu() -> void:
	var talk_scene = preload("res://scenes/ui/menus/TalkMenu.tscn").instantiate()
	get_tree().root.add_child(talk_scene)
	talk_scene.open_for_vendor(vendor_id)
