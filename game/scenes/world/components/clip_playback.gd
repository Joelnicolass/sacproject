@tool
class_name ClipPlayback
extends Node

## The contract of the node that plays the clips of a body by ROLE (idle, run, attack...): BodyAnimator (RFC-023 023c, RFC-036 036g).
## Afflictions, Stunned and the bodies talk to this and not to the animator, so a body can swap it. Presentation only:
## the simulation never reads it.

## The active clip went past its last frame and started again (RFC-028c). Emitted on the physics tick that wraps, on a
## client (the dedicated server plays no clips); the body picks the next variant from it.
signal clip_looped(role: String)

## F137 (RFC-030i-b): the pose holds (sacengine petrified, bone.d / state.d:11631-11640): the pose stops, play() does not
## switch the clip and the frame on the body stays. Set by its owner (Petrified) on every peer; off resumes from it.
var frozen := false:
	set(value):
		frozen = value
		_frozen_changed()


## A player that has a skeleton to hold hooks in here.
func _frozen_changed() -> void:
	pass


## Sets the model (its scene has the role -> clip mapping).
func setup(_model: String) -> void:
	pass


func play(_role: String, _restart := false) -> void:
	pass


## Plays `role` already on its last frame: a body that shows up after a one-shot clip ended (a corpse, RFC-023f).
func play_ended(role: String) -> void:
	play(role, true)


func active_role() -> String:
	return ""


## true while a skeleton (a BodyRig) is what draws the body; a static mesh answers false (RFC-023f: the corpse lets the
## clip lay it down only when it is a skeleton).
func is_skeletal() -> bool:
	return false


## True when this model has a playable clip (more than one frame) for `role`.
func has_role(_role: String) -> bool:
	return false


func active_tag() -> String:
	return ""


func active_framerate() -> int:
	return 0


func active_frame() -> int:
	return 0


func impact_frame() -> int:
	return -1
