extends Area2D

@export var souls_value: int = 50

@export var fall_distance: float = 6.0
@export var fall_duration: float = 0.05
@export var bounce_amount: float = 1.0
@export var bounce_duration: float = 0.05

@export var glow_pulse_min: float = 0.8   # dimmest glow
@export var glow_pulse_max: float = 1.4   # brightest glow
@export var glow_pulse_duration: float = 1.2  # full pulse cycle

@onready var sprite: Sprite2D = $Sprite2D  # assuming your sprite node is named this

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Start invisible, fade in glow over 0.2s
	modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Fall + bounce (your values)
	var fall_tween = create_tween()
	fall_tween.set_ease(Tween.EASE_OUT)
	fall_tween.set_trans(Tween.TRANS_CUBIC)
	fall_tween.tween_property(self, "position:y", position.y + fall_distance, fall_duration)
	fall_tween.tween_property(self, "position:y", position.y + fall_distance - bounce_amount, bounce_duration)
	fall_tween.tween_property(self, "position:y", position.y + fall_distance, bounce_duration * 0.6)
	
	# Start idle glow pulse loop (after fade-in)
	await fade_tween.finished
	glow_pulse_loop()

func glow_pulse_loop() -> void:
	while true:
		var pulse_tween = create_tween()
		pulse_tween.tween_property(sprite, "modulate", Color(glow_pulse_max, glow_pulse_max, glow_pulse_max), glow_pulse_duration * 0.5)
		pulse_tween.tween_property(sprite, "modulate", Color(glow_pulse_min, glow_pulse_min, glow_pulse_min), glow_pulse_duration * 0.5)
		await pulse_tween.finished

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		
		PlayerStats.add_souls(souls_value)
		PlayerStats.souls_changed.emit(PlayerStats.souls_carried)  # force HUD update
		print("DEBUG: Picked up ", souls_value, " souls — total: ", PlayerStats.souls_carried)
		
		# Pickup flash: bright burst then fade out
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 1.0), 0.1)  # super bright gold
		flash_tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		flash_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
		
		await flash_tween.finished
		queue_free()
