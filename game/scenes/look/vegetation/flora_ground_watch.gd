class_name FloraGroundWatch
extends RefCounted

## Listens to the ground of the map settling (Terrain.settled: a kept stamp, a stamp's end, a hole, a brush stroke in the
## editor; never a live tick) and, at most every `every_s` seconds, tells the planters which part of it moved so they plant
## it again at the new height, and replants the patches whose circle that part touches (no other). It remembers the moved
## areas in between and joins the ones that overlap. It plants nothing itself (MeshPlanter, VegetationPatch) and never
## touches the ground. `mark` also takes areas whose flora was painted (the map brush), under the same brake.

var _shape: Terrain
var _moved: Array[Rect2] = []
var _left := 0.0


## Follows this ground from now on (null: none). The same ground again changes nothing.
func follow(shape: Terrain) -> void:
	if shape == _shape:
		return
	if _shape != null and is_instance_valid(_shape) and _shape.settled.is_connected(mark):
		_shape.settled.disconnect(mark)
	_shape = shape
	_moved.clear()
	if _shape != null:
		_shape.settled.connect(mark)


## Counts `delta` seconds; when `every_s` have passed since the last time and something moved, the planters replan it and
## the patches of `tree` it touches plant again.
func update(delta: float, every_s: float, planters: Array[MeshPlanter], tree: SceneTree) -> void:
	_left -= delta
	if _moved.is_empty() or _left > 0.0:
		return
	_left = every_s
	for area in _moved:
		for planter in planters:
			planter.replan(area)
	for node in tree.get_nodes_in_group(VegetationPatch.GROUP):
		var patch := node as VegetationPatch
		if patch != null and _touches(patch):
			patch.ground_moved()
	_moved.clear()


## True when a moved area reaches the patch's circle (both in the ground's x, z).
func _touches(patch: VegetationPatch) -> bool:
	var local := _shape.to_local(patch.global_position) if is_instance_valid(_shape) else patch.global_position
	var center := Vector2(local.x, local.z)
	for area in _moved:
		if center.distance_to(center.clamp(area.position, area.end)) <= patch.radius_m:
			return true
	return false


## `area` (the ground's x, z) has to be planted again: the ground under it settled (Terrain.settled) or its flora was
## painted (FloraField.layer_painted). It waits for the next `update`, joined to an overlapping area already waiting.
func mark(area: Rect2) -> void:
	for i in _moved.size():
		if _moved[i].intersects(area):
			_moved[i] = _moved[i].merge(area)
			return
	_moved.append(area)
