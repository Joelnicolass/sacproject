class_name GroundField
extends RefCounted

## How far the ground has moved from the map file, vertex by vertex of a regular lattice: what stays
## (a mound, a crater), what moves right now (playing stamps) and which vertices were taken away
## (holes). It only keeps numbers and adds them up; who writes and who answers the height is
## Terrain. A new shift of a playing stamp adds its difference; its end (or a commit) sums the rect
## again from what stays and the stamps left, so dropping it leaves the ground exactly as it was.

## Vertices per side (x, z) and metres between two of them: the ground covers `size * cell_m` from
## the origin.
var size := Vector2i(TerrainGrid.SIDE, TerrainGrid.SIDE)
var cell_m := TerrainGrid.CELL_M
## Two floats per vertex (the layout the ground shader reads): [0] how far it is raised (permanent +
## live), [1] 1 if taken away.
var texels := PackedFloat32Array()
## What stays (floats, one per vertex). Only `commit` changes it.
var permanent := PackedFloat32Array()
## Count of changes made to what stays; a peer that joins late compares it with the commits it
## receives.
var rev := 0
## Count of times the visible sum changed (live stamps included).
var version := 0
## Count of times the ground settled: a commit, a hole, a stamp that ended, a snapshot. `snapshot()`
## copies once per count.
var settled_version := 0
## The vertices taken away, as a list (`texels` holds the same in its second float).
var holes := TerrainHoles.new()
var _live := {}  ## stamps playing now: key -> [rect, values] (values row by row over the rect)
var _snapshot := PackedFloat32Array()
var _snapshot_version := -1


func _init() -> void:
	texels.resize(TerrainGrid.COUNT * 2)
	permanent.resize(TerrainGrid.COUNT)


## Adds `delta` (row by row over `rect`) to what stays and, in the same step, takes away the live
## stamp `drop_key` (the ground does not blink between the two). Returns the rect that changed.
func commit(rect: Rect2i, delta: PackedFloat32Array, drop_key: Variant = null) -> Rect2i:
	GroundSumRules.add(permanent, rect, delta)
	var changed := rect
	if drop_key != null and _live.has(drop_key):
		changed = changed.merge((_live[drop_key] as Array)[0])
		_live.erase(drop_key)
	rev += 1
	settled_version += 1
	refresh(changed)
	return changed


## A stamp that is playing: its shift over `rect`, replacing the one it had under `key`. Returns the
## rect that changed. Over the same rect only the difference is added (exactly what stays + the
## shift when no other stamp overlaps it).
func set_live(key: Variant, rect: Rect2i, values: PackedFloat32Array) -> Rect2i:
	var old: Array = _live.get(key, [])
	_live[key] = [rect, values]
	if old.is_empty() or old[0] != rect:
		var changed: Rect2i = rect if old.is_empty() else rect.merge(old[0])
		refresh(changed)
		return changed
	version += 1
	var alone := true
	for other: Variant in _live:
		alone = alone and (other == key or not rect.intersects((_live[other] as Array)[0]))
	GroundSumRules.replace(texels, permanent, rect, values, old[1], alone)
	return rect


## The stamp under `key` is over: the ground goes back to what stays. Returns the rect that changed
## (empty if none).
func drop_live(key: Variant) -> Rect2i:
	if not _live.has(key):
		return Rect2i()
	var changed: Rect2i = (_live[key] as Array)[0]
	_live.erase(key)
	settled_version += 1
	refresh(changed)
	return changed


func live_count() -> int:
	return _live.size()


## The keys of the stamps playing now.
func live_keys() -> PackedStringArray:
	return PackedStringArray(_live.keys())


## A copy of `texels` as they were at the last settle, for a task on another thread (packed arrays
## are shared by reference). A live stamp's tick never copies; a stamp playing when the ground
## settled is in the copy.
func snapshot() -> PackedFloat32Array:
	if _snapshot_version != settled_version:
		_snapshot = texels.duplicate()
		_snapshot_version = settled_version
	return _snapshot


## The next `snapshot` copies `texels` as they are now, live stamps included (once; then it waits
## for a settle again).
func drop_snapshot() -> void:
	_snapshot_version = -1


## The shift of the vertex `id` right now.
func at(id: int) -> float:
	return texels[id * 2]


func is_removed(id: int) -> bool:
	return texels[id * 2 + 1] > 0.5


## Takes a vertex away or gives it back. True when that changed something.
func set_removed(id: int, removed: bool) -> bool:
	if is_removed(id) == removed:
		return false
	texels[id * 2 + 1] = 1.0 if removed else 0.0
	holes.put(id, removed)
	version += 1
	settled_version += 1
	return true


## The vertices taken away, in order.
func removed_ids() -> PackedInt32Array:
	return holes.ids()


## Sums what stays and the live stamps again over `rect` (stamp by stamp, in the order they
## started).
func refresh(rect: Rect2i) -> void:
	version += 1
	GroundSumRules.sum(texels, permanent, _live.values(), rect)


## A number that is equal on two peers only when what stays and the holes are equal.
func checksum() -> int:
	return hash(permanent) ^ hash(removed_ids())


## Everything a peer that joins late needs.
func to_snapshot() -> Dictionary:
	var raw := permanent.to_byte_array()
	return {
		"rev": rev,
		"size": raw.size(),
		"permanent": raw.compress(FileAccess.COMPRESSION_ZSTD),
		"holes": removed_ids()
	}


func apply_snapshot(data: Dictionary) -> void:
	permanent = (
		(data["permanent"] as PackedByteArray)
		. decompress(int(data["size"]), FileAccess.COMPRESSION_ZSTD)
		. to_float32_array()
	)
	for id in holes.ids():
		texels[id * 2 + 1] = 0.0
	holes.replace(data["holes"] as PackedInt32Array)
	for id in holes.ids():
		texels[id * 2 + 1] = 1.0
	rev = int(data["rev"])
	settled_version += 1
	refresh(Rect2i(0, 0, TerrainGrid.SIDE, TerrainGrid.SIDE))
