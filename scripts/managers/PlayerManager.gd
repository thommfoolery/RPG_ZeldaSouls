# autoload/PlayerManager.gd
extends Node

signal player_changed(new_player: Node)

var current_player: Node = null

func _ready() -> void:
	print("[PlayerManager] Ready — tracking current player reference")

func register_player(player: Node) -> void:
	var old_id = current_player.get_instance_id() if current_player and is_instance_valid(current_player) else -1
	current_player = player
	
	print("[PLAYER-LIFECYCLE] PlayerManager.register_player() | New ID: ", player.get_instance_id(), 
		  " | Old ID was: ", old_id, " | Scene: ", get_tree().current_scene.scene_file_path.get_file() if get_tree().current_scene else "none")
	
	player_changed.emit(player)

func register_player_from_group() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("[PLAYER-LIFECYCLE] register_player_from_group found player (ID: ", player.get_instance_id(), ")")
		register_player(player)
	else:
		print("[PLAYER-LIFECYCLE] register_player_from_group — no player in group yet")
