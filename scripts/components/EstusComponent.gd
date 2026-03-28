# scripts/components/EstusComponent.gd
extends Node
class_name EstusComponent

@onready var player = get_parent() as CharacterBody2D
@onready var sprite = player.get_node_or_null("SpriteContainer/AnimatedSprite2D")

var is_drinking: bool = false

func _ready() -> void:
	if not player:
		push_error("[EstusComponent] No parent player found!")
	if not sprite:
		push_warning("[EstusComponent] No AnimatedSprite2D found — animation won't play")
	if InputManager:
		InputManager.use_item_pressed.connect(_on_use_item_pressed)
		print("[EstusComponent] Connected to use_item_pressed")
	else:
		push_warning("[EstusComponent] InputManager not found!")
		

func _on_use_item_pressed() -> void:
	if is_drinking or PlayerStats.current_estus <= 0 or Global.is_death_respawn:
		print("[EstusComponent] Blocked estus use — drinking, no charges, or death respawn")
		return

	is_drinking = true
	InputManager.input_blocked = true
	print("[EstusComponent] Estus drink STARTED — input blocked")

	# Pause normal animation logic
	var anim_comp = player.get_node_or_null("AnimationComponent")
	if anim_comp:
		anim_comp.set_process(false)

	# Play drink animation
	var sprite = player.get_node_or_null("SpriteContainer/AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("drink"):
		sprite.stop()
		sprite.sprite_frames.set_animation_loop("drink", false)
		sprite.play("drink")
		print("[EstusComponent] Forced sprite.play('drink')")
	else:
		print("[EstusComponent] WARNING: No 'drink' animation found")

	var drink_duration = .5
	
	var timer = Timer.new()
	timer.wait_time = drink_duration
	timer.one_shot = true
	player.add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()

	# === HEAL MOMENT - Trigger particles here ===
	var particles = player.get_node_or_null("Effects/EstusHealParticles")
	if particles and particles is GPUParticles2D:
		particles.emitting = true
		print("[EstusComponent] Estus heal particles triggered")
		



	# Do the actual heal
	if PlayerStats.use_estus():
		var anim = player.get_node_or_null("AnimationComponent")
		if anim and anim.has_method("flash_heal"):
			anim.flash_heal()
			anim.flash_impact_heal()
		print("[Feature-DEBUG] Estus used successfully — healed")
	else:
		print("[Feature-DEBUG] Estus use cancelled mid-drink")
	# Re-enable animation system
	if anim_comp:
		anim_comp.set_process(true)

	is_drinking = false
	InputManager.input_blocked = false
	print("[EstusComponent] Estus drink FINISHED — input unblocked")
