@tool
class_name AnimateDeadAction
extends SpellAction

## Animate Dead: the click names the soul of a dead creature the wizard may take back; the creature starts to rise as soon as the cast
## starts (it does not wait for the casting time, and an interruption does not undo it). It climbs, turns and stands up on its own
## (FastRevive with the slow knobs), and a replicated effect shows the streams from the wizard to it. A soul without a corpse (a
## dropped one, a free one) is refused before any mana is spent. It does not decide how long the revival takes (the FastRevive scene).
## Ref: sacengine castAnimateDead, animateDead (state.d:10859-10903).

## The revival the creature goes through (a FastRevive scene with the normal, slow knobs).
@export var revive_scene: PackedScene
## The replicated effect of the streams from the wizard to the creature (an AnimateDeadFx scene).
@export var effect: PackedScene


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if effect == null:
		warnings.append("`effect` is empty: drag the streams scene.")
	return warnings


## Funds first, then a soul on a dead creature of the wizard's side, then the range.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	var soul := picked as Soul
	var corpse := soul.corpse as UnitBody if soul != null else null
	if corpse == null or not corpse.is_dead() or not soul.fetchable_by(int(wizard.get("owner_slot"))):
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(soul.global_position) > spell.cast_range_m:
		aim.status = OUT_OF_RANGE
	else:
		aim.target = corpse
		aim.point = corpse.global_position
		aim.data["soul"] = soul
	return aim


func started(wizard: WizardBody, _spell: SpellType, aim: Aim, _frames: int) -> void:
	var corpse := aim.target as UnitBody
	var revive := revive_scene.instantiate() as FastRevive if revive_scene != null else null
	if revive == null or not revive.begin(corpse, aim.data.get("soul") as Soul):
		if revive != null:
			revive.free()
		return
	corpse.add_child(revive)
	if effect == null:
		push_error("AnimateDeadAction %s: `effect` is empty, the streams are not shown." % name)
		return
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var at := corpse.global_position
	spawner.spawn_scene(effect, {
		"x": at.x, "y": at.y, "z": at.z,
		"caster": str(wizard.get_path()),
		"target": str(corpse.get_path()),
		"ticks": revive.revive_ticks,
	})
