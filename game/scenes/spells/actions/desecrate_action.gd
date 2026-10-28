@tool
class_name DesecrateAction
extends SpellAction

## Desecrate (ucas): the wizard sacrifices one of his own creatures to profane the closest enemy altar.
## The click is the creature (OWN_UNIT). It needs a standing enemy altar within rules.desecrate_altar_range
## of the wizard; the creature must be his own, alive and within the cast range. The red vortex opens when
## the casting starts; when it ends, a carrier doctor drops by the creature, lifts it and takes it to the
## altar. If the cast is interrupted there is no doctor and the creature stays free. All the rules live
## in SacrificeSystem; this action is only the
## contract with the Caster. The ritual itself is Ritual.Kind.DESECRATE.

var _system: SacrificeSystem
var _cast: SacrificeSystem.Cast


func arm_status(wizard: WizardBody, _spell: SpellType) -> String:
	var system := _find_system()
	if system == null:
		return NOT_IMPLEMENTED
	return system.altar_status(wizard.owner_slot, wizard.global_position)


## `picked` and `point` come from the client: the creature is validated here and its own position
## is the aim.
func check(wizard: WizardBody, spell: SpellType, _point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	var system := _find_system()
	if system == null:
		aim.status = NOT_IMPLEMENTED
		return aim
	aim.status = system.altar_status(wizard.owner_slot, wizard.global_position)
	if not aim.status.is_empty():
		return aim
	aim.status = system.sacrifice_status(wizard.owner_slot, picked)
	if not aim.status.is_empty():
		return aim
	aim.target = picked
	aim.point = picked.global_position
	aim.status = standing_status(funds, wizard, spell, aim.point)
	return aim


func begin(wizard: WizardBody, spell: SpellType, aim: Aim) -> void:
	cancel()
	var system := _find_system()
	if system == null:
		return
	_cast = system.begin_cast(wizard, aim.target as UnitBody, CastTime.seconds(spell, wizard.level))


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	var cast := _cast
	_cast = null
	var system := _find_system()
	if cast == null or system == null:
		return BAD_TARGET
	# The creature died during the cast: `target` is null and the cast keeps the freed reference.
	return system.finish_cast(cast)


func cancel() -> void:
	var cast := _cast
	_cast = null
	var system := _find_system()
	if cast != null and system != null:
		system.cancel_cast(cast)


func _find_system() -> SacrificeSystem:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	if _system == null or not is_instance_valid(_system):
		_system = get_tree().get_first_node_in_group(SacrificeSystem.GROUP) as SacrificeSystem
	return _system
