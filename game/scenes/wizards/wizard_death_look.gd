class_name WizardDeathLook
extends Node

## How a wizard's body lies after it dies: it falls as a rag doll (RagdollDriver, the physical skeleton baked into the model by
## tools/bake/bake_ragdolls.gd) and stands again, ready for the ghost, when GhostForm asks. A model with no physical skeleton
## (or a dedicated server, which draws nothing) just stays as it is. It only moves the model: the body, its collision and the
## stages of GhostForm stay where the simulation put them. GhostForm decides when to fall, fade and stand.
## Presentation only: nothing in the simulation reads it.

## The wizard's body: the rag doll is thrown away from where it faces.
@export var body: Node3D
## The model that is drawn.
@export var visual: BodyVisual
## Plays the clips; frozen while the body lies so no clip fights the physics.
@export var clip_pose: ClipPlayback
## The physical skeleton of the model.
@export var ragdoll: RagdollDriver

var _lying := false


## The body falls. True when it does (the model has a physical skeleton).
func fall() -> bool:
	if _lying:
		return true
	var skeleton := visual.rig.skeleton() if visual != null and visual.rig != null else null
	if skeleton == null or not ragdoll.bind(skeleton):
		return false
	clip_pose.frozen = true
	_lying = true
	ragdoll.start(-Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, body.rotation.y))
	return true


func is_lying() -> bool:
	return _lying


## The body stands up in its idle pose. Does nothing when it does not lie.
func stand() -> void:
	if not _lying:
		return
	_lying = false
	ragdoll.reset()
	clip_pose.frozen = false
	clip_pose.play("idle", true)


## The rise of a body that lies: the first half of `seconds` fades the corpse out (`set_transparency` goes from `from` to
## 1), then the body stands where it is and the second half fades it in to `to` (the ghost). One body the whole time.
## Returns the tween (GhostForm kills it if the stage changes).
func rise(set_transparency: Callable, from: float, to: float, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_method(set_transparency, from, 1.0, seconds * 0.5)
	tween.tween_callback(stand)
	tween.tween_method(set_transparency, 1.0, to, seconds * 0.5)
	return tween


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for socket in ["body", "visual", "clip_pose", "ragdoll"]:
		if get(socket) == null:
			warnings.append("Assign `%s`." % socket)
	return warnings
