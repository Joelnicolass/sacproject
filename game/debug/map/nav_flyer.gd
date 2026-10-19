extends Node

## RFC-035 035g case (headless): a flier is ordered across the map over the central manafount, the same walk as debug/map/nav_cross.tscn.
## It must not ask for a path: a flier goes in a straight line (UnitBody._flies_to drops the waypoints) whatever the NavService
## answers. PASS: it arrives within `ARRIVE_M` of the goal before `LIMIT_S`, its PathFollower never planned (searches 0) and is
## not active, the NavService answered no search while it flew, it never left the straight line by more than `LATERAL_M`, and that
## line really goes through a manafount (else the case proves nothing). Prints `nav_flyer: PASS|FAIL {json}` and quits.
## Run: Godot --headless --fixed-fps 60 --path game res://debug/map/nav_flyer.tscn

const ARRIVE_M := 6.0
const LIMIT_S := 60.0
const LATERAL_M := 4.0
## The straight line passes this close (m) to a manafount's center: through its collision.
const THROUGH_M := 5.0
const SETTLE_TICKS := 10

@export var flyer: Node3D
@export var goal: Node3D
@export var quit_when_done := true

var _ticks := 0
var _order_tick := -1
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _searches_before := 0
var _worst_lateral := 0.0
var _through_m := INF
var _done := false


func _get_configuration_warnings() -> PackedStringArray:
	if flyer == null or goal == null:
		return PackedStringArray(["Asigná flyer y goal."])
	return PackedStringArray()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_ticks += 1
	var nav := get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if _order_tick < 0:
		if _ticks >= SETTLE_TICKS and nav != null and nav.is_ready():
			_order(nav)
		return
	var at := flyer.global_position
	_worst_lateral = maxf(_worst_lateral, _segment_distance(Vector2(at.x, at.z), Vector2(_from.x, _from.z), Vector2(_to.x, _to.z)))
	var left := Vector2(at.x - _to.x, at.z - _to.z).length()
	var seconds := float(_ticks - _order_tick) / float(Engine.physics_ticks_per_second)
	if left <= ARRIVE_M or seconds >= LIMIT_S:
		_finish(nav, left, seconds)


func _order(nav: NavService) -> void:
	_order_tick = _ticks
	_from = flyer.global_position
	_to = goal.global_position
	_searches_before = nav.searches
	for fount in get_tree().get_nodes_in_group("manafount"):
		var at := (fount as Node3D).global_position
		_through_m = minf(_through_m, _segment_distance(Vector2(at.x, at.z), Vector2(_from.x, _from.z), Vector2(_to.x, _to.z)))
	flyer.call("walk_to", _to)


func _finish(nav: NavService, left: float, seconds: float) -> void:
	_done = true
	var follower := flyer.get_node_or_null("PathFollower")
	var planned := int(follower.get("searches")) if follower != null else 0
	var active := bool(follower.call("is_active")) if follower != null else false
	var checks := {
		"arrived": left <= ARRIVE_M,
		"never_planned": planned == 0 and not active,
		"no_search": nav.searches == _searches_before,
		"straight": _worst_lateral <= LATERAL_M,
		"line_crosses_fount": _through_m <= THROUGH_M,
	}
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	var report := {"checks": checks, "left_m": snappedf(left, 0.01), "seconds": snappedf(seconds, 0.01), "worst_lateral_m": snappedf(_worst_lateral, 0.01),
			"fount_m": snappedf(_through_m, 0.01)}
	print("nav_flyer: %s %s" % ["PASS" if ok else "FAIL", JSON.stringify(report)])
	if quit_when_done:
		get_tree().quit(0 if ok else 1)


static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)
