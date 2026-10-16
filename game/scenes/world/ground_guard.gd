class_name GroundGuard
extends RefCounted

## Keeps walkers on the land, as sacengine moveOnGround (sacmap.d:611-635): a step that would
## leave the ground becomes the best of 8 compass slides that stays on it, or no step at all.
## Call keep_on_ground on the velocity right before move_and_slide and hold_on_ground right after.
## Bodies that still end up deep in a hole: has_fallen (state.d:14800-14821, gibDepth).

const TERRAIN_GROUP := &"terrain"
## sacengine gibDepth = 0.5 * mapDepth = 25 m (state.d:14444, sacmap.d:108).
const FALL_DEPTH := 25.0
## sacengine wizardAltarDistance (state.d:2357).
const ALTAR_RETURN_DISTANCE := 15.0
const SLIDES: Array[Vector2] = [
	Vector2(-0.70710678, -0.70710678), Vector2(-1.0, 0.0), Vector2(-0.70710678, 0.70710678),
	Vector2(0.0, -1.0), Vector2(0.0, 1.0),
	Vector2(0.70710678, -0.70710678), Vector2(1.0, 0.0), Vector2(0.70710678, 0.70710678),
]


static func terrain_of(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var terrain := node.get_tree().get_first_node_in_group(TERRAIN_GROUP)
	if terrain == null or not terrain.call("has_ground_data"):
		return null
	return terrain


## Velocity whose horizontal step this frame does not leave the ground. Y is kept.
## A body already off the ground keeps its velocity (it is falling, sacengine tumbling).
static func keep_on_ground(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	var terrain := terrain_of(body)
	if terrain == null or delta <= 0.0:
		return velocity
	var at := body.global_position
	var step := Vector2(velocity.x, velocity.z) * delta
	if step.length_squared() < 0.0000001 or not terrain.call("is_on_ground", at.x, at.z):
		return velocity
	if terrain.call("is_on_ground", at.x + step.x, at.z + step.y):
		return velocity
	var best := Vector2.ZERO
	var best_along := 0.0
	for slide in SLIDES:
		var along := slide.dot(step)
		if along <= best_along:
			continue
		var moved := slide * along
		if terrain.call("is_on_ground", at.x + moved.x, at.z + moved.y):
			best = moved
			best_along = along
	return Vector3(best.x / delta, velocity.y, best.y / delta)


## Call right after move_and_slide with the position from before it. Gravity can still slide a
## body down a steep lip into a hole; a walker on the ground keeps its old position when the new
## one has none (state.d:14824-14834). Returns true when it held the body.
static func hold_on_ground(body: CharacterBody3D, previous: Vector3) -> bool:
	var terrain := terrain_of(body)
	if terrain == null or not terrain.call("is_on_ground", previous.x, previous.z):
		return false
	var at := body.global_position
	if terrain.call("is_on_ground", at.x, at.z):
		return false
	body.global_position = previous
	body.velocity = Vector3.ZERO
	return true


## True once the body is over a hole and FALL_DEPTH below the lowest land.
static func has_fallen(body: Node3D) -> bool:
	var terrain := terrain_of(body)
	if terrain == null:
		return false
	var at := body.global_position
	if terrain.call("is_on_ground", at.x, at.z):
		return false
	return at.y < float(terrain.call("lowest_ground")) - FALL_DEPTH


## sacengine getTeleportPosition (state.d:10215): ALTAR_RETURN_DISTANCE from the altar toward
## where the body was, or the altar itself when that spot has no ground. Y is the land height.
static func altar_return_spot(body: Node3D, altar: Vector3) -> Vector3:
	var flat := Vector3(body.global_position.x - altar.x, 0.0, body.global_position.z - altar.z)
	var spot := altar
	if flat.length_squared() > 0.000001:
		spot = altar + flat.normalized() * ALTAR_RETURN_DISTANCE
	var terrain := terrain_of(body)
	if terrain == null:
		return spot
	if not terrain.call("is_on_ground", spot.x, spot.z):
		spot = altar
	var height := float(terrain.call("ground_height", spot.x, spot.z))
	if not is_nan(height):
		spot.y = height
	return spot
