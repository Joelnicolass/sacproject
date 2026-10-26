class_name FloraClears
extends RefCounted

## When the planters of a FloraField take the map's VegetationClear circles again: on the next frame after a clear moved,
## resized or left (`mark`), and once every POLL_S anyway; each planter gets them in its map's coordinates.
## Not: which cells a clear makes rebuild (MeshPlanter.set_clears), the clears themselves (VegetationClear).

const POLL_S := 1.0

var _dirty := true
var _left_s := 0.0


## Something about the clears changed: the planters take them again on the next update.
func mark() -> void:
	_dirty = true


## Counts `delta` seconds and, when marked or POLL_S passed, hands every clear of `tree` to each planter.
func update(delta: float, planters: Array[MeshPlanter], tree: SceneTree) -> void:
	_left_s -= delta
	if _left_s <= 0.0:
		_left_s = POLL_S
		_dirty = true
	if not _dirty:
		return
	_dirty = false
	for planter in planters:
		planter.set_clears(in_map(tree, planter.map_xform.affine_inverse()))


## Every VegetationClear of `tree` in map coordinates (`to_map`): x, z, radius, edge.
static func in_map(tree: SceneTree, to_map: Transform3D) -> PackedVector4Array:
	var found := PackedVector4Array()
	for row in VegetationClear.world_rows(tree):
		var local := to_map * Vector3(row.x, 0.0, row.y)
		found.append(Vector4(local.x, local.z, row.z, row.w))
	return found
