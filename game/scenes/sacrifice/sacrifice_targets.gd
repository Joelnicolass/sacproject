class_name SacrificeTargets
extends Node

## The questions of the sacrifice, answered on any peer (the owner arms the icon with them, the server decides): which enemy altar is
## closest, which own site a Convert goes to, what can be sacrificed or converted, whether a Desecrate is underway, who the wizard of a slot is.
## What it does not do: write any state, spawn or run a cast.

const NO_ALTAR := Refusal.NO_ALTAR
const FAR_FROM_ALTAR := Refusal.FAR_FROM_ALTAR
const BAD_TARGET := SpellAction.BAD_TARGET

## The system that owns the rules (the altar range) and the world.
@export var system: SacrificeSystem


## The closest standing enemy altar to `from` within `max_range` on the plane, or null. A destroyed or collapsing altar is not there.
## Ref: sacengine closestEnemyAltar, state.d:28083.
func closest_enemy_altar(slot: int, from: Vector3, max_range := INF) -> Altar:
	var best: Altar = null
	var best_d := max_range
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		var altar := node as Altar
		if altar == null or not altar.is_standing() or altar.owner_slot <= 0 or altar.owner_slot == slot:
			continue
		## Only an altar of an enemy (the altar of an ally is not a target of Desecrate). Ref: RFC-049 049c.
		if not SideRelations.is_enemy(slot, altar.owner_slot):
			continue
		var d := Vector2(altar.global_position.x - from.x, altar.global_position.z - from.z).length()
		if d <= best_d:
			best_d = d
			best = altar
	return best


## "" when Desecrate can be armed from `from`, else why not.
## Ref: sacengine mustBeNearEnemyAltar, state.d:29562.
func altar_status(slot: int, from: Vector3) -> String:
	if closest_enemy_altar(slot, from) == null:
		return NO_ALTAR
	if closest_enemy_altar(slot, from, system.active_rules().desecrate_altar_range) == null:
		return FAR_FROM_ALTAR
	return ""


## "" when `picked` can be sacrificed by the wizard of `slot`: one of the caster's own creatures, alive, free and able to be taken.
## Not a wizard, a doctor, an enemy, a corpse or one that is already held. `picked` comes from the client: nothing about it is trusted.
func sacrifice_status(slot: int, picked: Node3D) -> String:
	var unit := picked as UnitBody
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree():
		return BAD_TARGET
	if not unit.is_in_group(Captive.UNIT_GROUP) or unit.owner_slot != slot or slot <= 0:
		return BAD_TARGET
	if unit.is_dead() or unit.is_summoning() or unit.is_held() or Captive.of(unit) == null:
		return BAD_TARGET
	return ""


## The standing ritual site of `slot` closest to `from` on the plane, or null: where a Convert takes the creature. It is the
## site of an altar or of a Shrine, whichever is closer, with no range.
## Ref: sacengine closestShrine, state.d:28060-28095.
func closest_own_site(slot: int, from: Vector3) -> RitualSite:
	var best: RitualSite = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(RitualSite.GROUP):
		var site := node as RitualSite
		if site == null or not site.is_standing() or site.owner_slot() != slot or slot <= 0:
			continue
		var d := Vector2(site.global_position.x - from.x, site.global_position.z - from.z).length()
		if d < best_d:
			best_d = d
			best = site
	return best


## "" when Convert can be armed from `from`: the wizard needs an own altar standing.
## Ref: sacengine mustBeConnectedToConversion, state.d:29563.
func convert_arm_status(slot: int, from: Vector3) -> String:
	return "" if closest_own_site(slot, from) != null else NO_ALTAR


## "" when `picked` is a soul the wizard of `slot` can convert: red for him, in the open, on the corpse of a creature that can be
## revived and that no doctor of his is already coming for. `picked` comes from the client.
func convert_status(slot: int, picked: Node3D) -> String:
	var soul := picked as Soul
	if soul == null or not is_instance_valid(soul) or not soul.is_inside_tree() or slot <= 0:
		return BAD_TARGET
	if not soul.can_convert_by(slot):
		return BAD_TARGET
	var corpse := soul.corpse as UnitBody
	if corpse == null or not is_instance_valid(corpse) or not corpse.is_inside_tree() or not corpse.is_dead():
		return BAD_TARGET
	if corpse.owner_slot == slot or Captive.of(corpse) == null:
		return BAD_TARGET
	return ""


## Is a Desecrate underway against the altars of `altar_slot` (0 = any) cast by `caster_slot` (0 = any): a wizard casting it (one of
## `casting`, the casts the caller holds), a carrier on its way or a ritual running. The AI reads it to guard its altar, to leave a
## target alone and to stop claiming creatures.
## Ref: sacengine desecrationOngoing, shiny.d:3079 over the `sacDocCastings`; RFC-024 024d.
func desecration_matches(altar_slot: int, caster_slot: int, casting: Array[SacrificeSystem.Cast]) -> bool:
	for cast in casting:
		if cast.site != null and is_instance_valid(cast.site) \
				and (altar_slot <= 0 or cast.site.owner_slot() == altar_slot) and (caster_slot <= 0 or cast.caster_slot == caster_slot):
			return true
	for node in get_tree().get_nodes_in_group(DoctorBody.GROUP):
		var errand := node.get_node_or_null("Errand") as CarryErrand
		if errand == null or errand.kind != Ritual.Kind.DESECRATE or errand.site == null or not is_instance_valid(errand.site):
			continue
		if (altar_slot <= 0 or errand.site.owner_slot() == altar_slot) and (caster_slot <= 0 or errand.caster_slot == caster_slot):
			return true
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		var ritual := node as Ritual
		if ritual != null and ritual.kind == Ritual.Kind.DESECRATE and ritual.outcome == Ritual.Outcome.RUNNING \
				and (altar_slot <= 0 or ritual.target_slot == altar_slot) and (caster_slot <= 0 or ritual.caster_slot == caster_slot):
			return true
	return false


## The wizard of that slot in this world, or null.
func wizard_of(slot: int) -> WizardBody:
	for node in get_tree().get_nodes_in_group("wizard"):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == slot and (system.world == null or system.world.is_ancestor_of(wizard)):
			return wizard
	return null
