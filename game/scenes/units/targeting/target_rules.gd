class_name TargetRules
extends RefCounted

## Who a body of a player may fight. TargetPicker, SideVision and UnitBody share it, so what is visible and what is
## attackable never drift apart.


## Whether `node` is a creature, wizard or structure that a body of player `slot` may fight (`me` is that
## body, never its own foe).
## `by_stance`: also ask SideRelations (the SIDS of the map) whether the body's side is an enemy of `slot`. Only the target
## of an explicit ATTACK order is asked without it (UnitBody.accepts_target, F370).
static func is_valid_foe_of(slot: int, node: Variant, me: Node = null, by_stance := true) -> bool:
	if node == null or not is_instance_valid(node) or node == me or not node is Node3D:
		return false
	var other := node as Node3D
	if not other.is_inside_tree() or other.is_in_group("corpse") or not "owner_slot" in other:
		return false
	if other is UnitBody and (other as UnitBody).is_summoning():
		return false
	## sacengine isVisibleToAI (state.d:93): a rock is not a target.
	if other is UnitBody and (other as UnitBody).is_rock_form():
		return false
	## sacengine isValidAttackTarget (state.d:138): not a dying or ghost wizard.
	if other.has_method("is_targetable") and not other.call("is_targetable"):  # dynamic: unit, wizard, structure and doctor bodies answer it
		return false
	var other_slot := int(other.get("owner_slot"))
	if other_slot == slot:
		return false
	if by_stance and not SideRelations.is_enemy(slot, other_slot):
		return false
	## sacengine isValidAttackTarget / canDamage (state.d:12426-12432, 9091): a body of health 0 (a gravestone, a fence) can
	## not be damaged, so it is no foe, by stance or not (F370). Shots still hit it: that is physics.
	var health := other.get_node_or_null("Health") as Health
	return health != null and health.maximum > 0.0 and not health.is_dead()


## The closest foe of `body` within its sight range of `center`, over the groups it targets (a body with no TargetPicker).
static func closest_in_sight(body: UnitBody, center: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := body.sight_range()
	for group in body.target_groups:
		for node in body.get_tree().get_nodes_in_group(group):
			if not body.accepts_target(node):
				continue
			var at: Vector3 = node.global_position
			var d := Vector2(at.x - center.x, at.z - center.z).length()
			if d <= best_d:
				best_d = d
				best = node
	return best
