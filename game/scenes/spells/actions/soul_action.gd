@tool
class_name SoulAction
extends SpellAction

## A spell that sends something walking to a soul and back (Soul Mole, Soul Wind). The click names a soul the wizard may fetch: blue for
## his side, not dropped with P, still waiting. The thing is born at his feet when the cast starts and already walks while he casts;
## when the casting time ends it starts to act (stun, hurt), and if the wizard is interrupted it vanishes. One scene per spell: the
## kind of carrier and the numbers change, not the script. It does not walk the route (SpellCarrier) nor take the soul (SoulFetch).
## Ref: sacengine castSoulMole, castSoulWind (state.d:10814-10826, 10941-10954).

## Key of the carrier scene in SpellSpawner.
@export var carrier_kind := ""

## The carrier of the cast in progress (server only).
var _carrier: SpellCarrier


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
	elif wizard.global_position.distance_to(soul.global_position) > spell.cast_range:
		aim.status = OUT_OF_RANGE
	else:
		aim.target = soul
		aim.point = soul.global_position
	return aim


## The carrier is born now: in the original it walks during the casting time too.
func started(wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var at := wizard.global_position
	_carrier = spawner.spawn_projectile(carrier_kind, {
		"x": at.x, "y": at.y, "z": at.z,
		"caster": str(wizard.get_path()),
		"target": str(aim.target.get_path()),
		"slot": int(wizard.get("owner_slot")),
		"damage": float(spell.damage),
	}) as SpellCarrier


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.arm()
	_carrier = null
	return ""


func cancel() -> void:
	if _carrier != null and is_instance_valid(_carrier):
		_carrier.stop()
	_carrier = null
