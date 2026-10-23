class_name RagdollDriver
extends Node

## Lets a dead body fall like a rag doll: it switches on the physical skeleton baked into the model (tools/bake/bake_ragdolls.gd),
## pushes it a little away, and after `settle_s` freezes the pose and stops the physics, so a field full of corpses costs
## nothing. The bones only meet the terrain (layer 16 with mask 1): they never push a unit nor touch a spell. It moves the
## model only: the body, its collision and its soul stay where the simulation put them, and nothing in the simulation reads it.

## The ragdoll started to fall.
signal started
## The pose is frozen and the physics is off.
signal froze

@export_group("Fall")
## Speed the body is thrown away along the direction given to start() (meters per second).
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var push_back_m_s := 2.5
## Seconds the body may move; after this the pose is frozen and the physical skeleton stops.
@export_range(0.5, 10.0, 0.1, "suffix:s") var settle_s := 2.5
## How far from where it fell the hips may travel on the ground; past it the body is stopped (the soul and the doctor use
## the position of the simulation, not of the model).
@export_range(0.0, 5.0, 0.1, "suffix:m") var max_drift_m := 1.5
## How fast the bones lose speed (linear and spin): higher lies down sooner and slides less.
@export_range(0.0, 20.0, 0.1) var bone_damping := 1.5

var _skeleton: Skeleton3D
var _simulator: PhysicalBoneSimulator3D
var _bones: Array[PhysicalBone3D] = []
var _elapsed := 0.0
var _hips_start := Vector3.ZERO
var _running := false


func _ready() -> void:
	set_physics_process(false)


## Looks for the physical skeleton in `skeleton` (the model of the body). True when it has one: this body can fall as a ragdoll.
func bind(skeleton: Skeleton3D) -> bool:
	_skeleton = skeleton
	_simulator = null
	_bones.clear()
	if skeleton != null:
		var found := skeleton.find_children("*", "PhysicalBoneSimulator3D", false, false)
		if not found.is_empty():
			_simulator = found[0] as PhysicalBoneSimulator3D
			for child in _simulator.get_children():
				if child is PhysicalBone3D:
					_bones.append(child)
	return available()


func available() -> bool:
	return _simulator != null and not _bones.is_empty()


func is_running() -> bool:
	return _running


## The body falls. `direction` is where it is thrown (its length is ignored; zero = it just collapses).
func start(direction: Vector3) -> void:
	if not available() or _running:
		return
	_simulator.process_mode = Node.PROCESS_MODE_INHERIT
	for bone in _bones:
		bone.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		bone.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		bone.linear_damp = bone_damping
		bone.angular_damp = bone_damping
	_simulator.physical_bones_start_simulation()
	var push := direction.normalized() * push_back_m_s if direction.length_squared() > 0.0001 else Vector3.ZERO
	for bone in _bones:
		bone.linear_velocity = push
	_hips_start = _bones[0].global_position
	_elapsed = 0.0
	_running = true
	set_physics_process(true)
	started.emit()


## Keeps the pose the bones are in, stops the physics and takes the bones out of the world.
func freeze() -> void:
	if not _running:
		return
	_running = false
	set_physics_process(false)
	var poses := {}
	for bone in _bones:
		poses[bone.get_bone_id()] = _skeleton.global_transform.affine_inverse() * (bone.global_transform * bone.body_offset.affine_inverse())
	_simulator.physical_bones_stop_simulation()
	_simulator.process_mode = Node.PROCESS_MODE_DISABLED
	var ids := poses.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return _depth(a) < _depth(b))
	for id: int in ids:
		_skeleton.set_bone_global_pose(id, poses[id])
	froze.emit()


## Stands the model up again: no physics, the skeleton back to its rest pose for the clips to take over.
func reset() -> void:
	_running = false
	set_physics_process(false)
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
		_simulator.process_mode = Node.PROCESS_MODE_DISABLED
	if _skeleton != null:
		_skeleton.reset_bone_poses()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_hold_near_start()
	if _elapsed >= settle_s:
		freeze()


## The hips may not go farther than `max_drift_m` along the ground: whatever speed takes them out is taken away.
func _hold_near_start() -> void:
	var away := _bones[0].global_position - _hips_start
	away.y = 0.0
	if away.length() <= max_drift_m:
		return
	var out := away.normalized()
	for bone in _bones:
		var speed := bone.linear_velocity
		var outward := speed.dot(out)
		if outward > 0.0:
			bone.linear_velocity = speed - out * outward


func _depth(bone: int) -> int:
	var depth := 0
	var up := _skeleton.get_bone_parent(bone)
	while up >= 0:
		depth += 1
		up = _skeleton.get_bone_parent(up)
	return depth
