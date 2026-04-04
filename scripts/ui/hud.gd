# ui/hud.gd
extends CanvasLayer

# ─── Existing nodes ─────────────────────────────────────────────────
@onready var souls_label: Label = %SoulsLabel
@onready var estus_label: Label = %EstusLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var saving_icon: Control = $SavingIcon
@onready var saving_label: Label = $SavingIcon/Label
@onready var mana_bar: ProgressBar = %ManaBar

# Reference to the Cross
@onready var cross_hud: CrossHUD = $QuickUseCross

# ─── Component references ───────────────────────────────────────────
var stamina_component: StaminaComponent
var health_component: HealthComponent

func _ready() -> void:
	print("[HUD] _ready() | Instance:", get_instance_id(), " | Path:", get_path())
	await get_tree().process_frame
	_connect_to_player_manager()
	saving_icon.visible = false
	saving_icon.modulate.a = 0.0
	_update_all_cross_slots()


func _connect_to_player_manager() -> void:
	if PlayerManager:
		if not PlayerManager.player_changed.is_connected(_on_player_changed):
			PlayerManager.player_changed.connect(_on_player_changed)
		
		if PlayerManager.current_player and is_instance_valid(PlayerManager.current_player):
			_connect_to_current_player()
	else:
		push_warning("[HUD] PlayerManager autoload not found!")


func _on_player_changed(new_player: Node) -> void:
	print("[HUD] Player changed signal received — reconnecting")
	_connect_to_current_player()


func _connect_to_current_player() -> void:
	var player = PlayerManager.current_player
	if not player or not is_instance_valid(player):
		print("[HUD] No valid current player — skipping")
		return

	# Safe disconnect old components
	if health_component and is_instance_valid(health_component) and health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.disconnect(_on_health_changed)
	if stamina_component and is_instance_valid(stamina_component) and stamina_component.stamina_changed.is_connected(_on_stamina_changed):
		stamina_component.stamina_changed.disconnect(_on_stamina_changed)

	health_component = null
	stamina_component = null

	health_component = player.get_node_or_null("HealthComponent")
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		_update_health_bar()
	else:
		push_warning("[HUD] HealthComponent not found")

	stamina_component = player.get_node_or_null("StaminaComponent")
	if stamina_component:
		stamina_component.stamina_changed.connect(_on_stamina_changed)
		_update_stamina_bar()
	else:
		push_warning("[HUD] StaminaComponent not found")

	var mana_component = player.get_node_or_null("ManaComponent")
	if mana_component:
		mana_component.mana_changed.connect(_on_mana_changed)
		_on_mana_changed(mana_component.current_mana, mana_component.max_mana)
	else:
		push_warning("[HUD] ManaComponent not found on player")

	# ── Reliable Souls connection ─────────────────────────────────────
	if PlayerStats:
		if not PlayerStats.souls_changed.is_connected(_on_souls_changed):
			PlayerStats.souls_changed.connect(_on_souls_changed)
			print("[HUD] Connected to PlayerStats.souls_changed")
		
		_update_souls()   # Force immediate update on connect

	if PlayerStats:
		if not PlayerStats.estus_changed.is_connected(_on_estus_changed):
			PlayerStats.estus_changed.connect(_on_estus_changed)
		_update_estus()

	if PlayerStats:
		if not PlayerStats.attunement_changed.is_connected(_on_attunement_changed):
			PlayerStats.attunement_changed.connect(_on_attunement_changed)

	print("[HUD] Successfully (re)connected to current player and all signals")
	_update_all_cross_slots()


# ─── Signal handlers ────────────────────────────────────────────────
func _on_attunement_changed() -> void:
	cross_hud.refresh()

func _on_equipped_changed(slot_index: int, _new_item: GameItem) -> void:
	cross_hud.refresh()

func _update_all_cross_slots() -> void:
	cross_hud.refresh()

# ─── Player stat / bar updates ─────────────────────────────────────
func _on_health_changed(current: float, max_health: float) -> void:
	_update_health_bar()

func _update_health_bar() -> void:
	if not health_bar: return
	if health_component:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.current_health
		print("[HUD] Health bar updated → ", health_bar.value, "/", health_bar.max_value)
	else:
		health_bar.value = 200.0

func _on_stamina_changed(current: float, max_stamina: float) -> void:
	_update_stamina_bar()

func _update_stamina_bar() -> void:
	if not stamina_bar: return
	if stamina_component:
		stamina_bar.max_value = stamina_component.max_stamina
		stamina_bar.value = stamina_component.current_stamina
	else:
		stamina_bar.value = 100.0

func _on_mana_changed(current: float, max_mana: float) -> void:
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current

func _on_souls_changed(_new: int) -> void:
	_update_souls()

func _update_souls() -> void:
	if souls_label and PlayerStats:
		souls_label.text = "Souls: %d" % PlayerStats.souls_carried
		souls_label.queue_redraw()          # Force visual refresh
		print("[HUD] Souls label updated to ", PlayerStats.souls_carried)
	else:
		print("[HUD] Souls label or PlayerStats not ready")

func _on_estus_changed(_new: int) -> void:
	_update_estus()

func _update_estus() -> void:
	if not estus_label or not PlayerStats: return
	estus_label.text = "%d/%d" % [PlayerStats.estus_charges, PlayerStats.max_estus]
	if PlayerStats.estus_charges >= PlayerStats.max_estus:
		estus_label.modulate = Color(1.0, 0.665, 0.161, 1.0)
	elif PlayerStats.estus_charges > 0:
		estus_label.modulate = Color(0.95, 0.95, 1.0)
	else:
		estus_label.modulate = Color(0.537, 0.0, 0.082, 1.0)

func show_saving_icon() -> void:
	if not saving_icon: return
	saving_icon.visible = true
	saving_label.text = "Saving..."
	var tween = create_tween()
	tween.tween_property(saving_icon, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(1.4).timeout
	tween = create_tween()
	tween.tween_property(saving_icon, "modulate:a", 0.0, 0.3)
	await tween.finished
	saving_icon.visible = false
