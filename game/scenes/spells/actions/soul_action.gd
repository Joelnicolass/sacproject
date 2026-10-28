@tool
class_name SoulAction
extends SpellAction

## A spell that sends something walking to a soul and back (Soul Mole, Soul Wind). The click names a soul the wizard may fetch: blue for
## his side, not dropped with P, still waiting. The thing is born at his feet when the cast starts and already walks while he casts;
## when the casting time ends it starts to act (stun, hurt), and if the wizard is interrupted it vanishes. One scene per spell: the
## kind of carrier and the numbers change, not the script. It does not walk the route (SpellCarrier) nor take the soul (SoulFetch).

## The carrier scene that walks to the soul (its root is a SpellCarrier).
@export var carrier: PackedScene

## The carrier of the cast in progress (server only).
var _carrier: SpellCarrier


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if carrier == null:
		warnings.append("`carrier` is empty: drag the carrier scene.")
	return warnings


## Funds first, then a soul the wizard can fetch, then the range (the order of the whole book).
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	var soul := picked as Soul
	if soul == null or not soul.fetchable_by(int(wizard.get("owner_slot"))):
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(soul.global_position) > spell.cast_range_m:
		aim.status = OUT_OF_RANGE
	else:
		aim.target = soul
		aim.point = soul.global_position
	return aim


## The carrier is born now: in the original it walks during the casting time too.
func started(wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	if carrier == null:
		push_error("SoulAction %s: `carrier` is empty, nothing walks to the soul." % name)
		return
	var spawner := projectile_spawner()
	if spawner == null:
		return
	# Only where it starts, who sends it, the soul and the damage: the walk sets its own pace.
	var launch := ProjectileLaunch.new()
	launch.from = wizard.global_position
	launch.caster = wizard.get_path()
	launch.target = aim.target.get_path()
	launch.slot = wizard.owner_slot
	launch.damage = float(spell.damage)
	_carrier = spawner.spawn_launch(carrier, launch) as SpellCarrier


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.arm()
	_carrier = null
	return ""


func cancel() -> void:
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.stop()
	_carrier = null
