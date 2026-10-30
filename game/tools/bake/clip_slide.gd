class_name ClipSlide
extends RefCounted

## How far a clip moves the body on the ground. Reads an Animation of a model's .glb AnimationPlayer
## and returns the most the root bone, or its first child (the hip), gets away from where it was on
## the clip's first frame, in X and Z of the skeleton (Y is up: a breath or a crouch does not
## count). A rest gesture that slides the root reads as a step on the spot. Static, no state; it
## does not need the scene in the tree.

## Clip sampling rate (the original's clips are 30 fps).
const SAMPLE_FPS := 30.0


## {"slide": meters (max of root and hip), "root": meters, "hip": meters, "span": Vector3 (root, per
## axis)}.
static func measure(
	player: AnimationPlayer, skeleton: Skeleton3D, animation: Animation
) -> Dictionary:
	var out := {"slide": 0.0, "root": 0.0, "hip": 0.0, "span": Vector3.ZERO}
	var roots := skeleton.get_parentless_bones()
	if roots.is_empty() or animation == null:
		return out
	var base := String(player.get_node(player.root_node).get_path_to(skeleton))
	var root_bone := roots[0]
	var children := skeleton.get_bone_children(root_bone)
	var hip := children[0] if not children.is_empty() else -1
	var start_root := Vector3.ZERO
	var start_hip := Vector3.ZERO
	var worst_root := 0.0
	var worst_hip := 0.0
	var span := Vector3.ZERO
	var steps := maxi(1, int(ceil(animation.length * SAMPLE_FPS)))
	for i in steps + 1:
		var t := minf(animation.length, float(i) / SAMPLE_FPS)
		var root_pos := _position(animation, base, skeleton, root_bone, t)
		var hip_pos := root_pos
		if hip >= 0:
			hip_pos = (
				root_pos
				+ (
					_rotation(animation, base, skeleton, root_bone, t)
					* _position(animation, base, skeleton, hip, t)
				)
			)
		if i == 0:
			start_root = root_pos
			start_hip = hip_pos
		worst_root = maxf(
			worst_root, Vector2(root_pos.x - start_root.x, root_pos.z - start_root.z).length()
		)
		worst_hip = maxf(
			worst_hip, Vector2(hip_pos.x - start_hip.x, hip_pos.z - start_hip.z).length()
		)
		span = span.max((root_pos - start_root).abs())
	out["root"] = worst_root
	out["hip"] = worst_hip
	out["slide"] = maxf(worst_root, worst_hip)
	out["span"] = span
	return out


## The skeleton and the clip player of a model instance (a BodyModel or a bare .glb): [player,
## skeleton], or [] without them.
static func rig_of(model_root: Node) -> Array:
	var players := model_root.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model_root.find_children("*", "Skeleton3D", true, false)
	# A BodyModel also has a Clips player (the library by role): the one inside the Model, the
	# .glb's own, comes first in the tree.
	for node in players:
		var player := node as AnimationPlayer
		if (
			not skeletons.is_empty()
			and player.has_node(player.root_node)
			and player.get_node(player.root_node).is_ancestor_of(skeletons[0])
		):
			return [player, skeletons[0]]
	return []


static func _position(
	animation: Animation, base: String, skeleton: Skeleton3D, bone: int, t: float
) -> Vector3:
	var track := animation.find_track(
		NodePath("%s:%s" % [base, skeleton.get_bone_name(bone)]), Animation.TYPE_POSITION_3D
	)
	return (
		animation.position_track_interpolate(track, t)
		if track >= 0
		else skeleton.get_bone_rest(bone).origin
	)


static func _rotation(
	animation: Animation, base: String, skeleton: Skeleton3D, bone: int, t: float
) -> Quaternion:
	var track := animation.find_track(
		NodePath("%s:%s" % [base, skeleton.get_bone_name(bone)]), Animation.TYPE_ROTATION_3D
	)
	return (
		animation.rotation_track_interpolate(track, t)
		if track >= 0
		else skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	)
