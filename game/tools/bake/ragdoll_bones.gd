class_name RagdollBones
extends RefCounted

## Builds the bodies of a model's physical skeleton: one `PhysicalBone3D` (a capsule along the bone, a cone joint to the nearest
## body above) per bone that is long enough. Does NOT pick the hang bone, save, or check anything (RagdollBaker and RagdollCheck do).
## A bone gets a body when its segment (the distance to its children) is at least MIN_BONE_RATIO of the model's size; a shorter one
## rides on its parent, unless a body hangs below it (then it is a short "link" that keeps the bodies together). The model is drawn
## mirrored on z, which a physics body cannot be: each body carries the mirror in its `body_offset`. Layer 16, mask 1: bones only
## meet the terrain, never units or spells.

const BONE_LAYER := 16
const BONE_MASK := 1
const MIN_BONE_RATIO := 0.06
const LEAF_RATIO := 0.35 ## a bone with no children gets this part of its own length
const RADIUS_PER_LENGTH := 0.22 ## capsule radius, as a part of the segment (never fatter than half of it)
const RADIUS_MIN_RATIO := 0.04
const DENSITY := 800.0
const FRICTION := 0.8
const LIMB_DEG := Vector2(55.0, 35.0) ## cone limits in degrees (swing, twist); a hub bone (hips, chest) is stiffer
const HUB_DEG := Vector2(28.0, 18.0)
## A capsule is never shorter than two radii plus this (Godot clamps it otherwise and the baked number lies).
const CAPSULE_SLACK_M := 0.01
const EPSILON := 0.001


## Adds the bodies under `simulator`, owned by `root`. Returns how many it made.
static func add_bodies(skeleton: Skeleton3D, simulator: PhysicalBoneSimulator3D, root: Node) -> int:
	var mirror := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, -1.0)), Vector3.ZERO)
	var offset := mirror if _world_basis(skeleton).determinant() < 0.0 else Transform3D.IDENTITY
	var size := _model_size(skeleton)
	var min_length := size * MIN_BONE_RATIO
	var linked := _bones_over_bodies(skeleton, min_length)
	var has_body := {}
	var count := 0
	for bone in skeleton.get_bone_count():
		var segment := _segment(skeleton, bone, min_length, linked.has(bone))
		if segment.is_empty():
			continue
		var length: float = segment["length"]
		var dir: Vector3 = offset.basis * (segment["dir"] as Vector3)
		var radius := clampf(maxf(length * RADIUS_PER_LENGTH, size * RADIUS_MIN_RATIO), 0.01, length * 0.5)
		var body := PhysicalBone3D.new()
		body.name = "Bone_" + skeleton.get_bone_name(bone)
		simulator.add_child(body)
		body.owner = root
		body.bone_name = skeleton.get_bone_name(bone)
		body.body_offset = offset
		body.transform = skeleton.get_bone_global_rest(bone) * offset
		body.collision_layer = BONE_LAYER
		body.collision_mask = BONE_MASK
		body.friction = FRICTION
		body.mass = maxf(0.2, PI * radius * radius * length * DENSITY)
		_add_capsule(body, root, dir, length, radius)
		if _has_parent_body(skeleton, bone, has_body):
			body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			body.joint_offset = Transform3D(Basis(Quaternion(Vector3.RIGHT, dir)), Vector3.ZERO)
			var span := HUB_DEG if segment["hub"] else LIMB_DEG
			body.set("joint_constraints/swing_span", span.x)
			body.set("joint_constraints/twist_span", span.y)
		has_body[bone] = true
		count += 1
	return count


## The capsule of a bone: its axis along `dir` (in the body's frame), from the bone's head to `length` ahead.
## The shape is sized first and assigned after, so the numbers that get saved are the ones set here.
static func _add_capsule(body: PhysicalBone3D, root: Node, dir: Vector3, length: float, radius: float) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0 + CAPSULE_SLACK_M)
	var shape := CollisionShape3D.new()
	shape.name = "Capsule"
	shape.shape = capsule
	shape.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * length * 0.5)
	body.add_child(shape)
	shape.owner = root


## The bones that have a body of their own or one below them (all their ancestors): the links of the physical skeleton.
static func _bones_over_bodies(skeleton: Skeleton3D, min_length: float) -> Dictionary:
	var over := {}
	for bone in skeleton.get_bone_count():
		if _segment(skeleton, bone, min_length, false).is_empty():
			continue
		var up := bone
		while up >= 0 and not over.has(up):
			over[up] = true
			up = skeleton.get_bone_parent(up)
	return over


## Where a bone points and how long it is, in the bone's own frame: {dir, length, hub}. Empty when it gets no body.
## `link`: a bone that is too short still gets the shortest segment (it holds bodies below it together).
static func _segment(skeleton: Skeleton3D, bone: int, min_length: float, link: bool) -> Dictionary:
	var kids: Array[Vector3] = []
	for other in skeleton.get_bone_count():
		var offset := skeleton.get_bone_rest(other).origin
		if skeleton.get_bone_parent(other) == bone and offset.length() > EPSILON:
			kids.append(offset)
	var dir := Vector3.ZERO
	var length := 0.0
	if kids.is_empty():
		var own := skeleton.get_bone_rest(bone).origin
		if skeleton.get_bone_parent(bone) < 0 or own.length() <= EPSILON:
			return {}
		dir = (skeleton.get_bone_rest(bone).basis.inverse() * own).normalized()
		length = maxf(own.length() * LEAF_RATIO, min_length)
	else:
		var sum := Vector3.ZERO
		var longest := kids[0]
		for kid: Vector3 in kids:
			sum += kid
			if kid.length() > longest.length():
				longest = kid
		dir = (sum if sum.length() > longest.length() * 0.25 else longest).normalized()
		for kid: Vector3 in kids:
			length = maxf(length, kid.dot(dir))
	if length < min_length:
		if not link:
			return {}
		length = min_length
	return {"dir": dir, "length": length, "hub": kids.size() > 1}


static func _has_parent_body(skeleton: Skeleton3D, bone: int, has_body: Dictionary) -> bool:
	var up := skeleton.get_bone_parent(bone)
	while up >= 0:
		if has_body.has(up):
			return true
		up = skeleton.get_bone_parent(up)
	return false


## The largest side of the box that holds the bone heads of the rest pose.
static func _model_size(skeleton: Skeleton3D) -> float:
	var box := AABB(skeleton.get_bone_global_rest(0).origin, Vector3.ZERO)
	for bone in skeleton.get_bone_count():
		box = box.expand(skeleton.get_bone_global_rest(bone).origin)
	return maxf(box.get_longest_axis_size(), 0.1)


## The part of the transform of everything above the skeleton in the model scene (the mirror lives in there).
static func _world_basis(skeleton: Skeleton3D) -> Basis:
	var basis := Basis.IDENTITY
	var node: Node = skeleton
	while node != null:
		if node is Node3D:
			basis = (node as Node3D).transform.basis * basis
		node = node.get_parent()
	return basis
