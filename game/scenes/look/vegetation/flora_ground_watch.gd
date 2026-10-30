class_name FloraGroundWatch
extends RefCounted

## Listens to the ground of the map settling (Terrain.settled: a kept stamp, a stamp's end, a hole,
## a brush stroke in the editor) and, at most every `every_s` seconds, tells the planters which part
## of it moved so they plant it again at the new height, and replants the patches whose circle that
## part touches (no other). It remembers the moved areas in between and joins the ones that overlap.
## It plants nothing itself (MeshPlanter, VegetationPatch) and never touches the ground. `mark` also
## takes areas whose flora was painted (the map brush), under the same brake. With `live_every_s` >
## 0 it also follows the stamps that play (Terrain.changed while one plays: the Volcano mound for 64
## s). A tick only joins its rect to a list of their own; that list is planted again every
## `live_every_s` seconds, only the cells it touches, on the ground as it is then
## (Terrain.refresh_sampler). 0 ignores them (only what settles plants again).

## Seconds between two replans of what the playing stamps moved (FloraField.live_replan_s); 0 =
## never.
var live_every_s := 0.0

var _shape: Terrain
var _moved: Array[Rect2] = []
var _live: Array[Rect2] = []
var _left := 0.0
var _live_left := 0.0


## Follows this ground from now on (null: none). The same ground again changes nothing.
func follow(shape: Terrain) -> void:
	if shape == _shape:
		return
	if _shape != null and is_instance_valid(_shape):
		if _shape.settled.is_connected(mark):
			_shape.settled.disconnect(mark)
		if _shape.changed.is_connected(_on_changed):
			_shape.changed.disconnect(_on_changed)
	_shape = shape
	_moved.clear()
	_live.clear()
	if _shape != null:
		_shape.settled.connect(mark)
		_shape.changed.connect(_on_changed)


## Counts `delta` seconds; when `every_s` have passed since the last time and something settled, the
## planters replan it and the patches of `tree` it touches plant again. What the playing stamps
## moved goes the same way every `live_every_s`.
func update(delta: float, every_s: float, planters: Array[MeshPlanter], tree: SceneTree) -> void:
	_left -= delta
	_live_left -= delta
	if not _moved.is_empty() and _left <= 0.0:
		_left = every_s
		_replan(_moved, planters, tree)
	if live_every_s <= 0.0:
		_live.clear()
	elif not _live.is_empty() and _live_left <= 0.0:
		_live_left = live_every_s
		if is_instance_valid(_shape):
			_shape.refresh_sampler()
		_replan(_live, planters, tree)


## How many areas the playing stamps left waiting (joined when they overlap: a stamp playing for a
## minute keeps one).
func live_waiting() -> int:
	return _live.size()


func _replan(areas: Array[Rect2], planters: Array[MeshPlanter], tree: SceneTree) -> void:
	for area in areas:
		for planter in planters:
			planter.replan(area)
	for node in tree.get_nodes_in_group(VegetationPatch.GROUP):
		var patch := node as VegetationPatch
		if patch != null and _touches(patch, areas):
			patch.ground_moved()
	areas.clear()


## True when one of `areas` reaches the patch's circle (both in the ground's x, z).
func _touches(patch: VegetationPatch, areas: Array[Rect2]) -> bool:
	var local := (
		_shape.to_local(patch.global_position)
		if is_instance_valid(_shape)
		else patch.global_position
	)
	var center := Vector2(local.x, local.z)
	for area in areas:
		if center.distance_to(center.clamp(area.position, area.end)) <= patch.radius_m:
			return true
	return false


## `area` (the ground's x, z) has to be planted again: the ground under it settled (Terrain.settled)
## or its flora was painted (FloraField.layer_painted). It waits for the next `update`, joined to an
## overlapping area already waiting; a live area inside it is dropped (the settled replan reads the
## same ground, sooner).
func mark(area: Rect2) -> void:
	_join(_moved, area)
	for i in range(_live.size() - 1, -1, -1):
		if area.encloses(_live[i]):
			_live.remove_at(i)


## Terrain.changed: every tick a stamp plays (and before each `settled`). Only the rect is kept,
## never any work.
func _on_changed(rect: Rect2) -> void:
	if live_every_s > 0.0:
		_join(_live, rect)


static func _join(areas: Array[Rect2], area: Rect2) -> void:
	for i in areas.size():
		if areas[i].intersects(area):
			areas[i] = areas[i].merge(area)
			return
	areas.append(area)
