class_name AnimSampler
extends RefCounted

## Debug: poses one clip of a model's .glb without a scene tree, and measures how much its bones move. It composes the
## bone chain by hand from the clip's position and rotation tracks (a bone with no track keeps its rest pose), so it works
## headless, where the AnimationPlayer and the meshes are inert. It only reads: it never changes a model or a clip.

## Clip sampling rate (the original's clips are 30 fps).
const FPS := 30.0
## Frames sampled per clip at most (the first and the last are always among them).
const MAX_SAMPLES := 36

var _skeleton: Skeleton3D
var _animation: Animation
var _custom := false
var _pos: Dictionary = {}
var _rot: Dictionary = {}


## `custom`: the clip comes from a model of assets/custom (RFC-051), whose Animation lasts frames / 30 s (the original's
## last (frames - 1) / 30 s).
func _init(skeleton: Skeleton3D, animation: Animation, custom := false) -> void:
	_skeleton = skeleton
	_animation = animation
	_custom = custom
	for track in animation.get_track_count():
		var kind := animation.track_get_type(track)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D:
			continue
		var bone := skeleton.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
		if bone >= 0:
			(_pos if kind == Animation.TYPE_POSITION_3D else _rot)[bone] = track


## Frames of the clip: the original shows `frames` frames, the Animation lasts (frames - 1) / 30 s.
func frames() -> int:
	return roundi(_animation.length * FPS) + (0 if _custom else 1)


## Model-space position of every bone at `frame`.
func pose(frame: int) -> PackedVector3Array:
	var t := minf(float(frame) / FPS, _animation.length)
	var count := _skeleton.get_bone_count()
	var global: Array[Transform3D] = []
	global.resize(count)
	var out := PackedVector3Array()
	out.resize(count)
	for bone in count:
		var rest := _skeleton.get_bone_rest(bone)
		var origin := rest.origin
		var turn := rest.basis.get_rotation_quaternion()
		if _pos.has(bone):
			origin = _animation.position_track_interpolate(_pos[bone], t)
		if _rot.has(bone):
			turn = _animation.rotation_track_interpolate(_rot[bone], t)
		var local := Transform3D(Basis(turn).scaled(rest.basis.get_scale()), origin)
		var parent := _skeleton.get_bone_parent(bone)
		global[bone] = local if parent < 0 else global[parent] * local
		out[bone] = global[bone].origin
	return out


## {"motion", "seam", "step", "slide", "finite"} in meters: the most a bone gets away from its first-frame place, the most
## it jumps between the last frame and the first (the wrap of a loop), the most it moves between two consecutive frames, the
## most the root or the hip gets away on the ground (`slide`) and how far they are from where they began on the last frame
## (`net`; `up` is the model's vertical in skeleton space), and whether every sampled position is a real number.
func measure(up: Vector3) -> Dictionary:
	var total := frames()
	var picks: Array[int] = []
	var stride := maxf(1.0, float(total - 1) / float(MAX_SAMPLES - 1))
	var at := 0.0
	while int(roundf(at)) < total - 1:
		picks.append(int(roundf(at)))
		at += stride
	picks.append(total - 1)
	var first := pose(picks[0])
	var out := {"motion": 0.0, "seam": 0.0, "step": 0.0, "slide": 0.0, "net": 0.0, "finite": true}
	var trunk: Array[int] = []
	for root in _skeleton.get_parentless_bones():
		trunk.append(root)
		trunk.append_array(_skeleton.get_bone_children(root).slice(0, 1))
		break
	var before := first
	var before_frame := picks[0]
	for pick in picks:
		var now := pose(pick)
		var gap := maxf(1.0, float(pick - before_frame))
		for bone in now.size():
			if not now[bone].is_finite():
				out["finite"] = false
				continue
			out["motion"] = maxf(float(out["motion"]), now[bone].distance_to(first[bone]))
			out["step"] = maxf(float(out["step"]), now[bone].distance_to(before[bone]) / gap)
		for bone in trunk:
			var away := now[bone] - first[bone]
			out["slide"] = maxf(float(out["slide"]), (away - up * away.dot(up)).length())
		before = now
		before_frame = pick
	for bone in trunk:
		var gone := before[bone] - first[bone]
		out["net"] = maxf(float(out["net"]), (gone - up * gone.dot(up)).length())
	for bone in first.size():
		out["seam"] = maxf(float(out["seam"]), before[bone].distance_to(first[bone]))
	return out


## True when every key of every position, rotation and scale track is a real number.
func keys_finite() -> bool:
	for track in _animation.get_track_count():
		var kind := _animation.track_get_type(track)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		for key in _animation.track_get_key_count(track):
			var value: Variant = _animation.track_get_key_value(track, key)
			if (value is Vector3 and not (value as Vector3).is_finite()) or (value is Quaternion and not (value as Quaternion).is_finite()):
				return false
	return true
