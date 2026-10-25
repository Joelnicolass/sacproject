class_name TargetPolicy
extends Resource

## How a creature whose ranged attack is `attack` chooses and keeps its target, in place of the enemy score of
## TargetPicker (the Scarab heals the wounded, a raging body fights anyone). TargetPicker owns
## the list (`policies`) and asks the one whose `attack` is the body's ranged attack; a body with none keeps the code it
## had. This base is the default rule: accepts() is what UnitBody accepted before, pick() has no opinion (null).
## A variant is a new script and a .tres (data/targeting/<name>.tres), never an `if` on the ability.
## Ref: F136 (RFC-030h2), sacengine's special cases of updateTarget (state.d:12940-12958).

## The ranged attack (CreatureType.ranged_attack) this policy is for.
@export var attack: AbilityType


## Whether `body` may keep `node` as its target (UnitBody.accepts_target). `explicit`: `node` is the target of an explicit
## ATTACK order (a click, the AI's port), the one target taken without asking the stance (F370).
func accepts(body: UnitBody, node: Variant, explicit: bool) -> bool:
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not explicit)


## The target `body` picks by itself around `center` (UnitBody.closest_foe); `within`: the candidates must lie within
## that distance of `center` (a guard's leash). Null: none.
func pick(_body: UnitBody, _center: Vector3, _within: float) -> Node3D:
	return null
