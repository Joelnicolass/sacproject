class_name GroundField
extends RefCounted

## How far the ground has moved from the map file, vertex by vertex of a regular lattice: what stays (a mound, a crater),
## what moves right now (playing stamps) and which vertices were taken away (holes). It only keeps numbers and adds them up;
## who may write is TerrainDeformer, who asks the height is GroundSurface. A live stamp is stored whole and the sum made
## again from it, never added to, so dropping it leaves the ground as it was.

const SIDE := TerrainRules.GRID  ## the grid map's lattice; anyone who needs the size reads `size`
const COUNT := SIDE * SIDE
## Vertices per side (x, z) and metres between two of them: the ground covers `size * cell_m` from the origin.
var size := Vector2i(SIDE, SIDE)
var cell_m := TerrainRules.CELL
## Two floats per vertex (the layout the ground shader reads): [0] how far it is raised (permanent + live), [1] 1 if taken away.
var texels := PackedFloat32Array()
## What stays (floats, one per vertex). Only `commit` changes it.
var permanent := PackedFloat32Array()
## Count of changes made to what stays; a peer that joins late compares it with the commits it receives.
var rev := 0
## Count of times the visible sum changed (live stamps included): whoever caches what it plants compares it.
var version := 0
## The vertices taken away, as a list (`texels` holds the same in its second float).
var holes := TerrainHoles.new()
var _live := {}  ## stamps playing now: key -> [rect, values] (values row by row over the rect)
var _snapshot := PackedFloat32Array()
var _snapshot_version := -1


func _init() -> void:
	texels.resize(COUNT * 2)
	permanent.resize(COUNT)


## The lattice vertices that lie within `radius_m` of the ground point `center` (x, z), cut to the grid.
static func vertex_rect(center: Vector2, radius_m: float) -> Rect2i:
	var low := Vector2i(floori((center.x - radius_m) / TerrainRules.CELL), floori((center.y - radius_m) / TerrainRules.CELL))
	var high := Vector2i(ceili((center.x + radius_m) / TerrainRules.CELL), ceili((center.y + radius_m) / TerrainRules.CELL))
	low = low.clamp(Vector2i.ZERO, Vector2i(SIDE - 1, SIDE - 1))
	high = high.clamp(Vector2i.ZERO, Vector2i(SIDE - 1, SIDE - 1))
	return Rect2i(low, high - low + Vector2i.ONE)


## Adds `delta` (row by row over `rect`) to what stays and, in the same step, takes away the live stamp `drop_key` (the
## ground does not blink between the two). Returns the rect that changed.
func commit(rect: Rect2i, delta: PackedFloat32Array, drop_key: Variant = null) -> Rect2i:
	for row in rect.size.y:
		for column in rect.size.x:
			var at := (rect.position.y + row) * SIDE + rect.position.x + column
			permanent[at] = permanent[at] + delta[row * rect.size.x + column]
	var changed := rect
	if drop_key != null and _live.has(drop_key):
		changed = changed.merge((_live[drop_key] as Array)[0])
		_live.erase(drop_key)
	rev += 1
	refresh(changed)
	return changed


## A stamp that is playing: its shift over `rect`, replacing the one it had under `key`. Returns the rect that changed.
func set_live(key: Variant, rect: Rect2i, values: PackedFloat32Array) -> Rect2i:
	var changed := rect
	if _live.has(key):
		changed = changed.merge((_live[key] as Array)[0])
	_live[key] = [rect, values]
	refresh(changed)
	return changed


## The stamp under `key` is over: the ground goes back to what stays. Returns the rect that changed (empty if none).
func drop_live(key: Variant) -> Rect2i:
	if not _live.has(key):
		return Rect2i()
	var changed: Rect2i = (_live[key] as Array)[0]
	_live.erase(key)
	refresh(changed)
	return changed


func live_count() -> int:
	return _live.size()


## A copy of `texels` as they are now, for a task on another thread (packed arrays are shared by reference). Made once per change.
func snapshot() -> PackedFloat32Array:
	if _snapshot_version != version:
		_snapshot = texels.duplicate()
		_snapshot_version = version
	return _snapshot


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
	return true


## The vertices taken away, in order.
func removed_ids() -> PackedInt32Array:
	return holes.ids()


## Sums what stays and the live stamps again over `rect`.
func refresh(rect: Rect2i) -> void:
	version += 1
	var stamps := _live.values()
	for row in rect.size.y:
		for column in rect.size.x:
			var x := rect.position.x + column
			var y := rect.position.y + row
			var sum := permanent[y * SIDE + x]
			for stamp: Array in stamps:
				var area: Rect2i = stamp[0]
				if area.has_point(Vector2i(x, y)):
					sum += (stamp[1] as PackedFloat32Array)[(y - area.position.y) * area.size.x + x - area.position.x]
			texels[(y * SIDE + x) * 2] = sum


## A number that is equal on two peers only when what stays and the holes are equal.
func checksum() -> int:
	return hash(permanent) ^ hash(removed_ids())


## Everything a peer that joins late needs.
func to_snapshot() -> Dictionary:
	var raw := permanent.to_byte_array()
	return {"rev": rev, "size": raw.size(), "permanent": raw.compress(FileAccess.COMPRESSION_ZSTD), "holes": removed_ids()}


func apply_snapshot(data: Dictionary) -> void:
	permanent = (data["permanent"] as PackedByteArray).decompress(int(data["size"]), FileAccess.COMPRESSION_ZSTD).to_float32_array()
	for id in holes.ids():
		texels[id * 2 + 1] = 0.0
	holes.replace(data["holes"] as PackedInt32Array)
	for id in holes.ids():
		texels[id * 2 + 1] = 1.0
	rev = int(data["rev"])
	refresh(Rect2i(0, 0, SIDE, SIDE))
