@tool
extends Resource
class_name StatusEffect

# Core
@export var id: String = ""
@export var display_name: String = "Unknown Effect"
@export var icon: Texture2D                     # ← Required for all effects (good and bad)
@export var color: Color = Color.WHITE

# Type
@export var is_permanent: bool = false   # Equipment buffs = true, timed/negative = false
@export var is_positive: bool = true            # true = Buff Bar, false = Status Bar
@export var is_mortal: bool = false             # Instadeath

# Build-up & Duration
@export var build_up_required: float = 0.0      # 0 = instant
@export var max_duration: float = 30.0
@export var tick_rate: float = 1.0
@export var tick_value: float = 0.0             # positive = heal, negative = damage
@export var build_up_rate: float = 45.0     # per second while inside source
@export var decay_rate: float = 35.0        # per second while outside


# On full bar (Bleed style)
@export var on_full_damage: float = 0.0
@export var on_full_damage_percent: float = 0.0

# Resistance & Modifiers
@export var resistance_tags: Array[String] = [] # e.g. ["poison"] - rings can reduce this

# Stacking & Cure
@export var max_stacks: int = 1
@export var cure_item_id: String = ""           # e.g. "poison_antidote"

# Visual/Audio
@export var vfx_scene: PackedScene
@export var sound_on_apply: AudioStream

# Future-proofing
@export var tags: Array[String] = []
