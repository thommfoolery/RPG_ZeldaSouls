# scripts/components/MovementComponent.gd
extends Node
class_name MovementComponent

@export var can_move: bool = true   # ← THIS LINE MUST EXIST AND BE @export OR PUBLIC
@export var base_speed: float = 80.0
@export var sprint_multiplier: float = 1.6
@export var sprint_drain_per_sec: float = 35.0
@export var sprint_min_stamina: float = 10.0

# Evade settings (editable in inspector)
@export var backstep_distance: float = 90.0
@export var dodge_roll_distance: float = 140.0
@export var evade_duration: float = 0.45
@export var evade_stamina_cost: float = 25.0

@onready var body: CharacterBody2D = get_parent()
@onready var stamina: StaminaComponent = get_parent().get_node("StaminaComponent")

var move_direction: Vector2 = Vector2.ZERO
var current_speed: float = base_speed
var wants_to_sprint: bool = false

# Sprint / Dodge / Backstep system
var sprint_hold_timer: float = 0.0
var sprint_tap_threshold: float = 0.5
var last_dir := Vector2.RIGHT

# Evade state
var evade_velocity: Vector2 = Vector2.ZERO
var evade_timer: float = 0.0

func _ready() -> void:
	if InputManager:
		InputManager.sprint_toggled.connect(_on_sprint_toggled)
		InputManager.direction_changed.connect(_on_direction_updated)
		print("[MovementComponent] Connected to InputManager.sprint_toggled + direction_changed")
	else:
		push_warning("[MovementComponent] InputManager not found!")
	
	if not stamina:
		push_warning("[MovementComponent] StaminaComponent not found!")

func _process(delta: float) -> void:
	if evade_timer > 0:
		evade_timer -= delta
		if evade_timer <= 0:
			evade_velocity = Vector2.ZERO
			InputManager.input_blocked = false
			print("[Feature-DEBUG] Evade finished")
	
	if wants_to_sprint and evade_timer <= 0:
		sprint_hold_timer += delta
	else:
		sprint_hold_timer = 0.0

func _physics_process(delta: float) -> void:
	# ── BONFIRE SIT LOCK ──
	# Lock normal movement while menu is open, BUT allow evade/roll/backstep to still move the player
	if InputManager.input_blocked and evade_timer <= 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return   # ← early return, nothing else runs

	# ── NORMAL MOVEMENT BELOW ──
	if evade_timer > 0:
		body.velocity = evade_velocity
	else:
		InputManager.update_move_direction(move_direction)
		# HARD FIX: If stamina is effectively 0, stop sprinting
		var effective_stamina = stamina.current_stamina if stamina else 0.0
		var should_sprint = wants_to_sprint and sprint_hold_timer >= sprint_tap_threshold and effective_stamina > 1.0
		current_speed = base_speed * sprint_multiplier if should_sprint else base_speed
		body.velocity = move_direction * current_speed
	
	body.move_and_slide()
	
	# Drain only while actually sprinting with stamina
	if wants_to_sprint and evade_timer <= 0 and sprint_hold_timer >= sprint_tap_threshold and move_direction.length_squared() > 0.01 and stamina and stamina.current_stamina > 1.0:
		stamina.drain(sprint_drain_per_sec * delta)

func _on_direction_updated(new_dir: Vector2) -> void:
	move_direction = new_dir.normalized() if new_dir.length_squared() > 0.01 else Vector2.ZERO
	if new_dir.length_squared() > 0.01:
		last_dir = new_dir.normalized()

func _on_sprint_toggled(new_state: bool) -> void:
	wants_to_sprint = new_state
	
	# ── COOLDOWN AFTER MENU CLOSE ──
	if Time.get_ticks_msec() < Global.menu_close_cooldown_until:
		sprint_hold_timer = 0.0
		return
	
	# Prevent evade when ANY menu is open
	if Global.is_in_menu or InputManager.input_blocked:
		sprint_hold_timer = 0.0
		return
	
	if new_state:
		sprint_hold_timer = 0.0
	else:
		if sprint_hold_timer < sprint_tap_threshold and stamina.current_stamina >= evade_stamina_cost:
			_perform_evade()
		sprint_hold_timer = 0.0


func _perform_evade() -> void:
	# ── STRONG COOLDOWN CHECK ──
	if Time.get_ticks_msec() < Global.menu_close_cooldown_until:
		sprint_hold_timer = 0.0
		return
	
	# Extra safety - never evade if a menu is open
	if Global.is_in_menu or InputManager.input_blocked:
		sprint_hold_timer = 0.0
		return
	
	if move_direction.length_squared() < 0.01:
		# Backstep
		var back_dir = -last_dir.normalized()
		evade_velocity = back_dir * backstep_distance
		evade_timer = 0.35
		print("[Feature-DEBUG] Backstep triggered")
	else:
		# Dodge Roll
		evade_velocity = move_direction.normalized() * dodge_roll_distance
		evade_timer = 0.5
		print("[Feature-DEBUG] Dodge roll triggered — direction: ", move_direction)
		
		var health = body.get_node_or_null("HealthComponent")
		if health and health.has_method("grant_iframes"):
			health.grant_iframes(0.5)
		
		var anim_comp = body.get_node_or_null("AnimationComponent")
		if anim_comp and anim_comp.has_method("play_roll"):
			anim_comp.play_roll(move_direction)
	
	# Stamina cost for BOTH backstep and dodge roll
	InputManager.input_blocked = true
	stamina.drain(evade_stamina_cost)
