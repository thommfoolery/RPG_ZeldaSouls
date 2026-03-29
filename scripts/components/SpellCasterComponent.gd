# scripts/components/SpellCasterComponent.gd
extends Node
class_name SpellCasterComponent

@onready var player = get_parent() as CharacterBody2D
var cross_hud: CrossHUD = null

signal spell_cast_started(spell: GameItem)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	cross_hud = get_tree().get_first_node_in_group("cross_hud") as CrossHUD
	if not cross_hud:
		push_error("[SpellCaster] Could not find CrossHUD in group 'cross_hud'")

	if InputManager:
		InputManager.right_hand_primary.connect(_on_right_primary)
		InputManager.left_hand_primary.connect(_on_left_primary)
		print("[SpellCaster] Connected to RB/LB for casting")

func _on_right_primary() -> void:
	_try_cast_from_hand(cross_hud.active_right_index)

func _on_left_primary() -> void:
	_try_cast_from_hand(cross_hud.active_left_index)

func _try_cast_from_hand(active_slot: int) -> void:
	if Global.is_death_respawn or Global.is_in_menu or not player:
		return

	var casting_tool = EquipmentManager.get_equipped_item(active_slot)
	if not casting_tool or not _is_valid_casting_tool(casting_tool):
		return

	var spell = cross_hud.get_current_attunement_spell()
	if not spell or spell.effect_type != "Cast":
		return

	_cast_spell(spell, active_slot)

func _is_valid_casting_tool(tool_item: GameItem) -> bool:
	if not tool_item: return false
	var spell = cross_hud.get_current_attunement_spell()
	if not spell: return false
	
	if tool_item.weapon_type == "Staff" and spell.spell_type in ["Sorcery", "Pyromancy", "Hex"]:
		return true
	if tool_item.weapon_type == "Chime" and spell.spell_type in ["Miracle", "Incantation"]:
		return true
	if tool_item.weapon_type == "Heretical":
		return true
	return false

func _cast_spell(spell: GameItem, active_slot: int) -> void:
	# Drain mana
	var mana_comp = player.get_node_or_null("ManaComponent")
	if mana_comp:
		if not mana_comp.drain(spell.mana_cost):
			print("[SpellCaster] Not enough mana for ", spell.display_name)
			return

	# Emit signal for animation hook later
	spell_cast_started.emit(spell)

	# ─── VFX PLACEHOLDER (temporary flash at casting hand) ───
	if spell.spell_vfx_scene:
		var vfx = spell.spell_vfx_scene.instantiate()
		get_tree().current_scene.add_child(vfx)
		
		# Spawn at the active casting hand
		var hand_offset := Vector2(5, -5) if active_slot <= 1 else Vector2(-5, -5)
		vfx.global_position = player.global_position + hand_offset
		
		# Auto-cleanup after 0.6 seconds (feels like a spell flash)
		var timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = true
		timer.timeout.connect(vfx.queue_free)
		add_child(timer)
		timer.start()
		
		print("[SpellCaster] Spawned temporary VFX for ", spell.display_name)

	# Projectile spell? (Fireball, Ice Spike, etc.)
	if spell.spell_projectile_scene and ProjectileSpawner:
		var dir: Vector2 = Vector2.RIGHT
		if player.has_method("get_last_facing_direction"):
			dir = player.get_last_facing_direction()
		elif player and "last_dir" in player and player.last_dir != Vector2.ZERO:
			dir = player.last_dir.normalized()
		elif player and "last_nonzero_dir" in player:
			dir = player.last_nonzero_dir
		elif player:
			dir = Vector2.RIGHT if player.scale.x > 0 else Vector2.LEFT

		var spawn_offset: Vector2 = Vector2(1, -1) * dir * -2
		var spawn_pos: Vector2 = player.global_position + spawn_offset

		ProjectileSpawner.spawn_projectile(spell, spawn_pos, dir)
		print("[SpellCaster] Launched projectile spell: ", spell.display_name)

	# Optional complex script for special behavior
	if spell.spell_effect_script:
		var script_instance = spell.spell_effect_script.new()
		script_instance.cast(player, spell)

	print("[SpellCaster] Cast spell: ", spell.display_name)
