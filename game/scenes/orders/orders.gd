extends Node

## RTS orders, server-authoritative.
## The owner calls request(); a client sends submit_order and the server checks every unit's
## owner_slot. The selection stands in the formation most of its creatures keep (the default is the line) turned by the
## camera facing; units are matched to slots greedily by distance. The "formation" command stores a formation on each
## creature and moves nobody. Retreat orders every creature of the side, not the selection.
## Ref: RFC-038; sacengine Command → ObjectState.applyOrder (state.d:29140), Formation / getFormationOffsets (state.d:417), greedy slot matching (state.d:29205), retreat (state.d:29174).

const UnitOrders := preload("res://scenes/units/unit_orders.gd")

## The local player asked for an order (request(), the owner side, before it is sent or applied). Presentation only
## (CommandVoice, RFC-052 052e); the AI's apply_for and the server's submit_order do not emit it.
signal requested(units: Array, command: String)

## Not a UnitOrders.Command: it stores a formation on the creatures and moves nobody.
const FORMATION_COMMAND := "formation"

const COMMANDS := {
	"move": UnitOrders.Command.MOVE,
	"attack": UnitOrders.Command.ATTACK,
	"guard": UnitOrders.Command.GUARD,
	"guard_area": UnitOrders.Command.GUARD_AREA,
	"advance": UnitOrders.Command.ADVANCE,
	"retreat": UnitOrders.Command.RETREAT,
}

## The formations the server accepts (a Resource never travels over the network, only its id).
@export var catalog: FormationCatalog = preload("res://data/orders/formations.tres")
## 0 = no limit (RFC-025); the original cuts at numCreaturesInGroup = 12.
@export var max_units := 0
## getFormationOffsets: unitDistance = min(1.25·max(size) + 0.85, 10).
@export var spacing_per_size := 1.25
@export var spacing_base := 0.85
@export var max_spacing := 10.0
## An attack on a creature retargets each unit to the enemy
## creature closest to its own slot within this range.
## Ref: attackDistance, state.d:13609.
@export var retarget_range := 100.0
## With the DebugLog category `orders` on, every applied human order prints «orden <command> <n>». The AI's orders
## (`apply_for`) print too only with `log_ai_orders`: thousands per match.
@export var log_ai_orders := false


## Owner side. `facing` is the camera yaw (forward = (sin, 0, cos)). `formation_id` only matters for "formation".
func request(units: Array, command: String, point: Vector3, target: Node3D, facing: float, formation_id := &"") -> void:
	requested.emit(units, command)
	var paths := _paths_of(units)
	var target_path := str(target.get_path()) if target else ""
	if MpAuthority.should_send_command():
		submit_order.rpc_id(MpAuthority.SERVER_PEER, paths, command, point, target_path, facing, formation_id)
		return
	_apply(MpKit.local_slot(), paths, command, point, target_path, facing, formation_id)


## The orders of a side that has no peer behind it (the AI, RFC-024 024c): server or solo only, no RPC. It is
## `request` with the slot given instead of read from MpKit.local_slot(); _apply still checks that every unit
## belongs to `slot`, so the AI can order exactly what a human of that slot could.
## The AI does not choose formations (RFC-038 P5): its creatures keep the line.
func apply_for(slot: int, units: Array, command: String, point: Vector3, target: Node3D, facing := 0.0, formation_id := &"") -> void:
	if slot <= 0 or (MpKit.is_networked() and not MpKit.is_server()):
		return
	## The nodes go straight in: the AI orders thousands of times per match and the roundtrip through NodePaths cost half of each order.
	_apply(slot, PackedStringArray(), command, point, "", facing, formation_id, units, target)


static func _paths_of(units: Array) -> PackedStringArray:
	var paths := PackedStringArray()
	for unit in units:
		if unit is Node and is_instance_valid(unit):
			paths.append(str((unit as Node).get_path()))
	return paths


@rpc("any_peer", "call_remote", "reliable")
func submit_order(unit_paths: PackedStringArray, command: String, target_pos: Vector3, target_path: String, facing: float, formation_id: StringName) -> void:
	var slot := MpAuthority.command_slot(self)
	if slot <= 0:
		return
	_apply(slot, unit_paths, command, target_pos, target_path, facing, formation_id)


## Microseconds the last _apply took, and the last formation (rows, widest row in meters),
## for debug overlays.
var last_apply_us := 0
var last_rows := 0
var last_width := 0.0


func _apply(slot: int, unit_paths: PackedStringArray, command: String, point: Vector3, target_path: String, facing: float, formation_id: StringName, unit_nodes: Array = [], target_node: Node3D = null) -> void:
	if command == FORMATION_COMMAND:
		_set_formation(slot, unit_paths, formation_id, unit_nodes)
		return
	if not COMMANDS.has(command):
		return
	## An order that carries a formation (the radial menu's pick) stores it first: the order itself already uses it.
	if formation_id != &"":
		_set_formation(slot, unit_paths, formation_id, unit_nodes)
	var started := Time.get_ticks_usec()
	var kind: int = COMMANDS[command]
	var target := target_node if target_node != null else (get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null)
	if kind == UnitOrders.Command.RETREAT:
		_retreat(slot)
		return
	var units := _own_units(slot, unit_paths, target, kind, unit_nodes)
	if units.is_empty():
		return
	var formation := _majority_formation(units)
	var slots := _formation(formation, units, kind, target)
	var spots: Array[Vector3] = []
	for offset in slots:
		spots.append(_spot(kind, point, target, offset, facing))
	var yaw := _yaw_of(target) if kind == UnitOrders.Command.GUARD and target else facing
	var row_size := formation.match_row_size(units.size())
	var matched := _match(units, spots) if last_rows <= 1 or row_size <= 0 else _match_rows(units, slots, yaw, row_size)
	var retarget := kind == UnitOrders.Command.ATTACK and target != null and target.is_in_group("unit")
	for i in units.size():
		var unit: Node3D = units[i]
		var index: int = matched[i]
		var foe := target
		if retarget:
			foe = _closest_enemy_creature(unit, spots[index])
			if foe == null:
				foe = target
		var order_point := target.global_position if target else point
		var order_facing := _yaw_of(target) if kind == UnitOrders.Command.GUARD and target else facing
		(unit.get_node("Orders") as UnitOrders).give(kind as UnitOrders.Command, foe, order_point, slots[index], order_facing)
	last_apply_us = Time.get_ticks_usec() - started
	if unit_nodes.is_empty() or log_ai_orders:
		if DebugLog.on(&"orders"): print("orden %s %d" % [command, units.size()])


## "formation": keeps `formation_id` on each creature of the slot that was asked for. Nobody moves; an id the catalog does
## not know changes nothing.
func _set_formation(slot: int, unit_paths: PackedStringArray, formation_id: StringName, unit_nodes: Array) -> void:
	if catalog == null or not catalog.has_id(formation_id):
		return
	for unit in _own_units(slot, unit_paths, null, UnitOrders.Command.MOVE, unit_nodes):
		unit.get_node("Orders").set("formation_id", formation_id)
	if unit_nodes.is_empty() or log_ai_orders:
		if DebugLog.on(&"orders"): print("orden formation %s" % formation_id)


## The formation most of the group keeps; a tie goes to the one first in the catalog (the original's order).
func _majority_formation(units: Array[Node3D]) -> FormationType:
	var counts := {}
	for unit in units:
		var id: StringName = unit.get_node("Orders").get("formation_id")
		counts[id] = int(counts.get(id, 0)) + 1
	var best: FormationType = catalog.default_formation()
	var best_count := 0
	for formation in catalog.formations:
		var count := int(counts.get(formation.id, 0))
		if count > best_count:
			best = formation
			best_count = count
	return best


func _retreat(slot: int) -> void:
	var wizard: Node3D = null
	for node in get_tree().get_nodes_in_group("wizard"):
		if int(node.get("owner_slot")) == slot:
			wizard = node
	if wizard == null:
		return
	for unit in get_tree().get_nodes_in_group("unit"):
		if _can_order(unit, slot):
			(unit.get_node("Orders") as UnitOrders).give(UnitOrders.Command.RETREAT, wizard, wizard.global_position, Vector2.ZERO, 0.0)


## Pacifists refuse attack and advance.
## Ref: canOrder (state.d:1140), sacengine order().
func _own_units(slot: int, unit_paths: PackedStringArray, target: Node3D, kind: int, unit_nodes: Array = []) -> Array[Node3D]:
	var units: Array[Node3D] = []
	var seen := {}
	var candidates: Array = unit_nodes.duplicate()
	for path in unit_paths:
		candidates.append(get_node_or_null(path))
	for candidate in candidates:
		var unit := candidate as Node3D if candidate != null and is_instance_valid(candidate) else null
		if unit == null or unit == target or seen.has(unit.get_instance_id()) or not _can_order(unit, slot):
			continue
		var pacifist: bool = unit.get("type") == null or unit.get("type").aggressiveness <= 0
		if pacifist and (kind == UnitOrders.Command.ATTACK or kind == UnitOrders.Command.ADVANCE):
			continue
		seen[unit.get_instance_id()] = true
		units.append(unit)
		if max_units > 0 and units.size() >= max_units:
			break
	return units


func _can_order(unit: Node, slot: int) -> bool:
	if not unit.is_in_group("unit") or int(unit.get("owner_slot")) != slot:
		return false
	var body := unit as UnitBody
	return body != null and not body.is_dead() and not body.is_summoning() and body.has_node("Orders")


## The slots (right, forward) of `formation` for the group. Guarding or attacking a body changes them.
## Ref: state.d:429.
func _formation(formation: FormationType, units: Array[Node3D], kind: int, target: Node3D) -> Array[Vector2]:
	var size := 0.0
	for unit in units:
		size = maxf(size, 2.0 * _half_size(unit))
	## getFormationOffsets: unitDistance = min(1.25·max(size) + 0.85, 10).
	var spacing := minf(spacing_per_size * size + spacing_base, max_spacing)
	var around := 0.0
	if target:
		around = maxf(0.5 * (spacing_per_size * spacing + _half_size(target)), spacing)
	var total := units.size()
	last_rows = formation.row_count(total)
	last_width = formation.row_width(total, spacing)
	return formation.slots(total, spacing, around, kind)


func _spot(kind: int, point: Vector3, target: Node3D, offset: Vector2, facing: float) -> Vector3:
	var base := target.global_position if target else point
	var yaw := _yaw_of(target) if kind == UnitOrders.Command.GUARD and target else facing
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	return base + ahead.cross(Vector3.UP) * offset.x + ahead * offset.y


## Greedy: the shortest unit-to-slot distance first, until every unit has a slot.
func _match(units: Array[Node3D], spots: Array[Vector3]) -> PackedInt32Array:
	var n := units.size()
	var m := spots.size()
	var result := PackedInt32Array()
	result.resize(n)
	result.fill(-1)
	if n == 0 or m == 0:
		return result
	# Each pair is one float: floor(d² · 1000) · total + index, so the native sort orders the pairs
	# by distance (ties by index) without a GDScript comparator. Exact below 2^53.
	var total := n * m
	var cap := floorf(9007199254740992.0 / float(total)) - 1.0
	var keys := PackedFloat64Array()
	keys.resize(total)
	var k := 0
	for u in n:
		var at := units[u].global_position
		for s in m:
			keys[k] = minf(floorf(at.distance_squared_to(spots[s]) * 1000.0), cap) * total + k
			k += 1
	keys.sort()
	var taken := PackedByteArray()
	taken.resize(m)
	var left := mini(n, m)
	for key in keys:
		var index := int(key) % total
		var u := floori(float(index) / m)
		var s := index % m
		if result[u] >= 0 or taken[s] != 0:
			continue
		result[u] = s
		taken[s] = 1
		left -= 1
		if left == 0:
			break
	return result


## The rows of a formation larger than one line (the port's extension, `RowFormation.row_size`): the original matches one
## line of at most 12 creatures greedily, and greedy over 150 bodies crossed the formation: the front of the
## crowd took the back rows and everyone else walked through the bodies already parked, which carried them off their slots.
## Here the units furthest along `yaw` take the front row, the next ones the row
## behind, and so on; inside a row they keep their order across (left to right). No two paths cross. Ties go by index.
## Ref: F88 round 3; sacengine numCreaturesInGroup = 12, state.d:29205.
func _match_rows(units: Array[Node3D], slots: Array[Vector2], yaw: float, row_size: int) -> PackedInt32Array:
	var n := units.size()
	var result := PackedInt32Array()
	result.resize(n)
	result.fill(-1)
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := ahead.cross(Vector3.UP)
	var order: Array = []
	for u in n:
		order.append([-ahead.dot(units[u].global_position), u])
	order.sort()
	var per_row := mini(row_size, n)
	var start := 0
	while start < mini(n, slots.size()):
		var stop := mini(start + per_row, mini(n, slots.size()))
		var row: Array = []
		for k in range(start, stop):
			var u: int = order[k][1]
			row.append([right.dot(units[u].global_position), u])
		row.sort()
		## The slots of this row, left to right (_formation lays them out in that order).
		for k in row.size():
			result[row[k][1]] = start + k
		start = stop
	return result


func _closest_enemy_creature(unit: Node3D, spot: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := retarget_range
	for node in get_tree().get_nodes_in_group("unit"):
		if not (unit as UnitBody).engagement.is_foe(node):
			continue
		var d := spot.distance_to((node as Node3D).global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best


## Half the body width: the larger of the collision radius and the melee reach.
static func _half_size(body: Node3D) -> float:
	return BodyFacts.of_body(body).half_size_m()


static func _yaw_of(node: Node3D) -> float:
	if node.has_method("facing_flat"):  # dynamic: unit, wizard and doctor bodies all face
		var ahead: Vector3 = node.call("facing_flat")
		return atan2(ahead.x, ahead.z)
	return node.rotation.y
