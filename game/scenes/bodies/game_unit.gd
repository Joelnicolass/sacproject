@tool
class_name GameUnit
extends RtsUnit

## The RtsKit unit of a Sacrifice body (a creature, a wizard, a Sac Doctor): a child of the
## GameBody, which keeps `owner_slot` in step (GameBody.owner_slot). It adds the game's rules the
## kit asks about: a pacifist creature refuses to attack, and a body faces the way
## GameBody.facing_flat says. Its `size` follows the body's BodyFacts (the wider of its collision
## radius and its melee reach, twice), read again whenever the body wears a new frame.
## Not: whether it is dead or summoning (the body sets `selectable` / `orderable` / `targetable`),
## how it executes an order (UnitOrders).

## The commands a creature with no aggressiveness never takes.
const ATTACKS: Array[StringName] = [&"attack", &"attack_body", &"attack_move"]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if body is GameBody:
		owner_slot = (body as GameBody).owner_slot
	var mount := _mount()
	if mount != null:
		mount.worn.connect(_on_worn)
	_on_worn(BodyFacts.of_body(body))


## A creature without a type, or whose type has no aggressiveness, moves and guards but never
## attacks.
func accepts(command: StringName) -> bool:
	if command in ATTACKS and body is UnitBody:
		var type: CreatureType = (body as UnitBody).type
		if type == null or type.aggressiveness <= 0:
			return false
	return super.accepts(command)


## The yaw of GameBody.facing_flat (what a guarding formation turns by), else the body's own yaw.
func facing_yaw() -> float:
	if body is GameBody:
		var ahead := (body as GameBody).facing_flat()
		return atan2(ahead.x, ahead.z)
	return (body as Node3D).rotation.y if body is Node3D else 0.0


func _on_worn(facts: BodyFacts) -> void:
	size = 2.0 * facts.half_size_m()


func _mount() -> BodyMount:
	var found: Variant = body.get("mount") if body != null and "mount" in body else null
	return found as BodyMount
