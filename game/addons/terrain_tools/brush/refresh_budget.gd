@tool
extends RefCounted

## How long the editor would stand still while a Terrain builds its ground again from new heights (its triangles, their
## index and the mesh arrays: what TerrainShape and TerrainMesh do on the main thread), measured once per heights on a
## worker thread so the measuring never blocks. Under LIMIT_MS a stroke rebuilds the ground when it is released; over it,
## the stroke stays a draft shown by the preview until it is saved or «Rebuild» is pressed.
## Not: rebuilding (Terrain does), the draft (TerrainHistory).

## Told on the main thread once `heights` has been measured.
signal measured(heights: TerrainHeights, ms: float)

const LIMIT_MS := 300.0

var _ms := {}  ## TerrainHeights -> ms (-1 while measuring)
var _tasks := PackedInt64Array()


## The measured rebuild time of `heights` in ms; -1 while it is not known yet (then measuring starts).
func cost_ms(terrain: Terrain) -> float:
	var heights := terrain.heights
	if heights == null or not heights.is_valid():
		return -1.0
	if not _ms.has(heights):
		_ms[heights] = -1.0
		var copy := TerrainHeights.new()
		copy.heights_m = heights.heights_m.duplicate()
		copy.void_mask = heights.void_mask.duplicate()
		_tasks.append(WorkerThreadPool.add_task(_measure.bind(heights, copy), false, "Measure the terrain rebuild"))
	return _ms[heights]


## Waits for the measures still running (the plugin calls it when it leaves the editor).
func finish() -> void:
	for task in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()


## True when a released stroke may rebuild the ground at once (measured and under LIMIT_MS).
func is_light(terrain: Terrain) -> bool:
	var ms := cost_ms(terrain)
	return ms >= 0.0 and ms <= LIMIT_MS


func _measure(heights: TerrainHeights, copy: TerrainHeights) -> void:
	var started := Time.get_ticks_usec()
	var faces := TerrainFaces.build(copy)
	if faces.is_valid():
		TerrainRules.index(faces)
		TerrainMeshArrays.from_data(faces).with_normals(true)
	_done.call_deferred(heights, (Time.get_ticks_usec() - started) / 1000.0)


func _done(heights: TerrainHeights, ms: float) -> void:
	_ms[heights] = ms
	print("Terrain: rebuilding %s takes %.0f ms (%s)." % [heights.resource_path.get_base_dir(), ms,
			"on stroke release" if ms <= LIMIT_MS else "over %.0f ms: stays a draft until saving or «Rebuild»" % LIMIT_MS])
	measured.emit(heights, ms)
