class_name NavRebake
extends RefCounted

## Re-bakes the whole map's navmesh when something that blocks changes (RFC-035 035g): an altar or a structure came or went, a building
## fell. The engine does the work: the static colliders of the `nav_source` nodes under `root` are parsed on the main thread
## (NavigationServer3D.parse_source_geometry_data, a fallen building has its collision off and is not parsed), and the bake
## (bake_from_source_geometry_data) runs on a worker thread. The caller swaps the result in at a TICK it chose, not when the thread
## happens to end (`finish` waits for it), so the match stays reproducible whatever the machine's speed.
## Tile by tile re-baking was dropped: the full bake of High Noon is a couple of seconds on a worker thread, and a lone tile leaves a
## seam against the neighbours baked in one piece.

var settings: NavBakeSettings
var parse_ms := 0.0
## Wall-clock of the last bake (the thread's own time); reports only.
var bake_ms := 0.0

var _task := -1
var _navmesh: NavigationMesh
var _bake_started := 0


func _init(bake_settings: NavBakeSettings = null) -> void:
	settings = bake_settings if bake_settings != null else NavBakeSettings.new()


func is_running() -> bool:
	return _task >= 0


## Parses `root` and starts the bake on a worker thread. False (nothing started) when a bake runs or there is no geometry.
func start(root: Node) -> bool:
	if is_running():
		return false
	var navmesh := NavigationMesh.new()
	settings.apply_to(navmesh)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var started := Time.get_ticks_usec()
	NavigationServer3D.parse_source_geometry_data(navmesh, geometry, root)
	parse_ms = float(Time.get_ticks_usec() - started) / 1000.0
	if not geometry.has_data():
		return false
	_navmesh = navmesh
	_task = WorkerThreadPool.add_task(_work.bind(navmesh, geometry), false, "NavRebake")
	return true


## Waits for the bake and returns its navmesh (null when it came out empty).
func finish() -> NavigationMesh:
	if not is_running():
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out := _navmesh
	_navmesh = null
	return out if out != null and out.get_polygon_count() > 0 else null


## Parse and bake on the calling thread (the check of debug/suite/nav_cases.gd measures this). Null when it came out empty.
func bake_now(root: Node) -> NavigationMesh:
	if not start(root):
		return null
	return finish()


func _work(navmesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D) -> void:
	_bake_started = Time.get_ticks_usec()
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	bake_ms = float(Time.get_ticks_usec() - _bake_started) / 1000.0
