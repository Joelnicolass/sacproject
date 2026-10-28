class_name SpellType
extends BookEntry

## What the AI wants a spell for. Saved as an integer: only append at the end.
## SELF_GUARD: a ward on himself. DISABLE_FOE: a control spell on a foe. HIT_ONE / HIT_AREA: damage
## on one body or on a group.
## HEAL / SPEEDUP: help for an own body. CONVERT / DESECRATE: the spells of the altar, the brain
## casts them in their own phases.
## SELF_AREA: a burst around himself while foes stand near (Halo). TAKE_FOE: an enemy creature
## becomes his (Charm).
## RAISE_DEAD: an own corpse stands up again (Animate Dead). GATHER_SOULS: a soul he would not walk
## to is brought to him (Soul Wind, Soul Mole). ESCAPE: away to an own building when the threat is
## high (Teleport). GUARD_SITE: an own creature is tied to a threatened building (Guardian).
## HEAL_AREA: health back to the own bodies around the target (Rainbow, Healing Aura).
enum AiUse {
	NONE,
	SELF_GUARD,
	DISABLE_FOE,
	HIT_ONE,
	HIT_AREA,
	HEAL,
	SPEEDUP,
	CONVERT,
	DESECRATE,
	SELF_AREA,
	TAKE_FOE,
	RAISE_DEAD,
	GATHER_SOULS,
	ESCAPE,
	GUARD_SITE,
	HEAL_AREA
}
## When the wizard of the AI may cast it: against a foe (ATTACK), for his own side (SUPPORT) or
## never on his own (NEVER).
## Saved as an integer: only append at the end.
enum AiPhase { NEVER, ATTACK, SUPPORT }

## How far from the caster it can be cast (m).
@export var cast_range_m: float = 0.0
## Wizard level it is meant for (0 to 9): casting it with a lower-level wizard is slower, with a
## higher one faster (CastTime).
@export_range(0, 9) var book_level := 0
## Place in the book among the entries of its level (0 to 99); the book lists entries by level, then
## by this number.
@export_range(0, 99) var book_slot := 0
## Speed of what it sends (m/s).
@export var speed_m_s: float = 0.0
## Acceleration of what it sends (m/s²).
@export var acceleration_m_s2: float = 0.0
@export var damage: int = 0
## Radius of its damage around where it hits (m).
@export var damage_range_m: float = 0.0
## Reach of its effect (m).
@export var effect_range_m: float = 0.0
## How long its effect lasts (s).
@export var duration_s: float = 0.0
@export var is_structure: bool = false
## Scene of the SpellAction that casts this spell. Caster instances it under its `actions` node the
## first time the spell is asked for and sets its `spell`, so a new spell is a `.tres` plus a scene,
## with no edit in Caster.
@export var action: PackedScene
@export_group("AI: who it may land on")
## Nothing ticked = anything. Ticks widen it to those kinds of body; a body of another kind is not a
## target for the AI.
@export var targets_wizards := false
@export var targets_souls := false
@export var targets_creatures := false
@export var targets_corpses := false
@export var targets_structures := false
## Only a free manafount (the spell that builds a Shrine).
@export var only_free_manafounts := false
@export var only_allies := false
@export var never_allies := false
@export var targets_ground := false
@export_group("AI")
## What the wizard of the AI casts it for (see AiUse).
@export var ai_use := AiUse.NONE
@export var ai_phase := AiPhase.NEVER
## The AI casts it only on the wizard himself (Halo of Earth, the wards).
@export var ai_only_on_self := false
## How much health the AI counts this spell takes from a body (Rock: 650). Not the damage it really
## does.
@export var ai_worth := 0
@export_group("")
## How many bodies it takes before it is over (Death: 8). 0 = not limited.
@export var max_targets := 0


## Where the book lists it: by level first, then by position (level * 100 + position).
func order_key() -> int:
	return book_level * 100 + book_slot
