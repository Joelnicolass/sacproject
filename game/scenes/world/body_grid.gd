class_name BodyGrid
extends RefCounted

## The obstacles of BodySeparation filed by cell, once per physics tick (RFC-024 addendum 1, 024b2; split out of
## BodySeparation in RFC-027 027d, REVIEW-F87 N1). Every obstacle of the groups, in the order of
## BodySeparation._obstacles (group by group, tree order inside each), gets an index; a cell keeps the indices of the
## obstacles whose position fell in it. The position and the box of each are kept as they were when the grid was
## filed (the first resolve of the tick, before any body moved), as sacengine builds state.proximity once per frame.
## Pure bookkeeping: it decides nothing about pushes or cuts.

## Side of a cell, meters. Any size gives the same candidates that can touch a body (BodySeparation asks for every
## cell within reach); a smaller cell gives fewer that cannot. RFC-027 027d: 2.5 instead of 16, where a crowd of 150
## put most of its bodies in the cells around each one.
const CELL := 2.5

## The obstacles filed, by index.
var filed: Array[Node3D] = []
## _box of each filed obstacle: half width and height (the box of this tick).
var halves := PackedFloat64Array()
var heights := PackedFloat64Array()
## Position of each filed obstacle when it was filed.
var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
var zs := PackedFloat64Array()
## 1 for a filed obstacle that left the tree since it was filed (SceneTree.node_removed): only those can be freed
## or out of the tree now, so only those pay is_instance_valid and is_inside_tree per pair.
var left := PackedByteArray()
## The widest half of any filed obstacle.
var widest := 0.0

var _tick := -1
var _members := -1
## cell key -> PackedInt32Array of indices, ascending.
var _cells: Dictionary = {}
## instance id -> indices in `filed` (a body in two groups is filed twice).
var _ids: Dictionary = {}


## Files the obstacles again when the physics tick changed or when a body joined or left the groups since (a spawn
## or a corpse); otherwise does nothing. A filing in the middle of a tick (a body spawned or freed by the physics of a
## body resolved earlier) reads every position again: the bodies already moved this tick are filed where they are now,
## not where the tick started, so for the rest of that tick the snapshot is no longer the one of the tick start.
## Side effect: the first call on a tree connects `tree.node_removed` to this grid (and keeps it connected), so a
## filed body that leaves the tree between two filings is marked in `left` (see _on_node_removed).
func file(tree: SceneTree, groups: Array[StringName]) -> void:
	var tick := Engine.get_physics_frames()
	var members := 0
	for group in groups:
		members += tree.get_node_count_in_group(group)
	if tick == _tick and members == _members:
		return
	_tick = tick
	_members = members
	filed.clear()
	_cells.clear()
	halves.clear()
	heights.clear()
	xs.clear()
	ys.clear()
	zs.clear()
	left.clear()
	_ids.clear()
	widest = 0.0
	if not tree.node_removed.is_connected(_on_node_removed):
		tree.node_removed.connect(_on_node_removed)
	for group in groups:
		for node in tree.get_nodes_in_group(group):
			if not node is Node3D or not BodySeparation.is_obstacle(node):
				continue
			var obstacle := node as Node3D
			var index := filed.size()
			filed.append(obstacle)
			var box := BodySeparation.box_of(obstacle)
			halves.append(box.x)
			heights.append(box.y)
			left.append(0)
			var id := obstacle.get_instance_id()
			var same: PackedInt32Array = _ids.get(id, PackedInt32Array())
			same.append(index)
			_ids[id] = same
			widest = maxf(widest, box.x)
			var at := obstacle.global_position
			xs.append(at.x)
			ys.append(at.y)
			zs.append(at.z)
			var key := key_of(floori(at.x / CELL), floori(at.z / CELL))
			var cell: PackedInt32Array = _cells.get(key, PackedInt32Array())
			cell.append(index)
			_cells[key] = cell


func is_empty() -> bool:
	return filed.is_empty()


## The indices filed in the cells first_x..last_x by first_z..last_z, ascending (the order of the full list).
func indices_in(first_x: int, last_x: int, first_z: int, last_z: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for cx in range(first_x, last_x + 1):
		for cz in range(first_z, last_z + 1):
			var key := key_of(cx, cz)
			if _cells.has(key):
				indices.append_array(_cells[key])
	indices.sort()
	return indices


## Connected by file() (its side effect): marks the filed copies of `node` as gone until the next filing.
func _on_node_removed(node: Node) -> void:
	var same: Variant = _ids.get(node.get_instance_id())
	if same == null:
		return
	for index in same:
		left[index] = 1


static func key_of(cx: int, cz: int) -> int:
	return (cx + 32768) * 65536 + (cz + 32768)
