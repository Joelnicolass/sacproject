@tool
class_name ClipPlayback
extends Node

## The contract of the node that plays the clips of a body by ROLE (idle, run, attack...): the baked player of the
## per-frame meshes (ClipPosePlayer) and the skeletal one (BodyAnimator, RFC-023 023c). Afflictions, Stunned and the
## bodies talk to this and not to either, so a body can swap one for the other. Presentation only: the simulation
## never reads it.

## The active clip went past its last frame and started again (RFC-028c). Emitted on the physics tick that wraps,
## on every peer (the clip clock runs without meshes too); the body picks the next variant from it.
signal clip_looped(role: String)

## F137 (RFC-030i-b): the pose holds (sacengine petrified, bone.d / state.d:11631-11640): the clock stops, play() does not
## switch the clip and the frame on the body stays. Set by its owner (Petrified) on every peer; off resumes from it.
var frozen := false:
	set(value):
		frozen = value
		_frozen_changed()


## A player that has more to hold than its own clock (the skeleton, a baked player under it) hooks in here.
func _frozen_changed() -> void:
	pass


## Sets the model, its role -> clip tag map and the pose the body is drawn from.
func setup(_model: String, _role_to_tag: Dictionary, _mesh_base_pos: Vector3, _mesh_base_rot: Vector3) -> void:
	pass


func play(_role: String, _restart := false) -> void:
	pass


func active_role() -> String:
	return ""


## True when this model has a playable clip (more than one frame) for `role`.
func has_role(_role: String) -> bool:
	return false


## True when `model` has a playable clip (more than one frame) called `tag`, whatever the roles.
func has_clip(_model: String, _tag: String) -> bool:
	return false


func active_tag() -> String:
	return ""


func active_framerate() -> int:
	return 0


func active_frame() -> int:
	return 0


func impact_frame() -> int:
	return -1
