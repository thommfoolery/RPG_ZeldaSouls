# res://resources/items/Item.gd
@tool
extends Resource
class_name GameItem

@export var id: String = ""
@export var display_name: String = "Unknown Item"
@export var description: String = ""
@export var quantity: int = 1
@export var icon: Texture2D
@export var category: String = "Consumables"

# Armor specific
@export_enum("Head", "Body", "Arms", "Legs") var armor_slot: String = ""

# Spell specific
@export_enum("Sorcery", "Miracle", "Pyromancy", "Hex", "Incantation", "Other") var spell_type: String = "Sorcery"
@export var mana_cost: int = 0
@export var attunement_slots: int = 1
@export var cast_time: float = 0.0
@export var cooldown: float = 0.0

# Weapon specific
@export_enum(
	"Straight Sword", 
	"Greatsword", 
	"Ultra Greatsword", 
	"Curved Sword", 
	"Katana", 
	"Thrusting Sword", 
	"Axe", 
	"Hammer", 
	" Spear", 
	"Bow", 
	"Crossbow", 
	"Staff", 
	"Chime", 
	"Fist", 
	"Other"
) var weapon_type: String = "Straight Sword"

@export var damage: int = 0
@export var scaling: String = ""                    # e.g. "STR B / DEX C"
@export var requirements: Dictionary = {}           # e.g. {"STR": 12, "DEX": 8}

# Consumable / Utility specific
@export_enum("Heal", "Buff", "StatusRemove", "Teleport", "Souls", "Other") var effect_type: String = ""
@export var effect_value: float = 0.0
@export var duration: float = 0.0

# General
@export var max_stack: int = 99
@export var weight: float = 0.0
@export var rarity: int = 1
@export var is_consumable: bool = false

# Ammo specific
@export var ammo_type: String = ""
@export var quantity_per_use: int = 1
