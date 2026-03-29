# res://scripts/spells/HealScript.gd
extends Node

func cast(caster: Node, spell: GameItem) -> void:
	var health = caster.get_node_or_null("HealthComponent")
	if health:
		health.heal(spell.effect_value if spell.effect_value > 0 else 30.0)
		print("[HealScript] Healed for ", spell.effect_value)
