class_name RagdollPose
extends RefCounted

## The math of a rag doll that has no tree of its own: keeping the pose the bones ended in when the physics stops, the brake that
## keeps a falling body near where it fell, and the push that makes a hanging anchor follow its skeleton. It only touches the
## nodes it is given and never decides when anything happens (RagdollDriver does).


## The physical bones of `simulator`, in order (empty without one).
static func bones_of(simulator: PhysicalBoneSimulator3D) -> Array[PhysicalBone3D]:
	var found: Array[PhysicalBone3D] = []
	if simulator != null:
		for child in simulator.get_children():
			if child is PhysicalBone3D:
				found.append(child)
	return found


## The pose of every bone, in the skeleton's space, as the physical bones carry it now (bone id -> Transform3D).
static func capture(skeleton: Skeleton3D, bones: Array[PhysicalBone3D]) -> Dictionary:
	var poses := {}
	for bone in bones:
		poses[bone.get_bone_id()] = (
			skeleton.global_transform.affine_inverse()
			* (bone.global_transform * bone.body_offset.affine_inverse())
		)
	return poses


## Writes the poses of `capture` into the skeleton, the bones nearest the root first so a child never undoes its parent.
static func apply(skeleton: Skeleton3D, poses: Dictionary) -> void:
	var ids := poses.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return _depth(skeleton, a) < _depth(skeleton, b))
	for id: int in ids:
		skeleton.set_bone_global_pose(id, poses[id])


## How fast the bones lose speed, linear and spin (it replaces the default of the world).
static func damp(bones: Array[PhysicalBone3D], value: float) -> void:
	for bone in bones:
		bone.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		bone.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		bone.linear_damp = value
		bone.angular_damp = value


## Throws every bone along `direction` (its length is ignored; zero: no throw) at `speed` meters per second.
static func push(bones: Array[PhysicalBone3D], direction: Vector3, speed: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	for bone in bones:
		bone.linear_velocity = direction.normalized() * speed


## The hips may not go farther than `max_drift_m` along the ground from `start`: whatever speed takes the bones out is taken away.
static func brake(bones: Array[PhysicalBone3D], start: Vector3, max_drift_m: float) -> void:
	var away := bones[0].global_position - start
	away.y = 0.0
	if away.length() <= max_drift_m:
		return
	var out := away.normalized()
	for bone in bones:
		var outward := bone.linear_velocity.dot(out)
		if outward > 0.0:
			bone.linear_velocity -= out * outward


## Cone limits wide enough that a hanging chain never pushes against them (tight cones blow up under gravity).
const HANG_SPAN_DEG := 180.0


## Starts the simulation: every bone (a fall: the joints stay as built), or every bone but `anchor`, which stays on the skeleton (a
## hang). A hang rebuilds every cone joint, parents first, on HANG_SPAN_DEG cones: Godot builds a joint when its bone enters the tree,
## with every body static, and the joints hanging from the root come out loose. Rebuilding them for a fall sends
## bones flying (a gallery fall), so a fall keeps them. `spans` (spans_of) are put back before the cones open.
static func start(
	simulator: PhysicalBoneSimulator3D,
	skeleton: Skeleton3D,
	spans: Dictionary,
	anchor: PhysicalBone3D
) -> void:
	var names: Array[StringName] = []
	for bone in bones_of(simulator):
		if bone != anchor:
			names.append(StringName(bone.bone_name))
	simulator.physical_bones_start_simulation(names)
	if anchor == null:
		return
	var cones: Array[PhysicalBone3D] = []
	for bone in bones_of(simulator):
		if bone.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
			cones.append(bone)
	cones.sort_custom(
		func(a: PhysicalBone3D, b: PhysicalBone3D) -> bool:
			return _depth(skeleton, a.get_bone_id()) < _depth(skeleton, b.get_bone_id())
	)
	for bone in cones:
		var limits: Dictionary = spans.get(bone, {})
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		for key: String in limits:
			bone.set("joint_constraints/" + key, limits[key])
		bone.set("joint_constraints/swing_span", HANG_SPAN_DEG)
		bone.set("joint_constraints/twist_span", HANG_SPAN_DEG)


## The cone limits each bone was baked with (bone -> {swing_span, twist_span, bias, softness, relaxation}).
static func spans_of(bones: Array[PhysicalBone3D]) -> Dictionary:
	var out := {}
	for bone in bones:
		if bone.joint_type != PhysicalBone3D.JOINT_TYPE_CONE:
			continue
		var limits := {}
		for key: String in ["swing_span", "twist_span", "bias", "softness", "relaxation"]:
			limits[key] = bone.get("joint_constraints/" + key)
		out[bone] = limits
	return out


static func _depth(skeleton: Skeleton3D, bone: int) -> int:
	var depth := 0
	var up := skeleton.get_bone_parent(bone)
	while up >= 0:
		depth += 1
		up = skeleton.get_bone_parent(up)
	return depth
