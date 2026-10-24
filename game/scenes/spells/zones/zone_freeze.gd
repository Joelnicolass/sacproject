class_name ZoneFreeze
extends ZonePulse

## What an ice zone does while it grows: every body on the ground that the ice reaches and that is not an ally freezes, once each, with the
## numbers of Freeze. A flier, the wizard that cast it and a body that crowd control cannot touch (shielded, already held) are left alone.
## It does not freeze by itself (Frozen does) nor draw the ice (the zone's look).
## Ref: sacengine updateFrozenGround (state.d:19831-19860).

## The spell whose duration and thaw damage the freeze uses (Freeze).
@export var freeze_spell: SpellType

var _taken := {}


func _fire(_step: int) -> void:
	var center := zone.points[0]
	var reach := zone.grown_m(zone.spell.effect_range)
	for body in bodies_near(center, reach + CANDIDATE_MARGIN_M):
		var frozen := Frozen.of(body)
		if frozen == null or not _applies(body) or ZoneRules.flat_gap(BodyNudge.box(body), center) > reach:
			continue
		if _taken.has(body.get_instance_id()):
			continue
		_taken[body.get_instance_id()] = true
		frozen.lay(freeze_spell, zone.from_slot)


## Not the caster, not an ally, not a flier, and crowd control can take it.
func _applies(body: Node3D) -> bool:
	if body == zone.caster() or is_ally(body) or BodyNudge.airborne(body):
		return false
	var afflictions := Afflictions.of(body)
	return afflictions != null and not afflictions.cc_protected()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if freeze_spell == null:
		warnings.append("Falta `freeze_spell`: los números del congelamiento.")
	return warnings
