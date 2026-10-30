@tool
class_name DamageModifier
extends Node

## Something on a body that changes the hits it takes or what it heals: a building's guardians, the
## devoured souls, the poison, the states and the oil, the wards, a creature's passive. Health holds
## them in its ordered `modifiers` list and asks every one at each stage of a hit; it never knows
## which kind it is. Every hook here is neutral, so a modifier overrides only the stages it changes.
## Not: the side rule (friendly fire), which is the match's and stays in Health.
##
## The stages, in the order Health runs them (see Health.damage_typed):
##   1. blocks_damage()   any true: the body takes nothing (Ethereal Form)
##   2. deflect()         the first that does not return NAN takes the whole hit instead of the body
##   3. resistance_factor() × base resistance, then + resistance_bonus(), inside max(0, …)
##   4. shield_factor()   × typed hits, skipped by pierce_shield (wards)
##   5. state_factor()    × both paths, skipped by pierce_shield (petrified)
##   6. incoming_factor() × both paths, from the health before the hit (Taurock's hide)
##   7. final_factor()    × typed hits, last (an IGNITE hit on oil)
## regeneration_factor() multiplies what the body heals by itself.


## True while the body cannot be hurt at all, whatever the hit pierces.
func blocks_damage() -> bool:
	return false


## Takes the whole hit in place of the body: the damage really taken by those who stood in, or NAN
## if nobody did. `amount` is the raw damage, before the body's resistance. Asked only where Health
## has authority, never again from inside a deflection.
func deflect(_amount: float, _kind: StringName, _from_slot: int) -> float:
	return NAN


## Multiplies the body's base resistance to every kind (1 = unchanged).
func resistance_factor() -> float:
	return 1.0


## Added to the resistance inside max(0, resistance + bonus) for every kind (0 = unchanged).
func resistance_bonus() -> float:
	return 0.0


## Multiplies a typed hit of `kind` (1 = unchanged). A pierce_shield hit skips it.
func shield_factor(_kind: StringName) -> float:
	return 1.0


## Multiplies every hit, on both paths (1 = unchanged). A pierce_shield hit skips it.
func state_factor() -> float:
	return 1.0


## Multiplies every hit from the body's relative health before it (`health_fraction`), the hit's
## `mods` bits, the damage that reached this stage (`before`) and whether the attacker is of the
## body's side (`ally`). 1 = unchanged.
func incoming_factor(_health_fraction: float, _mods: int, _before: float, _ally: bool) -> float:
	return 1.0


## Multiplies a typed hit after every other stage, given its `mods` bits (1 = unchanged). It may
## change the modifier (the oil lights up), so Health asks it once per hit that reaches the body.
func final_factor(_mods: int) -> float:
	return 1.0


## Multiplies what the body regenerates by itself (1 = unchanged, 0 = none). Health clamps it at 0.
func regeneration_factor() -> float:
	return 1.0
