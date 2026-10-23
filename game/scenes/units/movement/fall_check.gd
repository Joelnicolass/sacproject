class_name FallCheck
extends RefCounted

## What the port still decides about the land (RFC-036 036h): the terrain of a body, whether it fell into a hole and
## died (rule: sacengine gibDepth, state.d:14800-14821) and where a body returns to an altar. Walking stays on the land
## through the navmesh (EdgeClamp) and the terrain collision, not through a copy of moveOnGround.

## sacengine gibDepth = 0.5 * mapDepth = 25 m (state.d:14444, sacmap.d:108).
const FALL_DEPTH := 25.0
## sacengine wizardAltarDistance (state.d:2357).
const ALTAR_RETURN_DISTANCE := 15.0


## True once the body is over a hole and FALL_DEPTH below the lowest land.
static func has_fallen(body: Node3D) -> bool:
	var shape := TerrainShape.of(body)
	if shape == null:
		return false
	var at := body.global_position
	if shape.is_on_ground(at.x, at.z):
		return false
	return at.y < shape.lowest() - FALL_DEPTH


## sacengine getTeleportPosition (state.d:10215): ALTAR_RETURN_DISTANCE from the altar toward
## where the body was, or the altar itself when that spot has no ground. Y is the land height.
static func altar_return_spot(body: Node3D, altar: Vector3) -> Vector3:
	var flat := Vector3(body.global_position.x - altar.x, 0.0, body.global_position.z - altar.z)
	var spot := altar
	if flat.length_squared() > 0.000001:
		spot = altar + flat.normalized() * ALTAR_RETURN_DISTANCE
	var shape := TerrainShape.of(body)
	if shape == null:
		return spot
	if not shape.is_on_ground(spot.x, spot.z):
		spot = altar
	var height := shape.height_at(spot.x, spot.z)
	if not is_nan(height):
		spot.y = height
	return spot
