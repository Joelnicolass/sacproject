class_name TeleportMath
extends RefCounted

## The sums of Teleport (RFC-021c), with no world: where the group lands and where each body goes.
## Positions are compared on the plane (x, z); the height is the body's business (see warp_to), because the
## spot is on the land, never on a pillar or inside a building. `on_ground` is a Callable(x: float, z: float) -> bool
## (the terrain's is_on_ground); an empty one means «everything is land».


## getTeleportPosition (sacengine state.d:10215-10228): `radius` from the building toward where the wizard
## stands; if that spot has no land (or the wizard is right over the building and there is no side to
## come from), the building's own position (the original leaves `// TODO: fix` there, state.d:10225).
## Y is the building's.
static func landing(start: Vector3, building: Vector3, radius: float, on_ground: Callable = Callable()) -> Vector3:
	var flat := Vector2(start.x - building.x, start.z - building.z)
	if flat.length_squared() <= 0.000001:
		return building
	var spot := building + _flat3(flat.normalized() * radius)
	if not _ground(on_ground, spot):
		return building
	return spot


## teleport (state.d:10313-10327): `newPosition = obj.position - startPosition + targetPosition`, the formation
## is kept. A walker whose slot has no land goes to the landing spot itself (state.d:10318-10320, another
## `// TODO: fix`); a flier keeps the shifted position wherever it falls.
static func carried(position: Vector3, start: Vector3, destination: Vector3, flying: bool, on_ground: Callable = Callable()) -> Vector3:
	var moved := Vector3(position.x - start.x + destination.x, position.y, position.z - start.z + destination.z)
	if not flying and not _ground(on_ground, moved):
		return destination
	return moved


## proximity.eachInRange(startPosition, effectRange) (state.d:10326): who is close enough to the wizard.
static func in_radius(position: Vector3, start: Vector3, radius: float) -> bool:
	return Vector2(position.x - start.x, position.z - start.z).length() <= radius


static func _ground(on_ground: Callable, at: Vector3) -> bool:
	return not on_ground.is_valid() or bool(on_ground.call(at.x, at.z))


static func _flat3(flat: Vector2) -> Vector3:
	return Vector3(flat.x, 0.0, flat.y)
