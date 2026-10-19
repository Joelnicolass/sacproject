@tool
class_name ConvertAction
extends SpellAction

## Convert (ccas): the wizard steals the souls of a dead enemy creature. The click is a red soul within the
## cast range (SOUL); he needs an own altar standing. The red vortex opens past the soul when the casting
## starts; when it ends a carrier doctor drops by the corpse, pumps it back to life and takes it to the
## own altar closest to the wizard, where a ritual of Convert turns it into souls for him. If the cast is
## interrupted there is no doctor and the soul stays red and convertible. All the rules live in
## SacrificeSystem (sacengine castConvert, state.d:10181-10196); this action is only the contract with
## the Caster (RFC-021a). The ritual itself is Ritual.Kind.CONVERT (RFC-020e).

var _system: SacrificeSystem
var _cast: SacrificeSystem.Cast


func arm_status(wizard: WizardBody, _spell: SpellType) -> String:
	var system := _find_system()
	if system == null:
		return NOT_IMPLEMENTED
	return system.convert_arm_status(wizard.owner_slot, wizard.global_position)


## `picked` and `point` come from the client: the soul is validated here and its own position is the aim.
func check(wizard: WizardBody, spell: SpellType, _point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.target = wizard
	var system := _find_system()
	if system == null:
		aim.status = NOT_IMPLEMENTED
		return aim
	aim.status = system.convert_arm_status(wizard.owner_slot, wizard.global_position)
	if not aim.status.is_empty():
		return aim
	aim.status = system.convert_status(wizard.owner_slot, picked)
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
	_cast = system.begin_convert_cast(wizard, aim.target as Soul, CastTime.seconds(spell, wizard.level))


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	var cast := _cast
	_cast = null
	var system := _find_system()
	if cast == null or system == null:
		return BAD_TARGET
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
