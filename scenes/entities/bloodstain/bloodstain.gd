# scripts/entities/bloodstain/bloodstain.gd
extends Area2D

@export var souls_held: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var souls_label: Label = $SoulsLabel

var pending_position: Vector2 = Vector2.ZERO
var spawn_time: int = 0
var ignore_until: int = 0

func _ready() -> void:
	add_to_group("bloodstains")  # Required for cleanup in WorldManager/BloodstainManager
	print("[Bloodstain-DEBUG] _ready() - spawned at ", global_position, " with ", souls_held, " souls")
	
	if sprite:
		sprite.play("idle")
		sprite.visible = true
	
	update_label()
	
	if pending_position != Vector2.ZERO:
		global_position = pending_position
	
	#spawn_time = Time.get_ticks_msec()
	#ignore_until = spawn_time + 100  # 4s grace period to prevent instant pickup after spawn
	print("[Bloodstain] 4s grace period active (pickup blocked until ", ignore_until, ")")

func set_bloodstain_position(pos: Vector2) -> void:
	if is_inside_tree():
		global_position = pos
	else:
		pending_position = pos

func set_souls_held(value: int) -> void:
	souls_held = value
	update_label()

func update_label() -> void:
	if souls_label:
		souls_label.text = str(souls_held)
		souls_label.visible = souls_held > 0

func _on_pickup_area_body_entered(body: Node) -> void:
	if Time.get_ticks_msec() < ignore_until:
		print("[Bloodstain] Pickup IGNORED — still in 4-second grace period")
		return
	
	# ────────────────────────────────────────────────────────────────
	# IMPORTANT: Removed the permanent "near bonfire" block
	# Player should ALWAYS be able to collect souls from bloodstain
	# ────────────────────────────────────────────────────────────────
	print("[Bloodstain-DEBUG] _on_pickup_area_body_entered triggered → body: ", body.name)
	
	if body and body.is_in_group("player"):
		print("[Bloodstain] Player picked up - recovering ", souls_held, " souls")
		if souls_held > 0:
			PlayerStats.souls_carried += souls_held
			PlayerStats.souls_changed.emit(PlayerStats.souls_carried)
		
		Global.clear_pending_bloodstain()
		
		# ─── EXTRA SAFETY: force full cleanup of new fields (prevents empty stains) ───
		Global.death_scene_path = ""
		Global.death_locked_pos = Vector2.ZERO
		print("[Bloodstain] Pickup → FULL CLEAR (scene_path + locked_pos reset)")
		
		Global.is_death_respawn = false
		print("[Bloodstain] Pickup → reset is_death_respawn = false (normal reloads enabled)")
		
		EventBus.bloodstain_collected.emit(souls_held)
		print("[Bloodstain] Emitted bloodstain_collected via EventBus — souls: ", souls_held)
		
		if SaveManager:
			SaveManager.request_save()
		
		# Flash + disappear effect (unchanged)
		var flash_tween = create_tween()
		flash_tween.set_parallel()
		flash_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15)
		flash_tween.tween_property(self, "modulate", Color(1.8, 1.5, 0.4), 0.15)
		flash_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		await flash_tween.finished
		queue_free()
