@tool
class_name GuardianAction
extends SpellAction

## Guardian (ndrg): the wizard ties one of his own creatures to a building (RFC-021b). The click is
## the creature (OWN_UNIT). To arm it he needs a standing building of his own (altar, shrine, Manalith)
## within ReachFacts guardian_arm_m on the plane (mustBeNearBuilding, sacengine state.d:29561, 28082); the
## creature has to be free, alive, his and within the cast range. When the casting ends it is tied to
## the open post closest to the CREATURE, whatever the distance (guardian / findClosestBuilding,
## state.d:10398-10414); who sets the bond is GuardianBond. Not the wizard, a hero, a familiar, a Sac
## Doctor, one that is already a guardian (exclusion_tags «ndrg») nor a captive. The beam, the damage
## split and the factors live in GuardianTether, GuardPost and GuardianBond, not here.

const FAR_FROM_BUILDING := Refusal.FAR_FROM_BUILDING

## Numbers of the guardian (arm radius). Obligatory.
@export var rules: MatchRules


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if rules == null:
		warnings.append("Asigná en `rules` el MatchRules (radio para armar el hechizo).")
	return warnings


func arm_status(wizard: WizardBody, _spell: SpellType) -> String:
	if Engine.is_editor_hint() or not is_inside_tree():
		return NOT_IMPLEMENTED
	var radius := ReachFacts.of_rules(rules).guardian_arm_m
	if GuardPost.closest(get_tree(), wizard.owner_slot, wizard.global_position, radius) == null:
		return FAR_FROM_BUILDING
	return ""


## `picked` and `point` come from the client: the creature is validated here and its own position
## is the aim.
func check(wizard: WizardBody, spell: SpellType, _point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	aim.status = arm_status(wizard, spell)
	if not aim.status.is_empty():
		return aim
	if not can_guard(wizard.owner_slot, picked):
		aim.status = BAD_TARGET
		return aim
	aim.target = picked
	aim.point = picked.global_position
	aim.status = standing_status(funds, wizard, spell, aim.point)
	return aim


## The casting ended. The creature may have died or been taken meanwhile (`target` is then null or no
## longer valid) or the building may be gone: the cast is lost.
func finish(wizard: WizardBody, _spell: SpellType, target: Node3D) -> String:
	if not can_guard(wizard.owner_slot, target):
		return BAD_TARGET
	var post := GuardPost.closest(get_tree(), wizard.owner_slot, target.global_position)
	if post == null:
		return FAR_FROM_BUILDING
	var bond := GuardianBond.of(target)
	return "" if bond != null and bond.bind(post) else BAD_TARGET


## A creature of `slot` that can be tied: his, free, alive, not taken, with a bond to tie and none
## in place (sacspell.d:168, state.d:10401-10402, isApplicable sacspell.d:63).
static func can_guard(slot: int, picked: Node3D) -> bool:
	var unit := picked as UnitBody
	if unit == null or not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion():
		return false
	if slot <= 0 or unit.owner_slot != slot or not unit.is_in_group(Captive.UNIT_GROUP):
		return false
	if unit.is_dead() or unit.is_summoning() or unit.is_taken() or unit.is_in_group(GuardianBond.ROOTED):
		return false
	var bond := GuardianBond.of(unit)
	return bond != null and not bond.is_bound()
