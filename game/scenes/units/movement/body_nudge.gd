class_name BodyNudge
extends RefCounted

## What the effects that move a creature or a wizard from outside share (Squall's Pushback, the Flurry's
## implosion, Tumbling). A body on the ground slides on the land (a step that
## leaves the land is not taken, and the height is the ground's); one in the air takes the step as it is. The server
## (or solo) calls it; the clients get the position. Without terrain data (a bare debug scene) the land is everywhere
## and the ground is where the body stands.


## How hard an area pushes a body `distance` m from its middle (m/s): `speed` at `inner`, falling in a line to `edge` at `radius`, 0 from
## `radius` out; under `inner` it keeps growing (1.5 times `speed` at the middle with inner 5 and radius 15). The ritual and a tower
## being cast push with it.
static func push_speed(
	distance: float, inner: float, radius: float, speed: float, edge := 0.0
) -> float:
	if distance >= radius or radius <= inner:
		return 0.0
	return lerpf(speed, edge, (maxf(distance, 0.0) - inner) / (radius - inner))


## One tick of `velocity` (m/s). True when the body moved.
static func push(body: Node3D, velocity: Vector3) -> bool:
	return slide(body, velocity / MatchClock.TICKS_PER_SECOND_F)


## The step `offset` of a push / the implosion's slide. True when the body moved.
static func slide(body: Node3D, offset: Vector3) -> bool:
	if fixed(body):
		return false
	var at := body.global_position + offset
	if not airborne(body):
		if not on_land(body, at):
			return false
		at.y = floor_y(body, at)
	body.global_position = at
	return true


## The one place that puts a body somewhere else in one go (the server, or solo) without a WarpSnap: it writes the pose and tells
## physics interpolation not to slide the picture from the old place to the new one.
static func place(body: Node3D, to: Vector3) -> void:
	body.global_position = to
	body.reset_physics_interpolation()


## A petrified, frozen or vined body (push and catapult do nothing). The one answer
## to «can this body be moved from outside?», asked of its Afflictions.
static func fixed(body: Node) -> bool:
	var afflictions := body.get_node_or_null("Afflictions") as Afflictions
	return afflictions != null and afflictions.fixed()


## In the air on its own (a flier), not thrown.
static func airborne(body: Node3D) -> bool:
	return body is UnitBody and (body as UnitBody).is_flying()


static func on_land(body: Node3D, at: Vector3) -> bool:
	var shape := Terrain.of(body)
	return shape == null or shape.is_on_ground(at.x, at.z)


## The land height under `at`; where the body stands when there is none.
static func ground_y(body: Node3D, at: Vector3) -> float:
	var shape := Terrain.of(body)
	if shape == null:
		return body.global_position.y
	var height := shape.height_at(at.x, at.z)
	return body.global_position.y if is_nan(height) else height


## The height a body on the ground stands at near `at`: the land's, or the body's own when it rests on a
## building or another body above the land (building tops count). Off its edge, move_and_slide and
## gravity take it down.
static func floor_y(body: Node3D, at: Vector3) -> float:
	var land := ground_y(body, at)
	var character := body as CharacterBody3D
	if character and character.is_on_floor() and body.global_position.y > land + 0.1:
		return body.global_position.y
	return land


## The middle of the body's box (its collision shape).
static func center(body: Node3D) -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position


## The body's box in world space: the axis-aligned box of its collision capsule.
static func box(body: Node3D) -> AABB:
	var half := Vector3(0.3, 0.9, 0.3)
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var capsule := col.shape as CapsuleShape3D
		half = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	elif col and col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		half = Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
	elif col and col.shape is BoxShape3D:
		half = (col.shape as BoxShape3D).size * 0.5
	return AABB(center(body) - half, half * 2.0)


## Every live creature and wizard whose box meets `area`, in group order (wizards first, as
## SplashDamage walks them), so the result does not depend on the scene tree.
static func bodies_in(
	tree: SceneTree, area: AABB, groups: Array[StringName] = [&"wizard", &"unit"]
) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var seen := {}
	for group in groups:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or seen.has(body) or not _alive(body):
				continue
			seen[body] = true
			if box(body).intersects(area):
				found.append(body)
	return found


## Alive and on the field (a corpse, a ghost or a body being summoned is not moved): each effect asks the rest.
static func _alive(body: Node3D) -> bool:
	if not Attackable.is_body(body):
		return false
	if (
		body is UnitBody
		and ((body as UnitBody).mode == UnitBody.Mode.SUMMONING or (body as UnitBody).is_taken())
	):
		return false
	if not body is UnitBody and not GameBody.targetable(body):
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## The Tumbling state of `body`, or null (a body without one cannot be thrown).
static func tumbling_of(body: Node) -> Tumbling:
	return body.get_node_or_null("Afflictions/Tumbling") as Tumbling
