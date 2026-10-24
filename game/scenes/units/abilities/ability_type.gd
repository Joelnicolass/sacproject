class_name AbilityType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var mana_cost: int = 0
## How far from the caster it can be cast (m).
@export var cast_range_m: float = 0.0
@export var cooldown_s: float = 0.0
@export var casting_time_s: float = 0.0
## Speed of what it sends (m/s).
@export var speed_m_s: float = 0.0
## Acceleration of what it sends (m/s²).
@export var acceleration_m_s2: float = 0.0
@export var damage: int = 0
## SPEL `amount2` (u32 at 96): what the AI's rater reads of an ability (shiny.d:175-180 `abilityAcc`).
@export var amount2: int = 0
## Radius of its damage around where it hits (m).
@export var damage_range_m: float = 0.0
## Reach of its effect (m).
@export var effect_range_m: float = 0.0
## How long its effect lasts (s).
@export var duration_s: float = 0.0
@export var flags: int = 0
@export var flags1: int = 0
@export var flags2: int = 0
## SPEL args (spells.d Spel.args, as sacspell.d spellArgInt / spellArgFloat): `ires` and `freg` of poison, `ttex` of a
## particle… Read with the default sacengine passes (SacSpell.spellArgInt("ires", 0)).
@export var args: Dictionary = {}


func arg_int(key: String, fallback := 0) -> int:
	return int(args.get(key, fallback))


func arg_float(key: String, fallback := 0.0) -> float:
	return float(args.get(key, fallback))
