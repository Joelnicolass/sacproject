class_name SpellType
extends Resource

## What the AI wants a spell for (AiSpellEval reads it before the old flag bits).
enum AiUse { NONE, SELF_GUARD, DISABLE_FOE }

@export var tag: String = ""
@export var display_name: String = ""
@export var mana_cost: int = 0
## How far from the caster it can be cast (m).
@export var cast_range_m: float = 0.0
@export var cooldown_s: float = 0.0
@export var casting_time_s: float = 0.0
@export var spell_order: int = 0
## Speed of what it sends (m/s).
@export var speed_m_s: float = 0.0
## Acceleration of what it sends (m/s²).
@export var acceleration_m_s2: float = 0.0
@export var damage: int = 0
## SPEL `amount2` (u32 at 96): the AI's spell evaluators read it (shiny.d:2650-2690).
@export var amount2: int = 0
## SPEL `amount3` (u32 at 100): how many hits, kills or targets a spell takes (Death: 8). 0 = not written in the .tres (the SPEL says 1 for most).
@export var count: int = 0
## Radius of its damage around where it hits (m).
@export var damage_range_m: float = 0.0
## Reach of its effect (m).
@export var effect_range_m: float = 0.0
## How long its effect lasts (s).
@export var duration_s: float = 0.0
@export var flags: int = 0
@export var flags1: int = 0
@export var flags2: int = 0
@export var is_structure: bool = false
## Scene of the SpellAction that casts this spell (RFC-041). Caster instances it under its `actions` node when the wizard
## has no child for the tag, so a new spell is a `.tres` plus a scene, with no edit in Caster.
@export var action: PackedScene
## What the wizard of the AI casts it for. SELF_GUARD: on himself when foes are near and the ward is off. DISABLE_FOE: on the enemy whose
## being held is worth the most (Freeze, Grasping Vines, Rings of Fire, Slime).
@export var ai_use := AiUse.NONE
