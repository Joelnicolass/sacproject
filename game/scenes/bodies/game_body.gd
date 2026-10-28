@tool
class_name GameBody
extends CharacterBody3D

## A body that plays in a match: a creature (UnitBody), a wizard (WizardBody) or a Sac Doctor (DoctorBody). It answers the
## questions every other system asks a body: whose it is, whether it is dead, whether it can be picked or hit, whether the
## others steer around it, whether it takes mana, where it faces, what it is called and whether it walks. Each answer has a
## default a subclass overrides. It does not move, draw or decide anything: its children do.
## Buildings are not GameBody (they are StaticBody3D); `targetable()` also asks a CastTower.

## Player slot the body belongs to (0 = nobody).
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		_owner_slot_changed()


## The body is dead. A body that never dies (a wizard turns ghost) answers false.
func is_dead() -> bool:
	return false


## Creatures, shots and spells may pick or hit it.
func is_targetable() -> bool:
	return true


## The others steer around it.
func is_obstacle() -> bool:
	return true


## A mana gift (a Manahoar, a fount) may feed it.
func can_take_mana() -> bool:
	return true


## The name the HUD and the logs show.
func display_name() -> String:
	return str(name)


## The unit vector the body faces on the ground (+Z turned by its yaw).
func facing_flat() -> Vector3:
	var ahead := Vector3.BACK.rotated(Vector3.UP, rotation.y)
	ahead.y = 0.0
	return Vector3.BACK if ahead.length_squared() < 0.000001 else ahead.normalized()


## Walks one straight leg to `goal` (PathFollower hands each leg here). A body that does not walk ignores it.
func begin_walk(_goal: Vector3) -> void:
	pass


## A walk is in progress.
func is_walking() -> bool:
	return false


## The display name of any node: a GameBody names itself, anything else gives its node name.
static func name_of(node: Node) -> String:
	if node is GameBody:
		return (node as GameBody).display_name()
	return str(node.name)


## Whether `node` may be picked or hit: a GameBody or a CastTower answers; any other node (or null) may.
static func targetable(node: Node) -> bool:
	if node is GameBody:
		return (node as GameBody).is_targetable()
	if node is CastTower:
		return (node as CastTower).is_targetable()
	return true


## Called when `owner_slot` changes, also while the scene loads (children may not be ready).
func _owner_slot_changed() -> void:
	pass
