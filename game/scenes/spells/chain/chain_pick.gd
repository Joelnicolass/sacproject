class_name ChainPick
extends RefCounted

## The choosing of a chain, with no state of its own: from a point, inside a radius, the body that comes next (the nearest one, or the one
## with the lowest health), and the point a jump falls on when nobody is in reach. It does not remember who was hit (ChainHop) nor what a
## jump does (ChainEffect).

enum Order { CLOSEST, LOWEST_HEALTH }


## The nearest (or weakest) live body of the right side inside `radius` of `from`, not in `taken`; null when there is none. Ties go to the
## name, so the answer does not depend on the order of the tree.
static func next(tree: SceneTree, from: Vector3, radius: float, taken: Array[Node3D], slot: int, allies: bool, order: Order) -> Node3D:
	var best: Node3D
	var best_key := Vector2(INF, INF)
	var seen := {}
	for group in [&"wizard", &"unit"]:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or seen.has(body) or taken.has(body) or not LightningStrike.is_valid_target(body):
				continue
			seen[body] = true
			var distance := BodyNudge.center(body).distance_to(from)
			if distance > radius or _is_ally(body, slot) != allies:
				continue
			var key := Vector2(_health_fraction(body) if order == Order.LOWEST_HEALTH else 0.0, distance)
			if best == null or key < best_key or (key == best_key and str(body.name) < str(best.name)):
				best = body
				best_key = key
	return best


## Where a jump with nobody in reach falls: past the last body (`previous` to `current` goes on), within lerp(limit_min, 1, U) of the range,
## drifted a little by chance, and over the land.
static func fallback(from_node: Node3D, current: Vector3, previous: Vector3, reach: float, limit_min: float, drift: float, rng: RandomNumberGenerator) -> Vector3:
	var limit := lerpf(limit_min, 1.0, rng.randf()) * reach
	var wander := Vector2.from_angle(rng.randf() * TAU) * drift * limit * rng.randf()
	var at := 2.0 * current - previous + Vector3(wander.x, 0.0, wander.y)
	if at.distance_to(current) > limit:
		at = current + (at - current).normalized() * limit
	var ground := GroundRay.surface_y(from_node, at, 1, GroundRay.wizard_rids(from_node.get_tree()), INF)
	at.y = ground if is_finite(ground) else current.y
	return at


static func _is_ally(body: Node3D, slot: int) -> bool:
	var other := int(body.get("owner_slot")) if "owner_slot" in body else 0
	return other == slot or SideRelations.stance(slot, other) == SideRelations.Stance.ALLY


static func _health_fraction(body: Node3D) -> float:
	var health := Health.of(body)
	return health.current / maxf(health.maximum, 1.0) if health != null else 1.0
