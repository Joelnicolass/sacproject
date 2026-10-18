class_name BodyNudge
extends RefCounted

## F121 (RFC-030j): what the effects that move a creature or a wizard from outside share (Squall's Pushback, the Flurry's
## implosion, Tumbling). sacengine `push` (state.d:8604-8612): a body on the ground slides on the land (a step that
## leaves the land is not taken, and the height is the ground's); one in the air takes the step as it is. The server
## (or solo) calls it; the clients get the position. Without terrain data (a bare debug scene) the land is everywhere
## and the ground is where the body stands.

static var TICKS := float(MatchClock.TICKS_PER_SECOND)


## sacengine push(velocity): one tick of `velocity` (m/s). True when the body moved.
static func push(body: Node3D, velocity: Vector3) -> bool:
	return slide(body, velocity / TICKS)


## The step `offset` of sacengine push / the implosion's slide. True when the body moved.
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


## sacengine effects.fixed (push and catapult do nothing, state.d:8588-8590): a petrified, frozen or vined body. The one answer
## to «can this body be moved from outside?», asked of its Afflictions.
static func fixed(body: Node) -> bool:
	var afflictions := body.get_node_or_null("Afflictions") as Afflictions
	return afflictions != null and afflictions.fixed()


## In the air on its own (a flier), not thrown.
static func airborne(body: Node3D) -> bool:
	return body.has_method("is_flying") and bool(body.call("is_flying"))


static func on_land(body: Node3D, at: Vector3) -> bool:
	var terrain := FallCheck.terrain_of(body)
	return terrain == null or bool(terrain.call("is_on_ground", at.x, at.z))


## The land height under `at`; where the body stands when there is none.
static func ground_y(body: Node3D, at: Vector3) -> float:
	var terrain := FallCheck.terrain_of(body)
	if terrain == null:
		return body.global_position.y
	var height := float(terrain.call("ground_height", at.x, at.z))
	return body.global_position.y if is_nan(height) else height


## The height a body on the ground stands at near `at`: the land's, or (REVIEW-F121) the body's own when it rests on a
## building or another body above the land (sacengine getHeight counts building tops). Off its edge, move_and_slide and
## gravity take it down.
static func floor_y(body: Node3D, at: Vector3) -> float:
	var land := ground_y(body, at)
	var character := body as CharacterBody3D
	if character and character.is_on_floor() and body.global_position.y > land + 0.1:
		return body.global_position.y
	return land


## sacengine obj.center: the middle of the body's box (its collision shape).
static func center(body: Node3D) -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position


## The body's box in world space (sacengine hitbox): the axis-aligned box of its collision capsule.
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


## Every live creature and wizard (sacengine movingObjects) whose box meets `area`, in group order (wizards first, as
## SplashDamage walks them), so the result does not depend on the scene tree.
static func bodies_in(tree: SceneTree, area: AABB, groups: Array[StringName] = [&"wizard", &"unit"]) -> Array[Node3D]:
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
	if body is UnitBody and ((body as UnitBody).mode == UnitBody.Mode.SUMMONING or (body as UnitBody).is_taken()):
		return false
	if not body is UnitBody and body.has_method("is_targetable") and not body.call("is_targetable"):
		return false
	var health := body.get_node_or_null("Health")
	return health != null and not health.call("is_dead")


## The Tumbling state of `body`, or null (a body without one cannot be thrown).
static func tumbling_of(body: Node) -> Tumbling:
	return body.get_node_or_null("Afflictions/Tumbling") as Tumbling
