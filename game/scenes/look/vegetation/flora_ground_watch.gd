class_name FloraGroundWatch
extends RefCounted

## Listens to the ground of the map and, at most every `every_s` seconds, tells the planters which part of it moved so they
## plant it again at the new height (a mound lifts its bushes, a crater leaves none hanging). It remembers the moved areas
## in between and joins the ones that overlap. It plants nothing itself (MeshPlanter) and never touches the ground.

var _shape: Terrain
var _moved: Array[Rect2] = []
var _left := 0.0


## Follows this ground from now on (null: none). The same ground again changes nothing.
func follow(shape: Terrain) -> void:
	if shape == _shape:
		return
	if _shape != null and is_instance_valid(_shape) and _shape.changed.is_connected(_on_moved):
		_shape.changed.disconnect(_on_moved)
	_shape = shape
	_moved.clear()
	if _shape != null:
		_shape.changed.connect(_on_moved)


## Counts `delta` seconds; when `every_s` have passed since the last time and something moved, the planters replan it and
## the patches of `tree` look at the ground again.
func update(delta: float, every_s: float, planters: Array[MeshPlanter], tree: SceneTree) -> void:
	_left -= delta
	if _moved.is_empty() or _left > 0.0:
		return
	_left = every_s
	for area in _moved:
		for planter in planters:
			planter.replan(area)
	_moved.clear()
	tree.call_group(VegetationPatch.GROUP, &"field_changed")


func _on_moved(area: Rect2) -> void:
	for i in _moved.size():
		if _moved[i].intersects(area):
			_moved[i] = _moved[i].merge(area)
			return
	_moved.append(area)
