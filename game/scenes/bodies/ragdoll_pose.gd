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
		poses[bone.get_bone_id()] = skeleton.global_transform.affine_inverse() * (bone.global_transform * bone.body_offset.affine_inverse())
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


## Gives `bone` the speed and the spin that take it to `goal` (a global transform) within `delta` seconds.
static func follow(bone: PhysicalBone3D, goal: Transform3D, delta: float) -> void:
	bone.linear_velocity = (goal.origin - bone.global_position) / delta
	var turn := (goal.basis.orthonormalized() * bone.global_transform.basis.orthonormalized().inverse()).get_rotation_quaternion()
	var angle := turn.get_angle()
	bone.angular_velocity = turn.get_axis() * angle / delta if angle > 0.0001 else Vector3.ZERO


static func _depth(skeleton: Skeleton3D, bone: int) -> int:
	var depth := 0
	var up := skeleton.get_bone_parent(bone)
	while up >= 0:
		depth += 1
		up = skeleton.get_bone_parent(up)
	return depth
