extends SceneTree

## Gives a model the physical skeleton its body falls with when it dies: a `PhysicalBoneSimulator3D` named "Ragdoll"
## under the model's Skeleton3D, with one `PhysicalBone3D` (a capsule along the bone) per bone that is long enough.
## Nothing else in scenes/bodies/models/<tag>.tscn is touched. Run it again and the old "Ragdoll" is replaced by a new one
## (so it is safe to repeat, and an edit made by hand inside "Ragdoll" is lost). RagdollDriver (scenes/units/) switches it
## on when the body dies; until then the simulator is disabled and costs nothing.
##
## How the bones are built (all numbers are the constants below):
##   - a bone gets a body when its segment (the distance to its children) is at least MIN_BONE_RATIO of the model's size;
##     a shorter bone rides on its parent. The segment of a bone with several children points to the middle of them.
##   - a short bone with a body somewhere below it still gets one, as short as the rule allows (a "link"): without it the
##     bodies below would hang free of the ones above (a Taurock's legs fell apart from its torso) and the skin weighted to
##     that bone would stay up in the air at the standing pose while the rest lay down.
##   - the capsule lies along the segment; the joint to the nearest bone above that has a body is a cone with limits.
##   - the model is drawn mirrored on z (BodyModel), and a physics body cannot be mirrored: each body carries the mirror in
##     its `body_offset` so it moves as a normal rigid body and the skin still follows.
##   - layer 16 ("ragdoll"), mask 1 (terrain only): bones never push units and never meet spells.
##
## Run:  Godot --headless --path . --script res://tools/bake/bake_ragdolls.gd -- [tag tag ...]
## Without tags it bakes the five models below (a humanoid, a quadruped, a small one, a big one and a flier).

## eorc: Trogg (a humanoid) · eber: Taurock (four legs) · FAmr: Familiar (small) · sogr: Storm Giant (big) · ehbt: Gargoyle (winged).
const DEFAULT_TAGS: PackedStringArray = ["eorc", "eber", "FAmr", "sogr", "ehbt"]
const SIMULATOR_NAME := "Ragdoll"
const BONE_LAYER := 16
const BONE_MASK := 1

## Shortest segment that gets a body, as a part of the model's largest size.
const MIN_BONE_RATIO := 0.06
## A bone with no children gets a segment of this part of its own length, at least MIN_BONE_RATIO.
const LEAF_RATIO := 0.35
## Capsule radius: a part of the segment, never thinner than this part of the model's size, never fatter than half the segment.
const RADIUS_PER_LENGTH := 0.22
const RADIUS_MIN_RATIO := 0.04
## Mass of a bone in kilograms per cubic meter of its capsule (only the ratios between bones matter).
const DENSITY := 800.0
const FRICTION := 0.8
## Cone limits in degrees: a joint of a hub bone (several children: hips, chest) is stiffer than a limb joint.
const SWING_LIMB_DEG := 55.0
const TWIST_LIMB_DEG := 35.0
const SWING_HUB_DEG := 28.0
const TWIST_HUB_DEG := 18.0
const EPSILON := 0.001


func _init() -> void:
	var tags := OS.get_cmdline_user_args()
	if tags.is_empty():
		tags = DEFAULT_TAGS
	var failed := 0
	for tag in tags:
		var count := _bake(tag)
		if count < 0:
			failed += 1
	quit(1 if failed > 0 else 0)


## Writes the physical skeleton of one model. Returns how many bodies it has, -1 when the model could not be baked.
func _bake(tag: String) -> int:
	var path := BodyModel.scene_path(tag)
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("bake_ragdolls: no scene %s" % path)
		return -1
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var found := root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		printerr("bake_ragdolls: %s has no Skeleton3D" % tag)
		root.free()
		return -1
	var skeleton := found[0] as Skeleton3D
	for old in skeleton.find_children(SIMULATOR_NAME, "PhysicalBoneSimulator3D", false, false):
		skeleton.remove_child(old)
		old.free()
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = SIMULATOR_NAME
	simulator.process_mode = Node.PROCESS_MODE_DISABLED
	skeleton.add_child(simulator)
	simulator.owner = root
	var count := _add_bones(skeleton, simulator, root)
	_open_instances(skeleton, root)
	var out := PackedScene.new()
	var saved := out.pack(root) == OK and ResourceSaver.save(out, path) == OK
	root.free()
	if not saved:
		printerr("bake_ragdolls: could not save %s" % path)
		return -1
	print("bake_ragdolls: %s -> %d bodies" % [tag, count])
	return count


func _add_bones(skeleton: Skeleton3D, simulator: PhysicalBoneSimulator3D, root: Node) -> int:
	var mirror := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, -1.0)), Vector3.ZERO)
	var mirrored := _world_basis(skeleton).determinant() < 0.0
	var offset := mirror if mirrored else Transform3D.IDENTITY
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
		var hub: bool = segment["hub"]
		if _has_parent_body(skeleton, bone, has_body):
			body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			body.joint_offset = Transform3D(Basis(Quaternion(Vector3.RIGHT, dir)), Vector3.ZERO)
			body.set("joint_constraints/swing_span", SWING_HUB_DEG if hub else SWING_LIMB_DEG)
			body.set("joint_constraints/twist_span", TWIST_HUB_DEG if hub else TWIST_LIMB_DEG)
		has_body[bone] = true
		count += 1
	return count


## A node added inside an instanced scene (the .glb) is only saved when the instance is "editable children".
func _open_instances(skeleton: Node, root: Node) -> void:
	var node := skeleton.get_parent()
	while node != null and node != root:
		if not node.scene_file_path.is_empty():
			root.set_editable_instance(node, true)
		node = node.get_parent()


## The capsule of a bone: its axis along `dir` (in the body's frame), from the bone's head to `length` ahead.
func _add_capsule(body: PhysicalBone3D, root: Node, dir: Vector3, length: float, radius: float) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Capsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0 + 0.01)
	shape.shape = capsule
	shape.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * length * 0.5)
	body.add_child(shape)
	shape.owner = root


## The bones that have a body of their own or one below them (all their ancestors): the links of the physical skeleton.
func _bones_over_bodies(skeleton: Skeleton3D, min_length: float) -> Dictionary:
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
func _segment(skeleton: Skeleton3D, bone: int, min_length: float, link: bool) -> Dictionary:
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
		for kid in kids:
			sum += kid
			if kid.length() > longest.length():
				longest = kid
		dir = (sum if sum.length() > longest.length() * 0.25 else longest).normalized()
		for kid in kids:
			length = maxf(length, kid.dot(dir))
	if length < min_length:
		if not link:
			return {}
		length = min_length
	return {"dir": dir, "length": length, "hub": kids.size() > 1}


func _has_parent_body(skeleton: Skeleton3D, bone: int, has_body: Dictionary) -> bool:
	var up := skeleton.get_bone_parent(bone)
	while up >= 0:
		if has_body.has(up):
			return true
		up = skeleton.get_bone_parent(up)
	return false


## The largest side of the box that holds the bone heads of the rest pose.
func _model_size(skeleton: Skeleton3D) -> float:
	var box := AABB(skeleton.get_bone_global_rest(0).origin, Vector3.ZERO)
	for bone in skeleton.get_bone_count():
		box = box.expand(skeleton.get_bone_global_rest(bone).origin)
	return maxf(box.get_longest_axis_size(), 0.1)


## The part of the transform of everything above the skeleton in the model scene (the mirror lives in there).
func _world_basis(skeleton: Skeleton3D) -> Basis:
	var basis := Basis.IDENTITY
	var node: Node = skeleton
	while node != null:
		if node is Node3D:
			basis = (node as Node3D).transform.basis * basis
		node = node.get_parent()
	return basis
