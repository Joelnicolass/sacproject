class_name PathFollower
extends Node

## Turns "walk to this point" into waypoints (RFC-024 §3.1, 024b). A child of unit.tscn and wizard_body.tscn,
## it asks the world's NavService for the way around blockers and hands each leg to the body's
## begin_walk; the body still moves itself (CharacterBody3D, move_and_slide, collision). Take the node
## away and the body walks in a straight line, as before.
##
## go_to(goal)       an order: the body walks there by waypoints.
## steer_point(goal) a pursuit: the point a chasing body heads for this tick (the goal, or the next
##                   waypoint when the line to it is blocked). The caller moves.
##
## Waypoints are taken when the body comes within `advance_m` of them (sacengine pops a node within
## sqrt(2)*5 m, state.d:607), so the body never stops between legs. A path is rebuilt every `repath_s`
## when the line to the next waypoint is blocked or the body made no progress (sacengine repaths every
## 2 s, state.d:593). Runs where the body is simulated; all counts are physics ticks, so it is reproducible.

signal path_set(points: PackedVector3Array)
signal arrived

## The body to move: a UnitBody or a WizardBody (begin_walk / is_walking / walk_to).
@export var body: Node3D
## Seconds between checks of the way and the progress (sacengine: 2 s).
@export var repath_s := 2.0
## The final goal counts as reached this close (the body itself stops inside a step of it).
@export var arrive_m := 1.0
## A waypoint is taken when the body is this close to it.
@export var advance_m := 4.0
## Progress below this fraction of the expected distance in `repath_s` counts as stuck.
@export_range(0.0, 1.0) var stuck_fraction := 0.25
## Seconds between looks at the straight line of a pursuit.
@export var steer_check_s := 0.25
## A new goal within this distance of the one being walked to moves the last leg instead of searching again, when
## the line to it from the leg before is clear (the reuse `steer_point` makes: 2 cells). 0 = always search.
## The order layer repeats orders whose point drifts with a moving anchor (a follower behind its leader); searching
## again each time spent the search slots of the tick, and the bodies left without a slot walked straight into walls.
@export var retarget_m := 10.0

var active := false
var goal := Vector3.ZERO
var waypoints := PackedVector3Array()
## Counters for the probes.
var repaths := 0
var searches := 0

var _nav: NavService
var _waiting := false
var _check_left := 0.0
var _mark := Vector3.ZERO
var _steer_goal := Vector3.ZERO
var _steer_path := PackedVector3Array()
var _steer_left := 0.0
var _steer_age := 0.0


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not get_parent() is Node3D:
		warnings.append("Falta el cuerpo (body).")
	return warnings


func is_active() -> bool:
	return active


func cancel() -> void:
	active = false
	_waiting = false
	waypoints = PackedVector3Array()


## The next waypoint, or the goal when none is left.
func next_point() -> Vector3:
	return waypoints[0] if not waypoints.is_empty() else goal


## An order to walk to `goal`. The same goal while the walk goes on is a no-op (the order layer repeats it).
func go_to(target: Vector3) -> void:
	var same := active and Vector2(target.x, target.z).distance_to(Vector2(goal.x, goal.z)) < 0.5 and bool(body.call("is_walking"))
	if same:
		return
	if _retarget(target):
		return
	goal = target
	active = true
	_waiting = false
	_check_left = repath_s
	_mark = body.global_position
	_plan()


func _physics_process(delta: float) -> void:
	if _steer_left > 0.0:
		_steer_left -= delta
	_steer_age += delta
	if not active:
		return
	if not bool(body.call("is_walking")):
		var arrived_at_goal := _flat(body.global_position, goal) <= arrive_m
		cancel()
		if arrived_at_goal:
			arrived.emit()
		return
	if _waiting:
		_plan()
		return
	var here := body.global_position
	var changed := false
	while waypoints.size() > 1 and _may_advance(here):
		waypoints.remove_at(0)
		changed = true
	if changed:
		body.call("begin_walk", waypoints[0])
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = repath_s
	var pace := _pace()
	var moved := _flat(here, _mark)
	_mark = here
	var stuck := pace > 0.0 and moved < pace * repath_s * stuck_fraction
	var blocked := not waypoints.is_empty() and _nav_ready() and not _nav.line_clear(here, waypoints[0])
	if stuck or blocked:
		repaths += 1
		_plan()


## The body is done with waypoints[0]: within `advance_m` of it, unless the leg after it would go through a building
## (NavService.crosses_box, F88 round 2: the start node a path puts first beside a tipi); within `arrive_m` always, so the
## leg never ends under the body (a body at the end of its leg stops, and the order with it).
func _may_advance(here: Vector3) -> bool:
	var gap := _flat(here, waypoints[0])
	if gap > advance_m:
		return false
	return gap <= arrive_m or not _nav_ready() or not _nav.crosses_box(here, waypoints[1])


## A pursuit: where to head to reach `target` this tick. The goal itself while the line is clear (or there
## is no nav); otherwise the next waypoint of a path kept for `repath_s` and rebuilt when the target moved.
func steer_point(target: Vector3) -> Vector3:
	if not _nav_ready():
		return target
	var here := body.global_position
	if _steer_left > 0.0:
		if _steer_path.is_empty():
			return target
		if _flat(target, _steer_goal) < 2.0 * NavGrid.CELL_M:
			return _advance_steer(here, target)
	_steer_left = steer_check_s
	if _nav.line_clear(here, target):
		_steer_path = PackedVector3Array()
		return target
	var stale := _steer_path.is_empty() or _flat(target, _steer_goal) >= 2.0 * NavGrid.CELL_M or _steer_age >= repath_s
	if stale and _nav.take_search_slot():
		searches += 1
		_steer_path = _nav.find_path(here, target)
		_steer_goal = target
		_steer_age = 0.0
	return _advance_steer(here, target)


func _advance_steer(here: Vector3, target: Vector3) -> Vector3:
	while _steer_path.size() > 1 and _flat(here, _steer_path[0]) <= advance_m:
		_steer_path.remove_at(0)
	if _steer_path.is_empty():
		return target
	if _steer_path.size() == 1:
		return target
	return _steer_path[0]


## The walk goes on toward a goal close to `target`: the last leg goes to `target` if its line is clear. No search,
## and the progress check keeps its count (a stuck body still searches again after `repath_s`).
func _retarget(target: Vector3) -> bool:
	if retarget_m <= 0.0 or not active or _waiting or waypoints.is_empty() or not bool(body.call("is_walking")):
		return false
	if _flat(target, goal) >= retarget_m or not _nav_ready():
		return false
	var last := waypoints.size() - 1
	var from := waypoints[last - 1] if last > 0 else body.global_position
	if not _nav.line_clear(from, target):
		return false
	goal = target
	waypoints[last] = target
	if last == 0:
		body.call("begin_walk", target)
	return true


## Builds the waypoints from where the body stands now and starts the first leg.
func _plan() -> void:
	if not _nav_ready():
		waypoints = PackedVector3Array([goal])
		body.call("begin_walk", goal)
		return
	if not _nav.take_search_slot():
		# Too many searches this tick: go straight meanwhile, the path comes on a later tick.
		_waiting = true
		body.call("begin_walk", goal)
		return
	_waiting = false
	searches += 1
	waypoints = _nav.find_path(body.global_position, goal)
	if waypoints.is_empty():
		waypoints = PackedVector3Array([goal])
	path_set.emit(waypoints)
	body.call("begin_walk", waypoints[0])


func _nav_ready() -> bool:
	if _nav == null or not is_instance_valid(_nav):
		_nav = get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	return _nav != null and _nav.is_ready()


func _pace() -> float:
	var speed: Variant = body.get("move_speed")
	var factor: Variant = body.get("speed_factor")
	return (float(speed) if speed != null else 0.0) * (float(factor) if factor != null else 1.0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
