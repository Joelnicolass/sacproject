@tool
class_name DoctorLook
extends Node

## What every peer shows of a Sac Doctor: the clip of its pose (and, while it works, of what it
## does) and the fade-out when it dies. It listens to `body.pose_changed`; it changes no state and
## the server (no meshes) draws nothing.
## What it does not do: move the body (DoctorMotor), keep the pose (DoctorBody) or play the clips
## itself (the ClipPlayback does).

## Seconds of the fade when the rules do not say (a doctor without `rules`).
const _DEFAULT_FADE_S := 2.0

@export var body: DoctorBody
@export var clip_player: ClipPlayback
@export var visual: BodyVisual

@export_group("Pose clips")
## Role of the BodyRig for each pose. A pose without a clip keeps the one it had. Falling holds the
## last frame of «expelled»; landing plays «hit floor» once and then idle.
@export var idle_clip := &"idle"
@export var falling_clip := &"fall"
@export var landing_clip := &"hit_floor"
@export var walking_clip := &"run"
@export var dying_clip := &"idle"

@export_group("Work clips")
## The rig has one state per role of BodyModel.ROLES and the doctor has no states of its own, so
## each work borrows the role closest to what it does.
@export var pump_clip := &"work"
@export var lift_clip := &"cast"
@export var torture_clip := &"attack"

var _fade: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body.pose_changed.connect(_on_pose_changed)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		out.append("Assign `body` (the DoctorBody shown).")
	if clip_player == null:
		out.append(
			"Assign `clip_player` (BodyAnimator): without it the doctor stays in a fixed pose."
		)
	if visual == null:
		out.append("Assign `visual` (BodyVisual): without it a dead doctor does not fade out.")
	return out


func _on_pose_changed(pose: DoctorBody.Pose, work: DoctorBody.Work) -> void:
	if not BodyLook.loads_meshes():
		return
	_play(pose, work)
	if pose == DoctorBody.Pose.DYING:
		_fade_out()


func _play(pose: DoctorBody.Pose, work: DoctorBody.Work) -> void:
	var role := _clip_of(pose, work)
	if clip_player != null and not role.is_empty():
		clip_player.play(role)


func _clip_of(pose: DoctorBody.Pose, work: DoctorBody.Work) -> String:
	match pose:
		DoctorBody.Pose.IDLE:
			return String(idle_clip)
		DoctorBody.Pose.FALLING:
			return String(falling_clip)
		DoctorBody.Pose.LANDING:
			return String(landing_clip)
		DoctorBody.Pose.WALKING:
			return String(walking_clip)
		DoctorBody.Pose.DYING:
			return String(dying_clip)
		DoctorBody.Pose.WORKING:
			match work:
				DoctorBody.Work.PUMP:
					return String(pump_clip)
				DoctorBody.Work.LIFT:
					return String(lift_clip)
				DoctorBody.Work.TORTURE:
					return String(torture_clip)
	return ""


## BodyVisual.set_fade fades the rig's meshes too (transparency does not inherit).
func _fade_out() -> void:
	if visual == null:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(
		visual.set_fade, 0.0, 1.0, body.rules.doctor_death_s if body.rules else _DEFAULT_FADE_S
	)
