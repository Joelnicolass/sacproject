class_name NavRebake
extends RefCounted

## Re-bakes the navmesh of the zones a change touches when something that blocks changes: an altar
## or a structure came or went, a building fell, the ground moved. The map is a grid of zones
## (NavZones). The static colliders of the `nav_source` nodes under `root` are parsed on the main
## thread (NavigationServer3D.parse_source_geometry_data; a fallen building has its collision off
## and is not parsed), and on a worker thread only the zones the changed areas touch are baked
## again, stitched into one navmesh and indexed (NavRegions.build, pure data: the main thread only
## swaps references). The zone pieces in force belong to this class and the new ones count from
## `finish`. The caller swaps the result in at a TICK it chose, not when the thread happens to end
## (`is_done` says when it can be collected without waiting), so the match is reproducible while the
## bake ends before that tick; a slower machine swaps at the first tick it is done and the match
## keeps the old navmesh meanwhile.
## Not: when to bake or what changed (NavService, NavChanges), the swap itself
## (NavMeshBackend.swap).

var settings: NavBakeSettings
var parse_ms := 0.0
## Wall-clock of the last bake and its index (the thread's own time); reports only.
var bake_ms := 0.0
## How many zones the last bake did and how many the map has; reports only.
var zones_baked := 0
var zones_total := 0
## The components of the navmesh the last `finish` returned, built on the worker with it (null when
## it came out empty).
var regions: NavRegions

var _task := -1
var _navmesh: NavigationMesh
var _regions: NavRegions
## The pieces in force (null until the first bake finishes) and the ones the running bake makes.
var _zones: NavZones
var _next: NavZones
## The stored navmesh the pieces are cut from the first time (cut on the worker).
var _seed: NavigationMesh
## An index swapped out of the backend: the next bake drops it on its worker thread.
var _retired: NavRegions
var _bake_started := 0


func _init(bake_settings: NavBakeSettings = null) -> void:
	settings = bake_settings if bake_settings != null else NavBakeSettings.new()


func is_running() -> bool:
	return _task >= 0


## The stored navmesh of the map: the first bake cuts its pieces from it, so only the touched zones
## are baked.
func set_stored(navmesh: NavigationMesh) -> void:
	_seed = navmesh


## Parses `root` and starts the bake of the zones that `areas` (rects x, z in metres) touch on a
## worker thread. False (nothing started) when a bake runs or there is no geometry. Without pieces
## to start from (no `set_stored`) every zone is baked.
func start(root: Node, areas: Array[Rect2]) -> bool:
	return _begin(root, areas, _zones == null and _seed == null)


## True when the worker has finished (or none runs): `finish` then does not block.
func is_done() -> bool:
	return not is_running() or WorkerThreadPool.is_task_completed(_task)


## Waits for the bake (blocks the caller: use `is_done` first in the match) and returns its navmesh
## (null when it came out empty); `regions` then holds its components.
func finish() -> NavigationMesh:
	if not is_running():
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out := _navmesh
	var index := _regions
	var next := _next
	_navmesh = null
	_regions = null
	_next = null
	var empty := out == null or out.get_polygon_count() == 0
	regions = null if empty else index
	if not empty:
		_zones = next
		_seed = null
	return null if empty else out


## Keeps `old` (an index swapped out) until the next bake lets it go on the worker thread, so its
## memory is not freed on the main one.
func retire(old: NavRegions) -> void:
	_retired = old


## Parse and bake EVERY zone on the calling thread. Null when it came out empty.
func bake_now(root: Node) -> NavigationMesh:
	if not _begin(root, [] as Array[Rect2], true):
		return null
	return finish()


func _begin(root: Node, areas: Array[Rect2], everything: bool) -> bool:
	if is_running():
		return false
	var parse_mesh := NavigationMesh.new()
	settings.apply_to(parse_mesh)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var started := Time.get_ticks_usec()
	NavigationServer3D.parse_source_geometry_data(parse_mesh, geometry, root)
	# The zones the areas touch, with their borders: the trees past them change no zone baked now.
	var reach := settings.zone_m + 2.0 * settings.zone_border_m
	var within: Array[Rect2] = []
	if not everything:
		for area in areas:
			within.append(area.grow(reach))
	NavObstructions.add_to(geometry, root, within)
	parse_ms = float(Time.get_ticks_usec() - started) / 1000.0
	if not geometry.has_data():
		return false
	_task = WorkerThreadPool.add_task(_work.bind(geometry, areas, everything), false, "NavRebake")
	return true


func _work(
	geometry: NavigationMeshSourceGeometryData3D, areas: Array[Rect2], everything: bool
) -> void:
	_retired = null
	_bake_started = Time.get_ticks_usec()
	var base := _zones
	if base == null:
		base = NavZones.new(settings)
		if not everything:
			base.split(_seed)
	var next: NavZones
	if everything:
		next = base.bake_all(geometry)
		zones_baked = base.zone_count()
	else:
		var touched := PackedInt32Array()
		for area in areas:
			for zone in base.zones_touching(area):
				if not touched.has(zone):
					touched.append(zone)
		next = base.baked(geometry, touched)
		zones_baked = touched.size()
	zones_total = base.zone_count()
	var navmesh := next.stitched()
	var index := NavRegions.new()
	index.build(navmesh)
	_next = next
	_navmesh = navmesh
	_regions = index
	bake_ms = float(Time.get_ticks_usec() - _bake_started) / 1000.0
