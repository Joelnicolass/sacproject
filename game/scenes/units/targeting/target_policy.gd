class_name TargetPolicy
extends Resource

## How a creature chooses and keeps its target, in place of the enemy score of TargetPicker (the
## Scarab heals the wounded, a raging body fights anyone). A ranged attack carries its own in
## AbilityType.target_policy; TargetPicker also holds the rage one. This base is the default rule:
## accepts() is what UnitBody accepted before, pick() has no opinion (null). A variant is a new
## script and a .tres in data/targeting/, never an `if` on the ability.


## Whether `body` may keep `node` as its target (UnitBody.accepts_target). `explicit`: `node` is the
## target of an explicit ATTACK order (a click, the AI's port), the one target taken without asking
## the stance.
func accepts(body: UnitBody, node: Variant, explicit: bool) -> bool:
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not explicit)


## The target `body` picks by itself around `center` (UnitBody.closest_foe); `within`: the
## candidates must lie within that distance of `center` (a guard's leash). Null: none.
func pick(_body: UnitBody, _center: Vector3, _within: float) -> Node3D:
	return null
