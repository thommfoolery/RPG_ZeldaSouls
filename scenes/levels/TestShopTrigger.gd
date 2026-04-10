# TestShopTrigger.gd
extends Area2D

func _ready() -> void:
	monitoring = true
	monitorable = true
	print("[TestShopTrigger] Ready — monitoring = ", monitoring)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[TestShopTrigger] PLAYER ENTERED the trigger zone!")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("[TestShopTrigger] Player left the trigger zone")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var bodies = get_overlapping_bodies()
		print("[TestShopTrigger] A pressed — overlapping bodies: ", bodies.size())
		for body in bodies:
			if body.is_in_group("player"):
				print("[TestShopTrigger] → Player detected! Opening shop...")
				VendorManager.open_vendor("blacksmith_01")
				get_viewport().set_input_as_handled()
				return
		print("[TestShopTrigger] No player found in overlapping bodies")
