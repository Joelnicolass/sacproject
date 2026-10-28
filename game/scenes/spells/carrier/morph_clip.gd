@tool
class_name MorphClip
extends Resource

## One animation of a model whose frames are blend shapes (MorphModel): the poses it goes through,
## one after another, each for `pose_s`, blending from one to the next. A type template: never
## edited at runtime.

@export var id: StringName = &""
## The frames of the glb in order (0 is the mesh as it stands; 1 and up are the blend shapes f1,
## f2…).
@export var poses := PackedInt32Array()
@export_range(0.005, 5.0, 0.005, "suffix:s") var pose_s := 0.2
## It goes round again after the last pose (the last blends into the first). Off: it stops on the
## last pose, or goes to `next`.
@export var loop := true
## The clip that follows when this one (not a loop) ends.
@export var next: StringName = &""
## A shader parameter `reveal` of the model goes from x to y over the clip (x < 0: it is left
## alone).
@export var reveal := Vector2(-1.0, -1.0)


func duration_s() -> float:
	return pose_s * float(poses.size())


## Where the clip is `seconds` after it started: [from pose, to pose, blend 0..1, finished].
func at(seconds: float) -> Array:
	if poses.is_empty():
		return [0, 0, 0.0, true]
	var count := poses.size()
	var position := seconds / pose_s
	if loop:
		position = fposmod(position, float(count))
	elif position >= float(count - 1):
		return [poses[count - 1], poses[count - 1], 0.0, position >= float(count)]
	var index := int(floor(position))
	return [poses[index % count], poses[(index + 1) % count], position - float(index), false]
