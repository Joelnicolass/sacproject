class_name WizardClips
extends Node

## What a wizard shows: picks the clip each step (held, cast or cast-while-running, run, the idle
## gesture, idle) from its flat speed. The server (or solo) gives it the velocity of the step that
## ended (`update`); a client samples how far the drawn body moved each frame (`present`).
## Presentation only, on every peer.
## Not: how the wizard moves (Drive) nor when to update (the body asks).

@export var body: WizardBody
@export var clip_pose: ClipPlayback
## The cast in progress as every peer sees it (`is_casting()` reads the replicated `cast_fx_shown`
## on a client).
@export var caster: Caster
## The one owner of «held» (stunned, petrified): its pose role rules out the others.
@export var afflictions: Afflictions
@export var ghost: GhostForm
## Above this flat speed the wizard runs; at or below it, it stands.
@export_range(0.0, 5.0, 0.01, "suffix:m/s") var moving_above_m_s := 0.1
## One rest loop in this many ends in the idle gesture, the same on every peer (the units do the
## same).
@export_range(1, 50) var gesture_every := 5
@export_group("Client sampling")
## The sampled speed is capped at this many times the wizard's pace (a snap is not a sprint).
@export_range(1.0, 5.0, 0.01, "suffix:x pace") var sampled_cap := 1.6
## How fast the drawn speed rises toward a faster sample (fraction per second, 1 frame = all).
@export_range(0.0, 120.0, 0.1, "suffix:/s") var rise_per_s := 20.0
## How fast the drawn speed falls toward a slower sample (fraction per second).
@export_range(0.0, 120.0, 0.1, "suffix:/s") var fall_per_s := 6.0

var _prev_pos := Vector3.ZERO
var _prev_ready := false
var _sampled_speed := 0.0
var _idle_loops := 0
var _gesturing := false
## The speed the last `update` saw (a gesture that ends re-picks the pose with it).
var _flat_speed := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	if body == null or clip_pose == null or caster == null or afflictions == null or ghost == null:
		return PackedStringArray(["Assign body, clip_pose, caster, afflictions and ghost."])
	return PackedStringArray()


func _ready() -> void:
	if body == null or clip_pose == null or caster == null or afflictions == null or ghost == null:
		push_error("WizardClips: assign body, clip_pose, caster, afflictions and ghost.")
		return
	clip_pose.clip_looped.connect(_on_clip_looped)
	_prev_pos = body.global_position
	_prev_ready = true


## A client, once per frame: the speed comes from how far the drawn body moved, rising fast and
## falling slowly so a late snapshot does not flicker the run.
func present(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _prev_ready:
		_prev_pos = body.global_position
		_prev_ready = true
		return
	var from := _prev_pos
	var to := body.global_position
	_prev_pos = to
	var flat_delta := Vector2(to.x - from.x, to.z - from.z).length()
	var pace := maxf(body.move_speed * body.speed_factor * ghost.speed_factor(), 0.001)
	var sampled := clampf(flat_delta / delta, 0.0, pace * sampled_cap)
	var rate := rise_per_s if sampled >= _sampled_speed else fall_per_s
	_sampled_speed = lerpf(_sampled_speed, sampled, clampf(delta * rate, 0.0, 1.0))
	update(_sampled_speed)


## The clip for this flat speed (m/s). Held rules out the rest; a cast loops while the Caster casts,
## standing or walking.
func update(flat_speed: float) -> void:
	_flat_speed = flat_speed
	var held_role := afflictions.pose_role(clip_pose)
	if not held_role.is_empty():
		clip_pose.play(held_role)
		return
	var moving := flat_speed > moving_above_m_s and ghost.can_move()
	if caster.is_casting():
		_gesturing = false
		clip_pose.play("cast_run" if moving else "cast")
		return
	if moving:
		_gesturing = false
	elif _gesturing and clip_pose.has_role("gesture"):
		clip_pose.play("gesture")
		return
	clip_pose.play("run" if moving else "idle")


## A rest loop ended: a gesture is rolled after each stance loop, (hash(name) + loops) %
## `gesture_every`, the same on every peer and every run. The gesture ends and the body goes back to
## the rest pose.
func _on_clip_looped(role: String) -> void:
	if role != "idle" and role != "gesture":
		return
	_idle_loops += 1
	_gesturing = (
		role == "idle"
		and posmod(hash(String(body.name)) + _idle_loops, gesture_every) == 0
		and clip_pose.has_role("gesture")
	)
	update(_flat_speed)
