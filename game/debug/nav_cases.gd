extends RefCounted

## RFC-024 024b cases of rules_suite: the NavService on the baked navmesh with one manafount-like
## blocker at the center of the map, its cost, the path around the blocker and what it answers for points
## the land does not hold. `run(host)` adds the terrain and a NavService under `host` and removes them at
## the end. Times are wall clock (the RFC asks 5 ms for a corner-to-corner path).
## RFC-035 035i: the navmesh is the only backend. `nav_box_corner` checks the box blockers (NavBoxBlockers, the maths a building's
## corner needs); `nav_rebake_ms` is the cost of baking the whole navmesh again (gate REBAKE_MS).

const EDGE_CASES := preload("res://debug/edge_cases.gd")  # 036h
const TERRAIN_SCRIPT := preload("res://scenes/world/terrain.gd")
const FOUNT_AT := Vector3(1270.0, 10.0, 1270.0)
const FOUNT_RADIUS := 3.6
const START1 := Vector3(1504.9, 17.0, 1540.5)
const START2 := Vector3(1037.7, 15.0, 1009.9)
const PATH_US := 5000
## Loading the navmesh into its map and finding its regions (GDScript, once per match).
const NAVMESH_MS := 1500.0
## The whole-map re-bake runs on a worker thread and is swapped in after NavService.rebake_swap_frames ticks (3 s): it has to fit.
const REBAKE_MS := 3000.0

var _root: Node3D
var _service: NavService
var _terrain: MeshInstance3D


func run(host: Node3D) -> Dictionary:  # a coroutine: it waits for physics frames
	_root = Node3D.new()
	_root.name = "NavCases"
	_terrain = MeshInstance3D.new()
	_terrain.name = "Terrain"
	_terrain.set_script(TERRAIN_SCRIPT)
	_terrain.set("data", load(OriginalAssets.HIGH_NOON_TERRAIN))
	_terrain.add_to_group(NavFingerprint.GROUP)
	_root.add_child(_terrain)
	var fount := StaticBody3D.new()
	fount.name = "FakeFount"
	## `nav_blocker`, not `manafount`: the stored bake holds the real manafounts, so a fount of this test is what a re-bake adds.
	fount.add_to_group("nav_blocker")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = FOUNT_RADIUS
	## 8 m tall from the ground, like a structure: a top within the agent's climb would be walkable and connected.
	cylinder.height = 8.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 4.0, 0.0)
	fount.add_child(shape)
	var ground: float = _terrain.call("ground_height", FOUNT_AT.x, FOUNT_AT.z)
	fount.position = FOUNT_AT if is_nan(ground) else Vector3(FOUNT_AT.x, ground, FOUNT_AT.z)
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
		return {"nav_build": missing}
	_service.build()
	## The engine syncs the navmesh's map on its physics frames: the navmesh backend answers after the first ones.
	for _frame in 3:
		await host.get_tree().physics_frame
	## The fount is not in the stored bake: wait for the re-bake that adds it to be swapped in (bounded, the swap is a count of ticks).
	var guard := 900
	while _service.is_rebaking() and guard > 0:
		guard -= 1
		await host.get_tree().physics_frame
	for _frame in 3:
		await host.get_tree().physics_frame
	out["nav_build"] = _build()
	out["nav_blocker_blocks"] = _blocker()
	out["nav_path_around"] = _around()
	out["nav_path_corner_to_corner"] = _corner()
	out["nav_regions"] = _regions()
	out["nav_goal_off_land"] = _off_land()
	out["nav_line_clear"] = _line_clear()
	out["nav_box_corner"] = _box_corner()
	out.merge(await EDGE_CASES.new().run(_root, _terrain, _service))  # 036h
	out["nav_rebake_ms"] = _rebake()
	_root.free()
	return out


func _build() -> Dictionary:
	var mesh := _service.mesh
	var checks := {
		"built": _service.is_ready(),
		"ms_under_limit": mesh.build_ms <= NAVMESH_MS,
		"has_polygons": mesh.polygon_count > 1000,
		"regions": mesh.regions.component_count >= 1,
		"main_region_holds_most": _largest_share(mesh.regions.sizes) >= 0.9,
	}
	var sizes := Array(mesh.regions.sizes)
	sizes.sort()
	sizes.reverse()
	return _verdict(checks, {"backend": "navmesh", "build_ms": mesh.build_ms, "polygons": mesh.polygon_count, "regions": mesh.regions.component_count,
			"biggest_regions": sizes.slice(0, 6), "share": snappedf(_largest_share(mesh.regions.sizes), 0.001)})


static func _largest_share(sizes: PackedInt32Array) -> float:
	var total := 0
	var biggest := 0
	for size in sizes:
		total += size
		biggest = maxi(biggest, size)
	return float(biggest) / maxf(1.0, float(total))


## The blocker is a hole in the navmesh (radius plus the agent radius): its center is blocked, the land 25 m away is not.
func _blocker() -> Dictionary:
	var checks := {
		"center": not _service.is_free_at(FOUNT_AT),
		"far": _service.is_free_at(FOUNT_AT + Vector3(25.0, 0.0, 0.0)) or _service.is_free_at(FOUNT_AT + Vector3(-25.0, 0.0, 0.0)) or _service.is_free_at(FOUNT_AT + Vector3(0.0, 0.0, 25.0)),
	}
	return _verdict(checks, {})


## Across the blocker: the path bends around it, never goes through it and is not much longer than needed.
func _around() -> Dictionary:
	var from := FOUNT_AT + Vector3(-40.0, 0.0, 0.0)
	var to := FOUNT_AT + Vector3(40.0, 0.0, 0.0)
	if not _service.is_free_at(from) or not _service.is_free_at(to):
		return {"ok": false, "reason": "los extremos no son tierra libre", "from": _service.is_free_at(from), "to": _service.is_free_at(to)}
	var path := _service.find_path(from, to)
	var length := NavService.path_length(from, path)
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


## Start1 to Start2, corner to corner: under 5 ms (the best of five), through land only. The path ends on the closest point of the
## mesh to the goal (the goal itself when it is on the mesh), so its end and its length are taken to that point.
func _corner() -> Dictionary:
	var best := 1 << 30
	var path := PackedVector3Array()
	for _run in 5:
		var t := Time.get_ticks_usec()
		path = _service.find_path(START1, START2)
		best = mini(best, Time.get_ticks_usec() - t)
	var legs_clear := true
	var last := START1
	for point in path:
		if not _leg_ok(last, point):
			legs_clear = false
		last = point
	var goal := START2
	var snapped_goal := _service.nearest_free(START2)
	if not is_nan(snapped_goal.x):
		goal = snapped_goal
	var straight := Vector2(START1.x - goal.x, START1.z - goal.z).length()
	var length := NavService.path_length(START1, path)
	var end_gap := Vector2(path[path.size() - 1].x - goal.x, path[path.size() - 1].z - goal.z).length() if path.size() > 0 else INF
	var checks := {
		"under_5ms": best <= PATH_US,
		"has_path": path.size() >= 2,
		"legs_clear": legs_clear,
		"longer_than_straight": length >= straight,
		"ends_at_goal": end_gap < 1.5,
	}
	return _verdict(checks, {"best_us": best, "length_m": length, "straight_m": straight, "points": path.size(), "end_gap_m": end_gap,
			"goal_snap_gap_m": Vector2(goal.x - START2.x, goal.z - START2.z).length()})


## A leg of a path is on free land: its line is clear; the line test is strict at the edge of the mesh, where
## an optimized path hugs a corner, so a leg whose own path is no longer than the leg also passes.
func _leg_ok(a: Vector3, b: Vector3) -> bool:
	if _service.line_clear(a, b):
		return true
	var flat := Vector2(a.x - b.x, a.z - b.z).length()
	return NavService.path_length(a, _service.find_path(a, b)) <= flat * 1.02 + 0.5


func _regions() -> Dictionary:
	var checks := {
		"starts_connected": _service.same_region(START1, START2),
		"void_has_none": _service.component_at(Vector3(20.0, 0.0, 20.0)) == -1,
		"void_is_not_same": not _service.same_region(START1, Vector3(20.0, 0.0, 20.0)),
		"nearest_free_on_land": not is_nan(_service.nearest_free(START1).x),
		"nearest_free_void": is_nan(_service.nearest_free(Vector3(20.0, 0.0, 20.0)).x),
	}
	return _verdict(checks, {"component": _service.component_at(START1)})


## A goal over a hole or off the land ends on the closest free land of the walker's region; a goal on the
## blocker ends beside it.
func _off_land() -> Dictionary:
	var on_blocker := FOUNT_AT
	var from := FOUNT_AT + Vector3(-40.0, 0.0, 0.0)
	var checks := {}
	for label in ["blocker", "far_void"]:
		var goal := on_blocker if label == "blocker" else Vector3(20.0, 0.0, 20.0)
		var path := _service.find_path(from, goal)
		var last: Vector3 = path[path.size() - 1] if path.size() > 0 else from
		checks[label + "_answers"] = path.size() > 0
		checks[label + "_ends_free"] = _service.is_free_at(last) or Vector2(last.x, last.z) == Vector2(goal.x, goal.z)
	return _verdict(checks, {})


func _line_clear() -> Dictionary:
	var checks := {
		"across_blocker": not _service.line_clear(FOUNT_AT + Vector3(-40.0, 0.0, 0.0), FOUNT_AT + Vector3(40.0, 0.0, 0.0)),
		"starts_straight_blocked": not _service.line_clear(START1, START2),
		"short_hop": _service.line_clear(START1, START1 + Vector3(5.0, 0.0, 0.0)),
	}
	return _verdict(checks, {})


## RFC-024 024d fix: a building box turned 45 degrees (8 x 8 m, like the houses of the village) and a walk whose straight line
## grazes its corner by less than a body: the box blockers say that line goes through the building (grown by `BODY_M`), and a line
## that passes a body's width clear of the corner does not.
const BOX_HALF := Vector2(4.0, 4.0)
const BODY_M := 0.5


func _box_corner() -> Dictionary:
	var center := Vector2(FOUNT_AT.x, FOUNT_AT.z)
	var yaw := deg_to_rad(45.0)
	var boxes := NavBoxBlockers.new()
	boxes.reset(BODY_M)
	boxes.add_entries([[center, BOX_HALF, yaw]])
	## The corner of the turned box reaches 4 * sqrt(2) = 5.66 m from its center; the line passes 5.9 m off (0.24 m of the corner).
	var grazing_from := FOUNT_AT + Vector3(-40.0, 0.0, -5.9)
	var grazing_to := FOUNT_AT + Vector3(40.0, 0.0, -5.9)
	var clear_from := FOUNT_AT + Vector3(-40.0, 0.0, -6.5)
	var clear_to := FOUNT_AT + Vector3(40.0, 0.0, -6.5)
	var checks := {
		"has_box": not boxes.is_empty(),
		"grazing_line_crosses": boxes.crosses_box(grazing_from, grazing_to),
		"clear_line_does_not": not boxes.crosses_box(clear_from, clear_to),
		"through_center_crosses": boxes.crosses_box(FOUNT_AT + Vector3(-40.0, 0.0, 0.0), FOUNT_AT + Vector3(40.0, 0.0, 0.0)),
	}
	return _verdict(checks, {})


## RFC-035 035g: the whole navmesh baked again from the nav_source colliders (parse on this thread, bake on a worker thread, waited for).
## The gate is REBAKE_MS; the report gives the parse and the total.
func _rebake() -> Dictionary:
	var rebake := NavRebake.new(load("res://data/nav/nav_bake.tres") as NavBakeSettings)
	var started := Time.get_ticks_usec()
	var baked := rebake.bake_now(_root)
	var total_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var polygons := baked.get_polygon_count() if baked != null else 0
	var checks := {
		"has_polygons": polygons > 0,
		"under_limit": total_ms <= REBAKE_MS,
	}
	return _verdict(checks, {"total_ms": snappedf(total_ms, 0.1), "parse_ms": snappedf(rebake.parse_ms, 0.1), "bake_ms": snappedf(rebake.bake_ms, 0.1), "polygons": polygons})


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
