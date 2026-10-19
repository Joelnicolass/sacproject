class_name TargetPolicy
extends Resource

## F136 (RFC-030h2): how a creature whose ranged attack is `tag` chooses and keeps its target, in place of the
## enemy score of TargetPicker (sacengine's special cases of updateTarget, state.d:12940-12958). TargetPicker owns
## the list (`policies`) and asks the one whose tag is the body's ranged attack; a body with none keeps the code it
## had. This base is the default rule: accepts() is what UnitBody accepted before, pick() has no opinion (null).
## A variant is a new script and a .tres (data/targeting/<tag>.tres), never an `if` on the tag.

## SpellTag of the ranged attack (CreatureType.ranged_attack_tag) this policy is for.
@export var tag := ""


## Whether `body` may keep `node` as its target (UnitBody.accepts_target). `ordered`: the body is under an order.
func accepts(body: UnitBody, node: Variant, ordered: bool) -> bool:
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not ordered)


## The target `body` picks by itself around `center` (UnitBody.closest_foe); `within`: the candidates must lie within
## that distance of `center` (a guard's leash). Null: none.
func pick(_body: UnitBody, _center: Vector3, _within: float) -> Node3D:
	return null
