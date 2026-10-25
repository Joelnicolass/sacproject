class_name VisionRules
extends RefCounted

## The plain arithmetic of sight: is a point inside a sight shape, inside a cone, and has a memory run out.
## It holds no state and needs no tree, so the rules suite can try it alone. It does not know bodies or sides (Vision does).
## Ref: sacengine markVisibleNTTs (state.d:12901) measures the flat distance to the center of each body.


## Whether `at` is inside the sight shape around `center`: a cylinder looks at the flat distance (height does not matter), a sphere at the
## full distance. `forward` and `fov_deg` cut the cone (360 = no cone).
static func covers(round_shape: bool, center: Vector3, at: Vector3, range_m: float, forward: Vector3, fov_deg: float) -> bool:
	var offset := at - center
	if not round_shape:
		offset.y = 0.0
	if offset.length_squared() > range_m * range_m:
		return false
	return in_cone(forward, offset, fov_deg)


## Whether `offset` (center to target) lies within `fov_deg` degrees in total around `forward`, both seen from above.
## A target on top of the viewer is always inside.
static func in_cone(forward: Vector3, offset: Vector3, fov_deg: float) -> bool:
	if fov_deg >= 360.0:
		return true
	var flat := Vector2(offset.x, offset.z)
	var ahead := Vector2(forward.x, forward.z)
	if flat.length_squared() < 0.000001 or ahead.length_squared() < 0.000001:
		return true
	return absf(ahead.angle_to(flat)) <= deg_to_rad(fov_deg) * 0.5


## Whether a mark made at tick `made` has run out at tick `now` after `forget_ticks` ticks. `FOREVER` marks never do.
static func lapsed(made: int, now: int, forget_ticks: int) -> bool:
	return made != Vision.FOREVER and now - made >= forget_ticks


## Order of everything Vision reports: by node name, then by path, never by the order physics or groups happen to list them.
static func by_name(a: Node, b: Node) -> bool:
	var name_a := String(a.name)
	var name_b := String(b.name)
	if name_a != name_b:
		return name_a < name_b
	return str(a.get_path()) < str(b.get_path())


## The player slot a node belongs to (0 for a node with none, like a fake structure of a test).
static func slot_of(node: Object) -> int:
	var slot: Variant = node.get("owner_slot") if node != null else null
	return int(slot) if slot != null else 0


static var _raw: Array = []
static var _sorted: Array = []


## Of `candidates` (any order, repeats allowed), the nodes other than `me` that are in the tree, not corpses, and inside the sight
## shape and cone around `center`; sorted by name. The sorted, de-duplicated list is kept while the candidates do not change (every body
## of a tick asks with the same list), so a look costs one pass over it.
static func filter(candidates: Array, me: Node3D, round_shape: bool, center: Vector3, range_m: float, fov_deg: float) -> Array[Node3D]:
	if candidates != _raw:
		_raw = candidates
		var done := {}
		_sorted = []
		for node: Variant in candidates:
			if node is Node3D and not done.has(node.get_instance_id()):
				done[node.get_instance_id()] = true
				_sorted.append(node)
		_sorted.sort_custom(by_name)
	var found: Array[Node3D] = []
	var limit := range_m * range_m
	var forward := me.global_basis.z
	for node: Variant in _sorted:
		if not is_instance_valid(node) or node == me:
			continue
		var other: Node3D = node
		var offset := other.global_position - center
		if not round_shape:
			offset.y = 0.0
		if offset.length_squared() > limit or not in_cone(forward, offset, fov_deg):
			continue
		if other.is_inside_tree() and not other.is_in_group(&"corpse"):
			found.append(other)
	return found


## The nodes the groups list, plus (with the area) the bodies it overlaps that sit in one of the groups. Groups with no physics body
## (Vision.BODILESS) are always walked; the others only when there is no area.
static func gather(tree: SceneTree, groups: PackedStringArray, overlapping: Array, by_area: bool) -> Array:
	var nodes: Array = []
	for group in groups:
		if not by_area or Vision.BODILESS.has(StringName(group)):
			nodes.append_array(tree.get_nodes_in_group(group))
	for other: Node in overlapping:
		for group in groups:
			if other.is_in_group(group):
				nodes.append(other)
				break
	return nodes


## Sizes the cylinder of `shape` (the scene gives each body its own copy) to `range_m`: 400 m tall to also see what flies or stands on a
## hill, or as tall as it is wide for a sphere. The size is set before the body starts to look.
static func fit(shape: CollisionShape3D, round_shape: bool, range_m: float) -> void:
	var cylinder: CylinderShape3D = shape.shape as CylinderShape3D if shape != null else null
	if cylinder == null or range_m <= 0.0:
		return
	cylinder.radius = range_m
	cylinder.height = range_m * 2.0 if round_shape else 400.0
