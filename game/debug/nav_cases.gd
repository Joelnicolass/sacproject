extends RefCounted

## RFC-024 024b cases of rules_suite: the NavGrid built from the real terrain with one manafount-like
## blocker at the center of the map, its cost, the path around the blocker and what it answers for points
## the land does not hold. `run(host)` adds the terrain and a NavService under `host` and removes them at
## the end. Times are wall clock (the RFC asks 300 ms for the grid and 5 ms for a corner-to-corner path).

const TERRAIN_SCRIPT := preload("res://scenes/world/terrain.gd")
const FOUNT_AT := Vector3(1270.0, 10.0, 1270.0)
const FOUNT_RADIUS := 3.6
const START1 := Vector3(1504.9, 17.0, 1540.5)
const START2 := Vector3(1037.7, 15.0, 1009.9)
const GRID_MS := 300.0
const PATH_US := 5000

var _root: Node3D
var _service: NavService
var _terrain: MeshInstance3D


func run(host: Node3D) -> Dictionary:
	_root = Node3D.new()
	_root.name = "NavCases"
	_terrain = MeshInstance3D.new()
	_terrain.name = "Terrain"
	_terrain.set_script(TERRAIN_SCRIPT)
	_root.add_child(_terrain)
	var fount := StaticBody3D.new()
	fount.name = "FakeFount"
	fount.add_to_group("manafount")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = FOUNT_RADIUS
	cylinder.height = 4.0
	shape.shape = cylinder
	fount.add_child(shape)
	fount.position = FOUNT_AT
	_root.add_child(fount)
	_service = NavService.new()
	_service.name = "Nav"
	_service.terrain = _terrain
	_service.build_on_ready = false
	_root.add_child(_service)
	host.add_child(_root)
	var out := {}
	if not _terrain.has_ground_data():
		var missing := {"ok": false, "reason": "sin terreno (assets/original/maps/high_noon/terrain.res)"}
		_root.free()
		return {"nav_grid_build": missing}
	_service.build()
	out["nav_grid_build"] = _build()
	out["nav_blocker_blocks"] = _blocker()
	out["nav_path_around"] = _around()
	out["nav_path_corner_to_corner"] = _corner()
	out["nav_regions"] = _regions()
	out["nav_goal_off_land"] = _off_land()
	out["nav_line_clear"] = _line_clear()
	out["nav_box_corner"] = _box_corner()
	_root.free()
	return out


func _build() -> Dictionary:
	var grid := _service.grid
	var checks := {
		"built": grid.built,
		"ms_under_300": grid.build_ms <= GRID_MS,
		"has_land": grid.free_count > 5000 and grid.free_count < 60000,
		"regions": grid.component_count >= 1,
	}
	return _verdict(checks, {"build_ms": grid.build_ms, "free": grid.free_count, "regions": grid.component_count})


## The blocker's nodes (its radius plus the 1.5 m margin) are blocked, those 25 m away are not.
func _blocker() -> Dictionary:
	var grid := _service.grid
	var center := NavGrid.node_of(FOUNT_AT)
	var checks := {
		"center": not grid.is_free_node(center.x, center.y),
		"east": not grid.is_free_node(center.x + 1, center.y),
		"west": not grid.is_free_node(center.x - 1, center.y),
		"far": grid.is_free_node(center.x + 5, center.y) or grid.is_free_node(center.x - 5, center.y) or grid.is_free_node(center.x, center.y + 5),
	}
	return _verdict(checks, {})


## Across the blocker: the path bends around it, never goes through it and is not much longer than needed.
func _around() -> Dictionary:
	var from := FOUNT_AT + Vector3(-40.0, 0.0, 0.0)
	var to := FOUNT_AT + Vector3(40.0, 0.0, 0.0)
	var grid := _service.grid
	if not grid.is_free_at(from) or not grid.is_free_at(to):
		return {"ok": false, "reason": "los extremos no son tierra libre", "from": grid.is_free_at(from), "to": grid.is_free_at(to)}
	var path := _service.find_path(from, to)
	var length := NavGrid.path_length(from, path)
	var closest := INF
	var last := from
	for point in path:
		closest = minf(closest, _segment_distance(Vector2(FOUNT_AT.x, FOUNT_AT.z), Vector2(last.x, last.z), Vector2(point.x, point.z)))
		last = point
	var checks := {
		"bends": path.size() >= 2,
		"clear_of_blocker": closest >= FOUNT_RADIUS,
		"ends_at_goal": Vector2(path[path.size() - 1].x, path[path.size() - 1].z).distance_to(Vector2(to.x, to.z)) < 0.01,
		"not_much_longer": length > 80.0 and length < 110.0,
	}
	return _verdict(checks, {"length_m": length, "closest_m": closest, "points": path.size()})


## Start1 to Start2, corner to corner: under 5 ms (the best of five), through land only.
func _corner() -> Dictionary:
	var grid := _service.grid
	var best := 1 << 30
	var path := PackedVector3Array()
	for _run in 5:
		var t := Time.get_ticks_usec()
		path = grid.find_path(START1, START2)
		best = mini(best, Time.get_ticks_usec() - t)
	var legs_clear := true
	var last := START1
	for point in path:
		if not grid.line_clear(last, point):
			legs_clear = false
		last = point
	var straight := Vector2(START1.x - START2.x, START1.z - START2.z).length()
	var length := NavGrid.path_length(START1, path)
	var checks := {
		"under_5ms": best <= PATH_US,
		"has_path": path.size() >= 2,
		"legs_clear": legs_clear,
		"longer_than_straight": length >= straight,
		"ends_at_goal": path.size() > 0 and Vector2(path[path.size() - 1].x, path[path.size() - 1].z).distance_to(Vector2(START2.x, START2.z)) < 0.01,
	}
	return _verdict(checks, {"best_us": best, "length_m": length, "straight_m": straight, "points": path.size()})


func _regions() -> Dictionary:
	var grid := _service.grid
	var checks := {
		"starts_connected": grid.same_region(START1, START2),
		"void_has_none": grid.component_at(Vector3(20.0, 0.0, 20.0)) == -1,
		"void_is_not_same": not grid.same_region(START1, Vector3(20.0, 0.0, 20.0)),
	}
	return _verdict(checks, {"component": grid.component_at(START1)})


## A goal over a hole or off the land ends on the closest free node of the walker's region; a goal on the
## blocker ends beside it.
func _off_land() -> Dictionary:
	var grid := _service.grid
	var on_blocker := FOUNT_AT
	var from := FOUNT_AT + Vector3(-40.0, 0.0, 0.0)
	var checks := {}
	for label in ["blocker", "far_void"]:
		var goal := on_blocker if label == "blocker" else Vector3(20.0, 0.0, 20.0)
		var path := grid.find_path(from, goal)
		var last: Vector3 = path[path.size() - 1] if path.size() > 0 else from
		checks[label + "_answers"] = path.size() > 0
		checks[label + "_ends_free"] = grid.is_free_at(last) or last == goal
	return _verdict(checks, {})


func _line_clear() -> Dictionary:
	var grid := _service.grid
	var checks := {
		"across_blocker": not grid.line_clear(FOUNT_AT + Vector3(-40.0, 0.0, 0.0), FOUNT_AT + Vector3(40.0, 0.0, 0.0)),
		"starts_straight_blocked": not grid.line_clear(START1, START2),
		"short_hop": grid.line_clear(START1, START1 + Vector3(5.0, 0.0, 0.0)),
	}
	return _verdict(checks, {})


## RFC-024 024d fix: a building box turned 45 degrees (8 x 8 m, like the houses of the village) and a walk whose straight line
## grazes its corner by less than a body: the path the grid gives keeps every point of every leg at least `BODY_M` off the box,
## and the straight line is not «clear».
const BOX_HALF := Vector2(4.0, 4.0)
const BODY_M := 0.5


func _box_corner() -> Dictionary:
	var center := Vector2(FOUNT_AT.x, FOUNT_AT.z)
	var yaw := deg_to_rad(45.0)
	var grid := NavGrid.new()
	grid.build(_terrain, [[center, BOX_HALF, yaw]], _service.margin_m, _service.erode_edges)
	## The corner of the turned box reaches 4 * sqrt(2) = 5.66 m from its center; the line passes 5.9 m off (0.24 m of the corner).
	var from := FOUNT_AT + Vector3(-40.0, 0.0, -5.9)
	var to := FOUNT_AT + Vector3(40.0, 0.0, -5.9)
	var path := grid.find_path(from, to)
	var closest := INF
	var last := from
	for point in path:
		var a := Vector2(last.x, last.z)
		var b := Vector2(point.x, point.z)
		var steps := maxi(1, ceili(a.distance_to(b) / 0.25))
		for k in steps + 1:
			closest = minf(closest, _box_gap(a.lerp(b, float(k) / steps), center, BOX_HALF, yaw))
		last = point
	var checks := {
		"ends_free": grid.is_free_at(from) and grid.is_free_at(to),
		"straight_not_clear": not grid.line_clear(from, to),
		"path_clear_of_box": closest >= BODY_M,
	}
	return _verdict(checks, {"closest_m": snappedf(closest, 0.01), "points": path.size()})


## Distance from `p` to the box (half extents `half`, turned `yaw` about Y as NavGrid._block_box reads it); 0 inside.
static func _box_gap(p: Vector2, center: Vector2, half: Vector2, yaw: float) -> float:
	var d := p - center
	var local := Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))
	var out := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
	return out.length()


static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func _verdict(checks: Dictionary, details: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	var out := details.duplicate()
	out["ok"] = ok
	out["checks"] = checks
	return out
