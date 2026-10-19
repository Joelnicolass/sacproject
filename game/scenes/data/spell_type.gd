class_name SpellType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var mana_cost: int = 0
@export var cast_range: float = 0.0
@export var cooldown_s: float = 0.0
@export var casting_time_s: float = 0.0
@export var spell_order: int = 0
@export var speed: float = 0.0
@export var acceleration: float = 0.0
@export var damage: int = 0
## SPEL `amount2` (u32 at 96): the AI's spell evaluators read it (shiny.d:2650-2690).
@export var amount2: int = 0
@export var damage_range: float = 0.0
@export var effect_range: float = 0.0
@export var duration: float = 0.0
@export var flags: int = 0
@export var flags1: int = 0
@export var flags2: int = 0
@export var is_structure: bool = false
## Structure model tags by god order (persephone, pyro, james, stratos, charnel).
@export var structures: PackedStringArray = PackedStringArray()
## Scene of the SpellAction that casts this spell (RFC-041). Caster instances it under its `actions` node when the wizard
## has no child for the tag, so a new spell is a `.tres` plus a scene, with no edit in Caster.
@export var action: PackedScene
