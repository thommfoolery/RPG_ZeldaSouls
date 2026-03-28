extends Node2D

# test_room.gd (attach to root Node2D)
@onready var player = $Player  # or get_node
@onready var camera = $Player/Camera2D

func _ready() -> void:

	if Global.has_pending_bloodstain:
		if Global.last_death_scene == scene_file_path:
			print("[Scene] Restoring bloodstain from death at ", Global.last_death_pos)
			var bloodstain = preload("res://scenes/entities/bloodstain/bloodstain.tscn").instantiate()
			bloodstain.global_position = Global.last_death_pos
			bloodstain.souls_held = Global.dropped_souls
			# Add to your ysort / entity container
			$ysort.add_child(bloodstain)  # CHANGE $ysort to your actual YSort node name
			Global.clear_pending_bloodstain()
			print("[Scene] Bloodstain restored")
		else:
			print("[Scene] Bloodstain pending in different scene — not spawning here")
