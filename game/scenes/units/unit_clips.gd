class_name UnitClips
extends Node

## RFC-036 036j follow-up: what a UnitBody shows. Picks the clip of the body each step (held, captive, flight, then the
## role of the state of its mode), the pose scale, the swing lunge and the debug clip. Presentation only, on every peer.

@export var body: UnitBody

var _debug_role := ""
var _lunge_tween: Tween


## The clip to play now. The roles of Afflictions, Captive and Flight rule out the one of the mode.
func update() -> void:
	var state := body.current_state()
	if state == null:
		return
	var pivot := body.get_node_or_null("Tilt") as Node3D
	var want := state.pose_scale()
	if pivot != null and pivot.scale != want:
		pivot.scale = want
	var pose := body.clip_pose
	if pose == null or (body.mode == UnitBody.Mode.DEAD and (body.get_node("Corpse") as Corpse).clip_driven):
		return
	if not _debug_role.is_empty():
		pose.play(_debug_role)
		return
	var held_role := "idle" if body.is_playing_dead() else body.afflictions.pose_role(pose)
	if not held_role.is_empty():
		pose.play(held_role)
		return
	var captive := body.captive_role
	if not captive.is_empty() and body.has_clip(captive):
		pose.play(captive)
		return
	var flight_role := _flight_role()
	if not flight_role.is_empty() and body.has_clip(flight_role):
		pose.play(flight_role)
		return
	pose.play(state.clip_role())


## A clip looped: the state of the mode decides what plays next (the idle gesture, the talk-cower).
func looped(role: String) -> void:
	var state := body.current_state()
	if state != null and state.on_clip_looped(role):
		update()


## The forward lunge of a swing or a shot (BodyTilt of the Tilt pivot).
func lunge() -> void:
	var pivot := body.get_node_or_null("Tilt") as Node3D
	if pivot == null or body.mode == UnitBody.Mode.DEAD:
		return
	if _lunge_tween:
		_lunge_tween.kill()
	pivot.rotation.x = 0.0
	_lunge_tween = pivot.create_tween()
	_lunge_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_lunge_tween.tween_property(pivot, "rotation:x", -deg_to_rad(body.lunge_back_deg), body.lunge_back_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_property(pivot, "rotation:x", deg_to_rad(body.lunge_forward_deg), body.lunge_forward_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lunge_tween.tween_property(pivot, "rotation:x", 0.0, body.lunge_recover_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The attack is cancelled: the lunge stops and the pivot stands up.
func cancel_lunge() -> void:
	if _lunge_tween and _lunge_tween.is_valid():
		_lunge_tween.kill()
		(body.get_node("Tilt") as Node3D).rotation.x = 0.0


func set_debug_role(role: String) -> void:
	_debug_role = role


func info() -> Dictionary:
	var pose := body.clip_pose
	return {
		"role": pose.active_role() if pose else "",
		"tag": pose.active_tag() if pose else "",
		"frame": pose.active_frame() if pose else 0,
		"fps": pose.active_framerate() if pose else 0,
		"impact_frame": pose.impact_frame() if pose else -1,
	}


## F116: the clip of the Flight state ("" on the ground).
func _flight_role() -> String:
	var flight := body.flight
	if flight == null or body.mode == UnitBody.Mode.DEAD:
		return ""
	match flight.state:
		Flight.State.TAKEOFF:
			return "takeoff"
		Flight.State.FLYING:
			return "hover" if body.mode == UnitBody.Mode.IDLE and body.has_clip("hover") else "fly"
		Flight.State.LANDING:
			return "land"
	return ""
