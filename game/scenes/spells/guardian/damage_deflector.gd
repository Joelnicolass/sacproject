@tool
class_name DamageDeflector
extends Node

## Contract of a node that can take a hit in place of the body whose `Health.deflector` points at it.
## Health asks once per hit, only where it has authority. This base never deflects: a
## building's guardians (GuardPost) are the first user.


## `amount` is the raw damage, before the body's resistance. Returns the damage really taken by
## those who stood in, or NAN if nobody did (Health then applies the hit to its own body).
func deflect(_amount: float, _kind: StringName, _from_slot: int) -> float:
	return NAN
