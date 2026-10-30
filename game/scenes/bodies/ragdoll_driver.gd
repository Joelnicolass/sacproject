class_name RagdollDriver
extends Node

## Lets a body fall, or hang, like a rag doll with the physical skeleton of its model
## (BodyModel.ragdoll). FALL throws the body a little away and after `settle_s` freezes the pose and
## stops the physics, so a field of corpses costs nothing. HANG leaves the hang bone out of the
## physics (it rides the frozen skeleton) and lets the rest dangle on wide cones. Bones only meet
## the terrain (layer 16, mask 1). It moves the model only (the simulation never reads it; a server
## mounts no model, so it never binds) and does not decide when.

## The ragdoll started to fall.
signal started
## The pose is frozen and the physics is off.
signal froze
## A model was bound or taken away; `available` says whether the body can fall as a rag doll now.
signal bound(available: bool)

enum Pose { OFF, FALL, HANG }

## The rig that mounts the model: when set, the driver binds the model by itself as soon as it is
## mounted.
@export var rig: BodyRig
## The clips of the body: held still while the pose is not OFF.
@export var clip_pose: ClipPlayback
@export_group("Fall")
## Speed the body is thrown away along the direction given to set_pose (meters per second).
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var push_back_m_s := 2.5
## Seconds the body may move; after this the pose is frozen and the physical skeleton stops.
@export_range(0.5, 10.0, 0.1, "suffix:s") var settle_s := 2.5
## How far from where it fell the hips may travel on the ground; past it the body is stopped.
@export_range(0.0, 5.0, 0.1, "suffix:m") var max_drift_m := 1.5
## How fast the bones lose speed (linear and spin): higher lies down sooner and slides less.
@export_range(0.0, 20.0, 0.1) var bone_damping := 1.5
@export_group("Hang")
## The same for a hanging body: higher swings less.
@export_range(0.0, 20.0, 0.1) var hang_damping := 4.0

var _pose := Pose.OFF
var _model: BodyModel
var _skeleton: Skeleton3D
var _simulator: PhysicalBoneSimulator3D
var _hang_bone: PhysicalBone3D
var _bones: Array[PhysicalBone3D] = []
var _elapsed := 0.0
var _hips_start := Vector3.ZERO
## The cone limits the model was baked with, put back whenever the bones do not hang.
var _spans := {}


func _ready() -> void:
	set_physics_process(false)
	if rig != null:
		rig.model_loaded.connect(func() -> void: bind_model(rig.model_root()))
		if rig.is_loaded():
			bind_model(rig.model_root())


## Takes the physical skeleton of `model` (null: lets go of it). The model it already has: nothing.
func bind_model(model: BodyModel) -> void:
	if model == _model:
		return
	_pose = Pose.OFF
	_halt()
	_model = model
	_skeleton = model.skeleton() if model != null else null
	_simulator = model.ragdoll_simulator() if model != null else null
	_hang_bone = model.hang_bone if model != null else null
	_bones = RagdollPose.bones_of(_simulator)
	_spans = RagdollPose.spans_of(_bones)
	bound.emit(available())


func available() -> bool:
	return _simulator != null and _skeleton != null and not _bones.is_empty()


func can_hang() -> bool:
	return available() and _hang_bone != null and _hang_bone in _bones


func pose() -> Pose:
	return _pose


## The bones are moving (a fall not settled yet, or a hang).
func is_running() -> bool:
	return is_physics_processing()


## Asks for a pose (the one it has: nothing; one the model cannot do: ignored). FALL from OFF throws
## the body along `push` (zero: it collapses); from HANG it lets go. OFF stands the model up in its
## rest pose for the clips to take over.
func set_pose(next: Pose, push := Vector3.ZERO) -> void:
	if (
		next == _pose
		or (next != Pose.OFF and not available())
		or (next == Pose.HANG and not can_hang())
	):
		return
	var from := _pose
	_pose = next
	if next == Pose.OFF:
		_halt()
		_skeleton.reset_bone_poses()
		return
	if from != Pose.HANG:
		_halt()
		if from == Pose.FALL:
			_skeleton.reset_bone_poses()
	_begin(next)
	RagdollPose.damp(_bones, hang_damping if next == Pose.HANG else bone_damping)
	if next == Pose.FALL:
		if from == Pose.OFF:
			RagdollPose.push(_bones, push, push_back_m_s)
		_hips_start = _bones[0].global_position
		_elapsed = 0.0
		started.emit()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _pose == Pose.HANG:
		return
	_elapsed += delta
	RagdollPose.brake(_bones, _hips_start, max_drift_m)
	if _elapsed >= settle_s:
		_settle()


## Holds the clips and turns the simulator on: every bone (FALL) or all but the hang bone (HANG),
## then rebuilds the joints.
func _begin(next: Pose) -> void:
	if clip_pose != null:
		clip_pose.frozen = true
	_simulator.process_mode = Node.PROCESS_MODE_INHERIT
	RagdollPose.start(_simulator, _skeleton, _spans, _hang_bone if next == Pose.HANG else null)


## Keeps the pose the bones ended in and stops the physics (the pose stays FALL).
func _settle() -> void:
	var poses := RagdollPose.capture(_skeleton, _bones)
	_stop_simulation()
	RagdollPose.apply(_skeleton, poses)
	froze.emit()


func _stop_simulation() -> void:
	set_physics_process(false)
	if _simulator != null:
		_simulator.physical_bones_stop_simulation()
		_simulator.process_mode = Node.PROCESS_MODE_DISABLED


## Physics off; with the pose OFF the clips are free.
func _halt() -> void:
	_stop_simulation()
	if clip_pose != null and _pose == Pose.OFF:
		clip_pose.frozen = false
