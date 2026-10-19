extends Node

## REVIEW-RFC-024d §2 (deuda de la capa de juego): ¿un mago HUMANO con escolta en guardia también queda encerrado?
## The local wizard (slot 1, solo) gets `escort_count` own creatures around him, ordered to guard him through Orders.request
## (the same call a human's order makes, «guard» on the wizard). Then he walks a series of legs with request_walk (the click on
## the ground), turning around between legs so the escort ends in front of him. Per leg: the ticks to arrive within `arrive_m`,
## the straight distance, the seconds he was «jammed» (walking and moving less than `jam_moved_m` in a window of `window_s`,
## the same test as AiWizardBrain._check_jam) and the longest jam. Headless it prints `ESCORT_JAM <json>` and quits.
##
##   godot --headless --path game --fixed-fps 60 res://debug/orders/escort_jam.tscn -- --count=8
##
## Options after `--`: count (escort size; 0 = control without escort), tag (creature tag), out (a .json path), trace.
## RFC-036 036f: the wizard is above his creatures in the avoidance (BodyAvoidance priority), so his own escort does not
## push him back: per leg `back_m` is the most he lost of the ground he had gained toward the goal; the report is `ok`
## when no leg goes back more than `back_max_m`.

const REPORT_TAG := "ESCORT_JAM "

@export var world: Node
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var status_label: Label

@export var escort_tag := "ycro"
@export var escort_count := 8
## The escort starts in a ring of this radius around the wizard.
@export var ring_m := 6.0
## Each leg: x = turn in degrees from the facing the wizard has at the start, y = meters to walk.
@export var legs: Array[Vector2] = [Vector2(0, 120), Vector2(180, 120), Vector2(90, 80), Vector2(270, 80), Vector2(180, 60), Vector2(0, 60)]
## A leg gives up after this many seconds.
@export var leg_timeout_s := 60.0
@export var arrive_m := 5.0
@export var window_s := 1.0
@export var jam_moved_m := 0.6
@export var settle_frames := 4
## The most (m) a leg may lose of the ground gained toward its goal.
@export var back_max_m := 1.0

var _args := {}
var _wizard: Node3D
var _escort: Array[Node3D] = []
var _forward := Vector3.FORWARD
var _origin := Vector3.ZERO
var _leg := -1
var _goal := Vector3.ZERO
var _leg_ticks := 0
var _window_ticks := 0
var _window_mark := Vector3.ZERO
var _jam_s := 0.0
var _jam_run_s := 0.0
var _jam_max_s := 0.0
var _results: Array = []
var _leg_start := Vector3.ZERO
var _min_left := INF
var _back_m := 0.0
var _running := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if _args.has("count"):
		escort_count = int(_args["count"])
	if _args.has("tag"):
		escort_tag = str(_args["tag"])
	world.local_wizard_changed.connect(func(_w: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _start() -> void:
	if _wizard != null:
		return
	_wizard = world.call("local_wizard")
	if _wizard == null:
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	_forward = _wizard.call("facing_flat")
	_origin = _wizard.global_position
	for i in escort_count:
		var angle := TAU * float(i) / maxf(1.0, float(escort_count))
		var at := _origin + Vector3(sin(angle), 0.0, cos(angle)) * ring_m
		_escort.append(_spawn(at, i + 1))
	for _frame in settle_frames:
		await get_tree().physics_frame
	if not _escort.is_empty():
		world.get_node("%Orders").call("request", _escort, "guard", _wizard.global_position, _wizard, atan2(_forward.x, _forward.z))
	print("escort_jam: %d %s en guardia del mago slot %d" % [escort_count, escort_tag, MpKit.local_slot()])
	_running = true
	_next_leg()


func _spawn(at: Vector3, serial: int) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.set("creature_tag", escort_tag)
	unit.name = "Escort%d" % serial
	unit.set("owner_slot", MpKit.local_slot())
	unit.set("idle_aggro", false)
	arena.add_child(unit)
	unit.global_position = at
	return unit


func _next_leg() -> void:
	_leg += 1
	if _leg >= legs.size():
		_finish()
		return
	var leg := legs[_leg]
	var dir := _forward.rotated(Vector3.UP, deg_to_rad(leg.x))
	_goal = _wizard.global_position + dir * leg.y
	_leg_ticks = 0
	_window_ticks = 0
	_window_mark = _wizard.global_position
	_jam_s = 0.0
	_jam_run_s = 0.0
	_jam_max_s = 0.0
	_leg_start = _wizard.global_position
	_min_left = INF
	_back_m = 0.0
	_wizard.call("request_walk", _goal)


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	_leg_ticks += 1
	_window_ticks += 1
	var tick_s := 1.0 / float(Engine.physics_ticks_per_second)
	if _window_ticks * tick_s >= window_s:
		var moved := _flat(_wizard.global_position, _window_mark)
		if bool(_wizard.call("is_walking")) and moved < jam_moved_m:
			_jam_s += window_s
			_jam_run_s += window_s
			_jam_max_s = maxf(_jam_max_s, _jam_run_s)
		else:
			_jam_run_s = 0.0
		_window_ticks = 0
		_window_mark = _wizard.global_position
		if _args.has("trace"):
			_trace()
	var left := _flat(_wizard.global_position, _goal)
	_min_left = minf(_min_left, left)
	_back_m = maxf(_back_m, left - _min_left)
	var arrived := left <= arrive_m
	var timeout := _leg_ticks * tick_s >= leg_timeout_s
	if arrived or timeout:
		_results.append({
			"leg": _leg, "turn_deg": legs[_leg].x, "meters": legs[_leg].y, "arrived": arrived,
			"seconds": snappedf(_leg_ticks * tick_s, 0.01), "left_m": snappedf(left, 0.1),
			"jam_s": _jam_s, "jam_max_s": _jam_max_s, "min_left_m": snappedf(_min_left, 0.1), "back_m": snappedf(_back_m, 0.01),
			"from": _fmt(_leg_start), "goal": _fmt(_goal), "end": _fmt(_wizard.global_position),
			"walking_end": bool(_wizard.call("is_walking")), "escort_within_8m": _escort_near(8.0),
		})
		_next_leg()
	if status_label != null:
		status_label.text = "Escolta %d · tramo %d · faltan %.0f m · trabado %.0f s" % [escort_count, _leg + 1, left, _jam_s]


func _finish() -> void:
	_running = false
	var total_s := 0.0
	var total_jam := 0.0
	var arrived := 0
	var back_worst := 0.0
	for row: Dictionary in _results:
		back_worst = maxf(back_worst, float(row["back_m"]))
		total_s += float(row["seconds"])
		total_jam += float(row["jam_s"])
		arrived += 1 if bool(row["arrived"]) else 0
	var report := {
		"escort": escort_count, "tag": escort_tag, "legs": _results, "arrived": arrived, "of": legs.size(),
		"total_s": snappedf(total_s, 0.01), "jam_s": total_jam, "back_worst_m": back_worst, "ok": back_worst <= back_max_m,
	}
	var text := JSON.stringify(report)
	print(REPORT_TAG + text)
	if _args.has("out"):
		var file := FileAccess.open(str(_args["out"]), FileAccess.WRITE)
		if file != null:
			file.store_string(text)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()


## --trace: once a window, the wizard (place, velocity, walking, next waypoint) and where his escort stands from him.
func _trace() -> void:
	var follower := _wizard.get_node_or_null("PathFollower")
	var near := []
	for unit in _escort:
		if is_instance_valid(unit):
			var rel := unit.global_position - _wizard.global_position
			near.append("%s(%.1f,%.1f %s)" % [unit.name, rel.x, rel.z, UnitBody.Mode.keys()[int(unit.get("mode"))]])
	print("trace leg %d t %.1f wiz %s vel %s walking %s next %s · %s" % [_leg, _leg_ticks / float(Engine.physics_ticks_per_second),
		_fmt(_wizard.global_position), _fmt((_wizard as CharacterBody3D).velocity), _wizard.call("is_walking"),
		_fmt(follower.call("next_point")) if follower != null else "-", " ".join(near)])


func _escort_near(radius: float) -> int:
	var n := 0
	for unit in _escort:
		if is_instance_valid(unit) and _flat(unit.global_position, _wizard.global_position) <= radius:
			n += 1
	return n


static func _fmt(v: Vector3) -> String:
	return "%.1f,%.1f" % [v.x, v.z]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
