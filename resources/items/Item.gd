# res://resources/items/Item.gd
@tool
extends Resource
class_name GameItem

# ─────────────────────────────────────────────────────────────
# CORE / GENERAL
# ─────────────────────────────────────────────────────────────
@export var id: String = ""
@export var display_name: String = "Unknown Item"
@export var description: String = ""
@export var quantity: int = 1
@export var icon: Texture2D
@export var category: String = "Consumables"
@export var max_stack: int = 99
@export var weight: float = 0.0
@export var rarity: int = 1
@export var value: int = 0 # souls when sold / vendor price

# Consumption behavior
@export var consumes_on_use: bool = true
@export var is_consumable: bool = false

# ─────────────────────────────────────────────────────────────
# ARMOR SPECIFIC
# ─────────────────────────────────────────────────────────────
@export_enum("Head", "Body", "Arms", "Legs") var armor_slot: String = ""

# ─────────────────────────────────────────────────────────────
# SPELL SPECIFIC (NEW - Step 7)
# ─────────────────────────────────────────────────────────────
@export_enum("Sorcery", "Miracle", "Pyromancy", "Hex", "Other") var spell_type: String = "Sorcery"
@export var mana_cost: int = 0
@export var attunement_slots: int = 1
@export var cast_time: float = 0.0
@export var cooldown: float = 0.0

# NEW FIELDS FOR SPELL CASTER
@export var spell_vfx_scene: PackedScene
@export var spell_projectile_scene: PackedScene   # reuses ProjectileSpawner for projectiles
@export var spell_effect_script: Script           # optional GDScript for complex logic (heal over time, AoE, etc.)
@export var status_effect_to_apply: String = ""   # e.g. "Poison", "Fire", "Bleed"

# ─────────────────────────────────────────────────────────────
# WEAPON SPECIFIC
# ─────────────────────────────────────────────────────────────
@export_enum(
	"Straight Sword", "Greatsword", "Ultra Greatsword",
	"Curved Sword", "Katana", "Thrusting Sword",
	"Axe", "Hammer", "Spear", "Bow", "Heretical",
	"Staff", "Chime", "Fist", "Other"
) var weapon_type: String = "Straight Sword"
@export var damage: int = 0
@export var scaling: String = ""
@export var requirements: Dictionary = {}

# ─────────────────────────────────────────────────────────────
# CONSUMABLE / QUICK-USE EFFECT SYSTEM
# ─────────────────────────────────────────────────────────────
@export_enum("None", "Heal", "Damage", "Teleport", "Buff", "StatusClear", "Cast") var effect_type: String = "None"
@export var effect_value: float = 0.0
@export var duration: float = 0.0
@export var stamina_cost: float = 0.0
@export var requires_confirmation: bool = false
@export var requires_quantity: bool = false
@export var special_component_ref: String = ""

# ─────────────────────────────────────────────────────────────
# PROJECTILE / RANGED
# ─────────────────────────────────────────────────────────────
@export_enum("Straight", "Arc", "Homing", "Instant") var trajectory_type: String = "Straight"
@export var speed: float = 600.0
@export var lifetime: float = 5.0
@export var gravity: float = 0.0
@export var max_range: float = 0.0
@export var explosion_scene: PackedScene
@export var piercing: bool = false
@export var bounce_count: int = 0
@export var projectile_sprite: Texture2D
@export var projectile_trail_vfx: PackedScene
# ─────────────────────────────────────────────────────────────
# STATUS EFFECTS & BUFFS
# ─────────────────────────────────────────────────────────────
@export var status_effects: Array[Dictionary] = []

# ─────────────────────────────────────────────────────────────
# VFX / ANIMATION / AUDIO HOOKS
# ─────────────────────────────────────────────────────────────
@export var use_vfx_scene: PackedScene
@export var use_sound: AudioStream
@export var use_animation_name: String = ""

# ─────────────────────────────────────────────────────────────
# FUTURE / DLC / ORGANIZATION
# ─────────────────────────────────────────────────────────────
@export var tags: Array[String] = []
@export var ammo_type: String = ""
@export var quantity_per_use: int = 1
