class_name ProjectileTargets
extends RefCounted

## Who a spell can hit and where it aims on a body: the live-body test, the body's center, and the pick of the body a
## projectile's hit box touches (enemies first, then neutrals, then allies; the closest wins). Pure queries plus the damage
## log line; it holds no state and moves nothing.

## The layers a projectile's hit box looks at: the ground and buildings (1) and the creatures (2).
const HIT_MASK := 3
## The most bodies one hit-box query returns.
const MAX_HITS := 16


## A query for `shape`, built once by a projectile and reused every tick by `pick_body`.
static func query_for(shape: Shape3D) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = HIT_MASK
	return query


## The living body that `query`'s shape touches at `at`, except `skip`; enemies of `slot` first, then neutrals, then its own
## side, the closest of a rank wins. `skip_own_side` drops the bodies of `slot`. Null when none.
static func pick_body(
	from: Node3D, query: PhysicsShapeQueryParameters3D, at: Vector3, skip: Node, slot: int, skip_own_side: bool
) -> Node3D:
	if query.shape == null:
		return null
	query.transform = Transform3D(Basis(), at)
	var best: Node3D = null
	var best_key := Vector2(INF, INF)
	for hit in from.get_world_3d().direct_space_state.intersect_shape(query, MAX_HITS):
		var body := hit.get("collider") as Node3D
		if body == null or body == skip or not is_live_body(body):
			continue
		var other := int(body.get("owner_slot")) if "owner_slot" in body else 0
		if skip_own_side and other == slot:
			continue
		var rank := 2.0 if other == slot else (1.0 if other <= 0 or slot <= 0 else 0.0)
		var key := Vector2(rank, at.distance_squared_to(body_center(body)))
		if key < best_key:
			best_key = key
			best = body
	return best


## Where a projectile aims on `body`: its `Collision` child, or its origin when it has none.
static func body_center(body: Node3D) -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return col.global_position if col else body.global_position


## True for an attackable body that is targetable and alive.
static func is_live_body(body: Node) -> bool:
	if not Attackable.is_body(body):
		return false
	if not GameBody.targetable(body):
		return false
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead()


## Logs the damage `target` took ("damage <who> <taken> health <left>").
static func report(target: Node3D, taken: float, kind: StringName) -> void:
	var health := target.get_node("Health") as Health
	# Bodies of the same kind are told apart by their display name.
	var who := str(target.name) if DebugLog.on(&"oil") else GameBody.name_of(target)
	var line := "damage %s %d health %d" % [who, roundi(taken), roundi(health.current)]
	if taken <= 0.0 and health.resistance(kind) <= 0.0:
		line += " (inmune)"
	print(line)
