extends Camera2D

# test_room.gd (attach to root Node2D)

@onready var camera = $Player/Camera2D
@onready var player = get_parent().get_node("Player") if get_parent().has_node("Player") else null

func _ready():
	if camera:
		camera.make_current()
