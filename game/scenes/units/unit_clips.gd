class_name UnitClips
extends Node

## What a UnitBody shows: picks the clip each step (playing dead, held, captive, flight, then the role of the state of its mode), the
## pose scale, the lunge of a swing or a shot and the debug clip. Presentation only, on every peer.
## Not: what the creature does (States) nor when to update (the body, its modes and its forms ask `update`).

@export var body: UnitBody
@export var clip_pose: ClipPlayback
@export_group("Swing")
@export var lunge_back_deg := 6.0
@export var lunge_forward_deg := 10.0
@export var lunge_back_s := 0.3
@export var lunge_forward_s := 0.08
@export var lunge_recover_s := 0.25

## The clip role played in IDLE ("idle" = the CRE8 idle0): a calm peasant digs ("work"). A role the model has no clip for falls back to idle.
var idle_role := "idle":
	set(value):
		idle_role = value if not value.is_empty() else "idle"
		_update_if_ready()
## The clip role of a creature a Sac Doctor holds or revives (rise, held, thrash); CaptiveLook writes it on every peer. "" = none.
var captive_role := "":
	set(value):
		captive_role = value
		_update_if_ready()

var _debug_role := ""
var _lunge_tween: Tween


func _ready() -> void:
	if clip_pose != null:
		clip_pose.clip_looped.connect(looped)


## The clip to play now. The roles of Afflictions, Captive and Flight rule out the one of the mode.
func update() -> void:
	var state := body.current_state()
	if state == null:
		return
	var pivot := body.get_node_or_null("Tilt") as Node3D
	var want := state.pose_scale()
	if pivot != null and pivot.scale != want:
		pivot.scale = want
	var pose := clip_pose
	if pose == null or (body.mode == UnitBody.Mode.DEAD and body.corpse().clip_driven):
		return
	if not _debug_role.is_empty():
		pose.play(_debug_role)
		return
	var held_role := "idle" if body.special_forms.playing_dead else body.afflictions.pose_role(pose)
	if not held_role.is_empty():
		pose.play(held_role)
		return
	if not captive_role.is_empty() and has_clip(captive_role):
		pose.play(captive_role)
		return
	var flight_role := _flight_role()
	if not flight_role.is_empty() and has_clip(flight_role):
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
	_lunge_tween.tween_property(pivot, "rotation:x", -deg_to_rad(lunge_back_deg), lunge_back_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_property(pivot, "rotation:x", deg_to_rad(lunge_forward_deg), lunge_forward_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lunge_tween.tween_property(pivot, "rotation:x", 0.0, lunge_recover_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The attack is cancelled: the lunge stops and the pivot stands up.
func cancel_lunge() -> void:
	if _lunge_tween and _lunge_tween.is_valid():
		_lunge_tween.kill()
		(body.get_node("Tilt") as Node3D).rotation.x = 0.0


func has_clip(role: String) -> bool:
	return clip_pose != null and clip_pose.has_role(role)


## Bench: shows `role` whatever the mode says ("" = back to the modes).
func set_debug_role(role: String) -> void:
	_debug_role = role


func show_role(role: String) -> void:
	set_debug_role(role)
	update()


func info() -> Dictionary:
	var pose := clip_pose
	return {
		"role": pose.active_role() if pose else "",
		"tag": pose.active_tag() if pose else "",
		"frame": pose.active_frame() if pose else 0,
		"fps": pose.active_framerate() if pose else 0,
		"impact_frame": pose.impact_frame() if pose else -1,
	}


func _update_if_ready() -> void:
	if body != null and body.is_node_ready():
		update()


## The clip of the Flight state ("" on the ground).
func _flight_role() -> String:
	var flight := body.flight
	if flight == null or body.mode == UnitBody.Mode.DEAD:
		return ""
	match flight.state:
		Flight.State.TAKEOFF:
			return "takeoff"
		Flight.State.FLYING:
			return "hover" if body.mode == UnitBody.Mode.IDLE and has_clip("hover") else "fly"
		Flight.State.LANDING:
			return "land"
	return ""
