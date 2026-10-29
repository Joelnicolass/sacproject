class_name RtsOrders
extends Node

## Group orders: it checks who may order what, lays the group out in its formation, matches each unit
## to a slot and gives every unit its own order (RtsUnit.give). It sends nothing over any network.
##
## Two ways in. `request(order)` is the local player's: it emits `requested` and hands the order to
## `send`, which applies it here with `local_slot` unless the game set its own `send` (a network
## client sends `order.to_array()` to its server). `apply(order, from_slot)` is the rules: the server,
## a single-player game, an AI or a replay call it with the slot the order comes from, and only that
## slot's units obey.
##
## The formation of the group is the one most of its units keep (a tie: the first in the catalog).
## Units are spaced by the widest of them (min(spacing_per_size · size + spacing_base, max_spacing)),
## the slots are turned by the order's facing (the guarded body's for a GUARD order), and units are
## matched to slots greedily by distance, or row by row (front units to the front row, left to right)
## for a formation of several rows, so no two paths cross.
## Not: what a unit does with its order (the game, RtsUnit.order_started), how an order is chosen
## (RtsOrderInput).

## The local player asked for an order (before `send`). Presentation only: a voice, a sound. Never
## emitted by `apply`.
signal requested(order: RtsOrder)
## `apply` gave `order` to `units` (RtsUnit); an empty list never emits.
signal applied(order: RtsOrder, units: Array)

## The command that only stores a formation on the units: nobody moves.
const FORMATION := &"formation"

@export var commands: RtsCommandCatalog = preload("res://addons/rts_kit/commands/commands.tres")
@export var formations: RtsFormationCatalog = preload(
	"res://addons/rts_kit/orders/formations/formations.tres"
)
## The slot of the player of this process: `request` applies with it when `send` is not replaced.
@export var local_slot := 1
## Most units one order moves; 0 = no limit.
@export var max_units := 0
@export var spacing_per_size := 1.25
@export var spacing_base := 0.85
@export var max_spacing := 10.0
## A `retarget_nearest` command (attack a unit) makes each unit take the foe nearest its slot within
## this range.
@export var retarget_range := 100.0

## Where `request` hands an order: `func(order: RtsOrder) -> void`. Default: `apply(order,
## local_slot)` here. A network client sets its own (send `order.to_array()` to the server, which
## calls `apply(RtsOrder.from_array(data, self), sender_slot)`).
var send: Callable
## The side's anchor a `to_anchor` command (retreat) goes to: `func(slot: int) -> Node`. Default: the
## first unit of that slot tagged `anchor_tag`.
var anchor_for: Callable
## The foe nearest a point for a `retarget_nearest` command: `func(unit: RtsUnit, point: Vector3,
## reach: float) -> Node`. Default: the nearest targetable unit `unit.is_foe` within `reach`.
var closest_foe: Callable
@export var anchor_tag: StringName = &"anchor"

## Microseconds the last apply took, and the rows and width of its formation (debug overlays).
var last_apply_us := 0
var last_rows := 0
var last_width := 0.0


func _init() -> void:
	send = func(order: RtsOrder) -> void: apply(order, local_slot)
	anchor_for = _default_anchor
	closest_foe = _default_closest_foe


## The local player's order: `requested`, then `send`.
func request(order: RtsOrder) -> void:
	if order == null:
		return
	requested.emit(order)
	send.call(order)


## `request` from its parts.
func issue(
	command: StringName,
	units: Array,
	point := Vector3.ZERO,
	target: Node = null,
	facing := 0.0,
	formation := &"",
	queue := false
) -> void:
	request(RtsOrder.make(command, units, point, target, facing, formation, queue))


## Applies `order` as the player of `from_slot` asked it: only that slot's orderable units that accept
## the command obey. True when at least one unit got it (or a formation was stored).
func apply(order: RtsOrder, from_slot: int) -> bool:
	if order == null or from_slot <= 0:
		return false
	if order.command == FORMATION:
		return _store_formation(order, from_slot) > 0
	var type := commands.find(order.command) if commands else null
	if type == null:
		return false
	# An order that carries a formation (the radial menu's pick) stores it first: the order itself
	# already uses it.
	if order.formation != &"":
		_store_formation(order, from_slot)
	var started := Time.get_ticks_usec()
	var target := order.target if order.target != null and is_instance_valid(order.target) else null
	if type.to_anchor:
		var anchor: Variant = anchor_for.call(from_slot)
		target = anchor as Node if anchor is Node and is_instance_valid(anchor) else null
		if target == null:
			return false
	var units: Array[RtsUnit] = []
	if type.scope == RtsCommandType.Scope.SIDE:
		units = _side_units(from_slot, type, target)
	else:
		units = _own_units(from_slot, order.units, target, type)
	if units.is_empty():
		return false
	var point := RtsSpace.position_of(target) if target else order.point
	if not type.uses_formation:
		for unit in units:
			unit.give(RtsUnitOrder.new(type, target, point, Vector2.ZERO, 0.0, &""), order.queue)
		last_apply_us = Time.get_ticks_usec() - started
		applied.emit(order, units)
		return true
	var formation := _majority_formation(units)
	var slots := _formation(formation, units, type, target)
	var spots: Array[Vector3] = []
	for offset in slots:
		spots.append(_spot(type, order.point, target, offset, order.facing))
	var yaw := _facing_of(type, target, order.facing)
	var row_size := formation.match_row_size(units.size()) if formation else 0
	var matched := (
		match_greedy(units, spots)
		if last_rows <= 1 or row_size <= 0
		else match_rows(units, slots, yaw, row_size)
	)
	var retarget := type.retarget_nearest and target != null and RtsUnit.of(target) != null
	var formation_id := formation.id if formation else &""
	for i in units.size():
		var unit := units[i]
		var index: int = matched[i]
		if index < 0:
			continue
		var foe := target
		if retarget:
			var near: Variant = closest_foe.call(unit, spots[index], retarget_range)
			foe = near as Node if near is Node and is_instance_valid(near) else target
		unit.give(RtsUnitOrder.new(type, foe, point, slots[index], yaw, formation_id), order.queue)
	last_apply_us = Time.get_ticks_usec() - started
	applied.emit(order, units)
	return true


## An AI's order, no conversion: `apply` of an order made from these parts.
func apply_units(
	from_slot: int,
	units: Array,
	command: StringName,
	point := Vector3.ZERO,
	target: Node = null,
	facing := 0.0,
	queue := false
) -> bool:
	return apply(RtsOrder.make(command, units, point, target, facing, &"", queue), from_slot)


## True when the player of `slot` may order `unit` now.
func can_order(unit: RtsUnit, slot: int) -> bool:
	return (
		unit != null
		and is_instance_valid(unit)
		and unit.is_inside_tree()
		and unit.owner_slot == slot
		and unit.orderable
	)


## The spacing the group of `units` stands at.
func spacing_for(units: Array) -> float:
	var widest := 0.0
	for unit in units:
		widest = maxf(widest, (unit as RtsUnit).size)
	return minf(spacing_per_size * widest + spacing_base, max_spacing)


## "formation": `order.formation` kept on each of the slot's units of the order. Nobody moves; an id
## the catalog does not know changes nothing. Returns how many units kept it.
func _store_formation(order: RtsOrder, from_slot: int) -> int:
	if formations == null or not formations.has_id(order.formation):
		return 0
	var kept := 0
	for candidate in order.units:
		if can_order(candidate, from_slot):
			candidate.formation = order.formation
			kept += 1
	return kept


## The formation most of the group keeps; a tie goes to the one first in the catalog.
func _majority_formation(units: Array[RtsUnit]) -> RtsFormation:
	if formations == null:
		return null
	var counts := {}
	for unit in units:
		var id: StringName = unit.formation if unit.formation != &"" else formations.default_id
		counts[id] = int(counts.get(id, 0)) + 1
	var best := formations.default_formation()
	var best_count := 0
	for formation in formations.formations:
		if formation == null:
			continue
		var count := int(counts.get(formation.id, 0))
		if count > best_count:
			best = formation
			best_count = count
	return best


## The slot's units the order names: orderable, not the target, not twice, taking the command; at most
## `max_units`.
func _own_units(
	slot: int, candidates: Array[RtsUnit], target: Node, type: RtsCommandType
) -> Array[RtsUnit]:
	var units: Array[RtsUnit] = []
	var seen := {}
	for unit in candidates:
		if (
			unit == null
			or not is_instance_valid(unit)
			or unit.body == target
			or seen.has(unit.get_instance_id())
			or not can_order(unit, slot)
			or not unit.accepts(type.id)
		):
			continue
		seen[unit.get_instance_id()] = true
		units.append(unit)
		if max_units > 0 and units.size() >= max_units:
			break
	return units


## Every orderable unit of the slot that takes the command (a SIDE command), the target excepted.
func _side_units(slot: int, type: RtsCommandType, target: Node) -> Array[RtsUnit]:
	var units: Array[RtsUnit] = []
	for unit in RtsUnit.all(get_tree()):
		if unit.body != target and can_order(unit, slot) and unit.accepts(type.id):
			units.append(unit)
	return units


## The slots (right, forward) of `formation` for the group. Guarding or attacking a body changes them.
func _formation(
	formation: RtsFormation, units: Array[RtsUnit], type: RtsCommandType, target: Node
) -> Array[Vector2]:
	var spacing := spacing_for(units)
	var around := 0.0
	if target:
		around = maxf(0.5 * (spacing_per_size * spacing + _half_size(target)), spacing)
	var total := units.size()
	if formation == null:
		last_rows = 1
		last_width = 0.0
		var flat: Array[Vector2] = []
		flat.resize(total)
		flat.fill(Vector2.ZERO)
		return flat
	last_rows = formation.row_count(total)
	last_width = formation.row_width(total, spacing)
	return formation.slots(total, spacing, around, type.role)


func _spot(
	type: RtsCommandType, point: Vector3, target: Node, offset: Vector2, facing: float
) -> Vector3:
	var base := RtsSpace.position_of(target) if target else point
	var ahead := RtsSpace.ahead(_facing_of(type, target, facing))
	return base + ahead.cross(Vector3.UP) * offset.x + ahead * offset.y


## The yaw a formation turns by: the guarded body's for a GUARD order on a body, else `facing`.
func _facing_of(type: RtsCommandType, target: Node, facing: float) -> float:
	if type.role == RtsCommandType.Role.GUARD and target:
		var unit := RtsUnit.of(target)
		return unit.facing_yaw() if unit else RtsSpace.yaw_of_node(target)
	return facing


## Greedy: the shortest unit-to-slot distance first, until every unit has a slot. Returns the slot
## index of each unit (-1 when there are more units than slots).
static func match_greedy(units: Array[RtsUnit], spots: Array[Vector3]) -> PackedInt32Array:
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
		var at := units[u].position()
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


## Rows: the units furthest along `yaw` take the front row, the next ones the row behind, and so on;
## inside a row they keep their order across (left to right). No two paths cross; ties go by index.
## (Greedy over a crowd of 150 crossed the formation: the front of the crowd took the back rows.)
static func match_rows(
	units: Array[RtsUnit], slots: Array[Vector2], yaw: float, row_size: int
) -> PackedInt32Array:
	var n := units.size()
	var result := PackedInt32Array()
	result.resize(n)
	result.fill(-1)
	var ahead := RtsSpace.ahead(yaw)
	var right := ahead.cross(Vector3.UP)
	var order: Array = []
	for u in n:
		order.append([-ahead.dot(units[u].position()), u])
	order.sort()
	var per_row := mini(row_size, n)
	var start := 0
	while start < mini(n, slots.size()):
		var stop := mini(start + per_row, mini(n, slots.size()))
		var row: Array = []
		for k in range(start, stop):
			var u: int = order[k][1]
			row.append([right.dot(units[u].position()), u])
		row.sort()
		# The slots of this row, left to right (formations lay them out in that order).
		for k in row.size():
			result[row[k][1]] = start + k
		start = stop
	return result


## Half the width of a body: its unit's size / 2, 0 for a body that is no unit.
static func _half_size(body: Node) -> float:
	var unit := RtsUnit.of(body)
	return unit.size * 0.5 if unit else 0.0


func _default_anchor(slot: int) -> Node:
	for unit in RtsUnit.all(get_tree()):
		if unit.owner_slot == slot and unit.has_tag(anchor_tag):
			return unit.body
	return null


func _default_closest_foe(unit: RtsUnit, point: Vector3, reach: float) -> Node:
	var best: Node = null
	var best_d := reach
	for other in RtsUnit.all(get_tree()):
		if not other.targetable or not unit.is_foe(other):
			continue
		var d := point.distance_to(other.position())
		if d <= best_d:
			best_d = d
			best = other.body
	return best
