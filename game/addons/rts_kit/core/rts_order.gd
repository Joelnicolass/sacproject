class_name RtsOrder
extends RefCounted

## An order for a group, as the player (or an AI) asked it: which command, to which units, at which
## point or body, turned how. RtsOrders.apply checks it and turns it into one RtsUnitOrder per unit.
## It holds nodes, so an AI builds one and applies it with no conversion at all. `to_array()` /
## `from_array()` turn it into plain data and back for whatever carries it (a network, a replay, a
## save): the kit sends nothing anywhere.

## Version of the `to_array` layout; `from_array` refuses any other.
const FORMAT := 1
## `from_array` refuses an order with more units than this (data from a network is not trusted).
const MAX_UNITS := 4096

var command: StringName = &""
## The units asked to obey (RtsUnit). Empty for a SIDE command (retreat).
var units: Array[RtsUnit] = []
## Kit point (RtsSpace): the clicked ground, or where the target stood.
var point := Vector3.ZERO
## The body clicked (an enemy, a friend to guard), or null.
var target: Node
## The yaw the formation is turned by (the camera's, RtsPointer.camera_yaw).
var facing := 0.0
## A formation to store on the units before the order uses it (empty = keep theirs).
var formation: StringName = &""
## Wait behind the units' current orders (Shift) instead of replacing them.
var queue := false


static func make(
	p_command: StringName,
	p_units: Array,
	p_point := Vector3.ZERO,
	p_target: Node = null,
	p_facing := 0.0,
	p_formation: StringName = &"",
	p_queue := false
) -> RtsOrder:
	var order := RtsOrder.new()
	order.command = p_command
	for unit in p_units:
		var found := RtsUnit.of(unit)
		if found != null:
			order.units.append(found)
	order.point = p_point
	order.target = p_target
	order.facing = p_facing
	order.formation = p_formation
	order.queue = p_queue
	return order


## Plain data: [FORMAT, command, unit ids, point, target id ("" for none), facing, formation, queue].
## A unit is named by `id_of.call(body)` (a String); without it, by the body's absolute NodePath,
## which every peer of a networked game shares when its scenes match.
func to_array(id_of := Callable()) -> Array:
	var ids := PackedStringArray()
	for unit in units:
		if unit != null and is_instance_valid(unit) and unit.body != null:
			ids.append(_id(unit.body, id_of))
	var target_id := ""
	if target != null and is_instance_valid(target):
		target_id = _id(target, id_of)
	return [FORMAT, String(command), ids, point, target_id, facing, String(formation), queue]


## The order `data` stands for, or null when it is malformed (wrong layout, types or sizes). Ids are
## found with `node_of.call(id)` (returns a Node or null); without it, as NodePaths from `root`'s
## tree. Units that are not found are left out; RtsOrders.apply still checks the rest.
static func from_array(data: Variant, root: Node, node_of := Callable()) -> RtsOrder:
	if not data is Array:
		return null
	var list := data as Array
	if list.size() != 8 or typeof(list[0]) != TYPE_INT or int(list[0]) != FORMAT:
		return null
	if (
		typeof(list[1]) != TYPE_STRING
		or typeof(list[2]) != TYPE_PACKED_STRING_ARRAY
		or typeof(list[3]) != TYPE_VECTOR3
		or typeof(list[4]) != TYPE_STRING
		or typeof(list[5]) != TYPE_FLOAT
		or typeof(list[6]) != TYPE_STRING
		or typeof(list[7]) != TYPE_BOOL
	):
		return null
	var ids := list[2] as PackedStringArray
	if ids.size() > MAX_UNITS:
		return null
	var at := list[3] as Vector3
	var facing_value := float(list[5])
	if not at.is_finite() or not is_finite(facing_value):
		return null
	var order := RtsOrder.new()
	order.command = StringName(list[1])
	for id in ids:
		var unit := RtsUnit.of(_node(id, root, node_of))
		if unit != null:
			order.units.append(unit)
	order.point = at
	var target_id := String(list[4])
	order.target = null if target_id.is_empty() else _node(target_id, root, node_of)
	order.facing = facing_value
	order.formation = StringName(list[6])
	order.queue = bool(list[7])
	return order


static func _id(node: Node, id_of: Callable) -> String:
	if id_of.is_valid():
		return str(id_of.call(node))
	return str(node.get_path()) if node.is_inside_tree() else ""


static func _node(id: String, root: Node, node_of: Callable) -> Node:
	if id.is_empty():
		return null
	if node_of.is_valid():
		var found: Variant = node_of.call(id)
		return found as Node if found is Node and is_instance_valid(found) else null
	if root == null or not root.is_inside_tree():
		return null
	return root.get_tree().root.get_node_or_null(NodePath(id))
