class_name DeathRules
extends RefCounted

## What a death turns into, as plain rules: does it leave a soul, does it burst, and what becomes of
## a creature when the doctor that carries it dies. Pure: no nodes, no clock, no dice. The nodes
## (Corpse, Captive, SoulSystem) ask.

## What a creature was to the doctor that lost it.
enum Carried { HELD, REVIVING }
## What happens to it when its doctor dies: it lands alive and stunned, or it dies in the air and
## falls as a corpse.
enum Outcome { LAND_ALIVE, DROP_DEAD }


## A creature that dies leaves `souls` souls on its corpse, unless it burst (it fell into a hole, it
## was gibbed).
static func leaves_soul(souls: int, burst: bool) -> bool:
	return souls > 0 and not burst


## The doctor carrying `kind` died. A body that was being pumped back to life dies again, always. A
## carried one dies when it is dropped only if the match says so (`dies_when_dropped`,
## MatchRules.carried_dies_when_dropped); otherwise it lands alive and stunned. A body that is
## already dead stays dead.
static func on_carrier_lost(kind: Carried, alive: bool, dies_when_dropped: bool) -> Outcome:
	if not alive or kind == Carried.REVIVING:
		return Outcome.DROP_DEAD
	return Outcome.DROP_DEAD if dies_when_dropped else Outcome.LAND_ALIVE
