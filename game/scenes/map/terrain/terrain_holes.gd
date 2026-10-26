class_name TerrainHoles
extends RefCounted

## Which vertices of the ground's lattice were taken away, by id (a set), and how many times that changed. Whoever draws the pits
## compares `version`. It keeps the list only: the numbers the ground answers with are GroundField's, and who may take a vertex
## away is Terrain.

## Count of times a vertex came or went.
var version := 0

var _ids := {}


func has(id: int) -> bool:
	return _ids.has(id)


func count() -> int:
	return _ids.size()


## Takes `id` in or out. True when that changed the list.
func put(id: int, gone: bool) -> bool:
	if _ids.has(id) == gone:
		return false
	if gone:
		_ids[id] = true
	else:
		_ids.erase(id)
	version += 1
	return true


## The ids, smallest first (the same order on every peer).
func ids() -> PackedInt32Array:
	var found := PackedInt32Array(_ids.keys())
	found.sort()
	return found


## The list is now `list` (a snapshot arrived).
func replace(list: PackedInt32Array) -> void:
	_ids.clear()
	for id in list:
		_ids[id] = true
	version += 1
