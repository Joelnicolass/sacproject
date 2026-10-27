class_name NavRebake
extends RefCounted

## Re-bakes the whole map's navmesh when something that blocks changes: an altar or a structure came or went, a building
## fell. The engine does the work: the static colliders of the `nav_source` nodes under `root` are parsed on the main thread
## (NavigationServer3D.parse_source_geometry_data, a fallen building has its collision off and is not parsed), and the bake
## (bake_from_source_geometry_data) runs on a worker thread, and so does the index of its components (NavRegions.build, pure data:
## the main thread only swaps references). The caller swaps the result in at a TICK it chose, not when the thread happens to end
## (`is_done` says when it can be collected without waiting), so the match is reproducible while the bake ends before that tick; a
## slower machine swaps at the first tick it is done (the server only) and the match keeps running with the old navmesh meanwhile.
## Not: when to bake (NavService), the swap itself (NavMeshBackend.swap).
## Tile by tile re-baking was dropped: the full bake of High Noon is a couple of seconds on a worker thread, and a lone tile leaves a
## seam against the neighbours baked in one piece.
## Ref: RFC-035 035g.

var settings: NavBakeSettings
var parse_ms := 0.0
## Wall-clock of the last bake and its index (the thread's own time); reports only.
var bake_ms := 0.0
## The components of the navmesh the last `finish` returned, built on the worker with it (null when it came out empty).
var regions: NavRegions

var _task := -1
var _navmesh: NavigationMesh
var _regions: NavRegions
## An index swapped out of the backend: the next bake drops it on its worker thread.
var _retired: NavRegions
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
	settings.fit_to(navmesh, geometry)  # the same cell as the stored bake of a big map
	_navmesh = navmesh
	_task = WorkerThreadPool.add_task(_work.bind(navmesh, geometry), false, "NavRebake")
	return true


## True when the worker has finished (or none runs): `finish` then does not block.
func is_done() -> bool:
	return not is_running() or WorkerThreadPool.is_task_completed(_task)


## Waits for the bake (blocks the caller: use `is_done` first in the match) and returns its navmesh (null when it came out empty); `regions` then holds its components.
func finish() -> NavigationMesh:
	if not is_running():
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out := _navmesh
	var index := _regions
	_navmesh = null
	_regions = null
	var empty := out == null or out.get_polygon_count() == 0
	regions = null if empty else index
	return null if empty else out


## Keeps `old` (an index swapped out) until the next bake lets it go on the worker thread, so its memory is not freed on the main one.
func retire(old: NavRegions) -> void:
	_retired = old


## Parse and bake on the calling thread (the check of debug/suite/nav_cases.gd measures this). Null when it came out empty.
func bake_now(root: Node) -> NavigationMesh:
	if not start(root):
		return null
	return finish()


func _work(navmesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D) -> void:
	_retired = null
	_bake_started = Time.get_ticks_usec()
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	var index := NavRegions.new()
	index.build(navmesh)
	_regions = index
	bake_ms = float(Time.get_ticks_usec() - _bake_started) / 1000.0
