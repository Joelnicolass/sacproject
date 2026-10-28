class_name WallUvRules
extends RefCounted

## Where the cliff texture lies on the walls that hang under the edge of the land (the map's rim, a Bore pit, a falling
## piece): across a wall it runs by the metres walked along the rim, so it keeps its width on every wall and goes on from
## one wall to the next without a jump; down a wall it runs once from the rim (0) to the wall's foot (1). Pure and static:
## TerrainMeshArrays, HoleWallRules and FallingChunkRules put the result in the mesh's UV. It does not build walls.


## For walls given by the two ends of their rim, [a0, b0, a1, b1, ...] (x, z), the metres along the rim at each end, in the
## same order. Walls that share an end continue each other's count; a run starts at an end only one wall touches (or
## anywhere on a closed loop).
static func rim_metres(ends: PackedVector2Array) -> PackedFloat32Array:
	var at := {}
	for i in ends.size():
		var key := point_key(ends[i])
		if not at.has(key):
			at[key] = []
		(at[key] as Array).append(i)
	var metres := PackedFloat32Array()
	metres.resize(ends.size())
	var done := PackedByteArray()
	done.resize(ends.size() / 2)
	for open_runs_first in [true, false]:
		for i in ends.size():
			if done[i / 2] == 0 and (not open_runs_first or (at[point_key(ends[i])] as Array).size() == 1):
				_walk(ends, at, done, metres, i)
	return metres


static func _walk(ends: PackedVector2Array, at: Dictionary, done: PackedByteArray, metres: PackedFloat32Array, start: int) -> void:
	var end := start
	var walked := 0.0
	while end >= 0:
		done[end / 2] = 1
		var other := end ^ 1
		metres[end] = walked
		walked += ends[end].distance_to(ends[other])
		metres[other] = walked
		end = -1
		for candidate: int in at[point_key(ends[other])]:
			if done[candidate / 2] == 0:
				end = candidate
				break


## The same point of the rim, rounded to 10 cm, as a dictionary key.
static func point_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))
