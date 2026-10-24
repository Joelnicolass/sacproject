@tool
class_name StuckGuard
extends Node

## Not in the original, which pushes until the doctor dies or the target stops being valid. Since 024d the
## carrying doctor walks by a PathFollower (DoctorBody.walk_to), but the ritual's doctors do not, and a path
## can still end against a body or an edge the grid does not know, where the doctor would hold its cargo forever.
## While the body walks, every `window_s` seconds it checks it got `progress_m` closer to the goal; if
## not it nudges the body sideways (alternating sides). After `rules.doctor_stuck_abort_s` seconds
## without progress it gives up: the body emits `stuck` and dies. Remove this node (or set the rule
## to 0) and the original behavior is back. Server only.

signal dodged
signal gave_up

@export var body: DoctorBody
## Meters closer to the goal that count as progress in a window.
@export var progress_m := 2.0
@export var window_s := 2.0
## Meters the body must move in a window while its errand wants it to walk.
@export var idle_move_m := 0.5
@export var dodge_deg := 90.0
@export var dodge_s := 1.0

var _best := INF
## The goal the progress is measured against: a PathFollower hands the body one leg after another (RFC-024 024d), and a leg that
## starts farther than the best distance of the last one is not «no progress»: it starts the measure again.
var _goal := Vector3.INF
var _window_left := 0.0
var _stuck_for := 0.0
var _side := 1.0
var _idle_mark := Vector3.INF
var _idle_left := 0.0
var _idle_for := 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or body == null or not body.is_inside_tree():
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_watch_idle(delta)
	if not body.is_walking() or not body.is_targetable():
		_reset()
		return
	if _goal == Vector3.INF or Vector2(_goal.x - body.goal.x, _goal.z - body.goal.z).length() > 0.5:
		_goal = body.goal
		_reset()
	var distance := Vector2(body.goal.x - body.global_position.x, body.goal.z - body.global_position.z).length()
	if _best == INF:
		_best = distance
		_window_left = window_s
	_window_left -= delta
	_stuck_for += delta
	if _best - distance >= progress_m:
		_best = distance
		_window_left = window_s
		_stuck_for = 0.0
	elif _window_left <= 0.0:
		_window_left = window_s
		_dodge()
	var limit := body.rules.doctor_stuck_abort_s if body.rules else 0.0
	if limit > 0.0 and _stuck_for >= limit:
		gave_up.emit()
		_reset()
		body.give_up()


## `body.errand_walks`: the errand wants the body to walk: every window it must have moved `idle_move_m`; else it sidesteps, and after the
## abort time of the rules it gives up, as a walk that makes no progress does.
func _watch_idle(delta: float) -> void:
	if not body.errand_walks or not body.is_targetable():
		_idle_mark = Vector3.INF
		_idle_for = 0.0
		return
	if _idle_mark == Vector3.INF:
		_idle_mark = body.global_position
		_idle_left = window_s
		_idle_for = 0.0
	_idle_left -= delta
	if _idle_left > 0.0:
		return
	_idle_left = window_s
	var moved := Vector2(body.global_position.x - _idle_mark.x, body.global_position.z - _idle_mark.z).length()
	_idle_mark = body.global_position
	if moved >= idle_move_m:
		_idle_for = 0.0
		return
	_idle_for += window_s
	_dodge()
	var limit := body.rules.doctor_stuck_abort_s if body.rules else 0.0
	if limit > 0.0 and _idle_for >= limit:
		gave_up.emit()
		_idle_mark = Vector3.INF
		_idle_for = 0.0
		body.give_up()


func _dodge() -> void:
	_side = -_side
	body.dodge_angle = deg_to_rad(dodge_deg) * _side
	body.dodge_left = dodge_s
	dodged.emit()


func _reset() -> void:
	_best = INF
	_stuck_for = 0.0
	_window_left = 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		out.append("Asigná `body` (el DoctorBody que vigila).")
	return out
