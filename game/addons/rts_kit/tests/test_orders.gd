extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsOrders: who obeys, the formation of the group, the slot match, retarget, retreat, the plain data
## of an order, and `send`.

var orders: RtsOrders
## RtsUnit -> the RtsUnitOrder it got last.
var got := {}


func _setup() -> void:
	orders = RtsOrders.new()
	root.add_child(orders)
	got.clear()


func _unit(at: Vector3, slot := 1, size := 1.0, flat := false) -> RtsUnit:
	var body: Node = Node2D.new() if flat else Node3D.new()
	root.add_child(body)
	RtsSpace.place(body, at)
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	unit.size = size
	body.add_child(unit)
	unit.order_started.connect(func(order: RtsUnitOrder, _replaced: RtsUnitOrder) -> void: got[unit] = order)
	return unit


func test_only_the_slots_own_orderable_units_obey() -> void:
	_setup()
	var mine := _unit(Vector3(0, 0, 0))
	var theirs := _unit(Vector3(1, 0, 0), 2)
	var busy := _unit(Vector3(2, 0, 0))
	busy.orderable = false
	var ok := orders.apply(RtsOrder.make(&"move", [mine, theirs, busy, mine], Vector3(10, 0, 0)), 1)
	check(ok and got.has(mine), "the slot's unit obeys")
	check(not got.has(theirs), "another slot's unit does not")
	check(not got.has(busy), "an unorderable unit does not")
	check(not orders.apply(RtsOrder.make(&"move", [theirs], Vector3.ZERO), 1), "nothing to order: false")
	check(not orders.apply(RtsOrder.make(&"fly", [mine], Vector3.ZERO), 1), "an unknown command: false")
	check(not orders.apply(RtsOrder.make(&"move", [mine], Vector3.ZERO), 0), "slot 0 orders nobody")


func test_a_refused_command_skips_the_unit() -> void:
	_setup()
	var pacifist := _unit(Vector3.ZERO)
	pacifist.refused = [&"attack", &"attack_move"]
	var fighter := _unit(Vector3(1, 0, 0))
	var foe := _unit(Vector3(5, 0, 0), 2)
	orders.apply(RtsOrder.make(&"attack", [pacifist, fighter], foe.position(), foe.body), 1)
	check(got.has(fighter) and not got.has(pacifist), "the pacifist refuses an attack")
	orders.apply(RtsOrder.make(&"move", [pacifist], Vector3.ZERO), 1)
	check(got.has(pacifist), "but moves")


func test_max_units() -> void:
	_setup()
	orders.max_units = 2
	var units: Array = []
	for i in 4:
		units.append(_unit(Vector3(i, 0, 0)))
	orders.apply(RtsOrder.make(&"move", units, Vector3(0, 0, 10)), 1)
	check(got.size() == 2 and got.has(units[0]) and got.has(units[1]), "the first two only")


func test_spacing_and_slots_in_the_line() -> void:
	_setup()
	var a := _unit(Vector3(-5, 0, 0))
	var b := _unit(Vector3(0, 0, 0))
	var c := _unit(Vector3(5, 0, 0), 1, 2.0)
	check(near(orders.spacing_for([a, b, c]), minf(1.25 * 2.0 + 0.85, 10.0)), "the widest unit sets the spacing")
	# Facing yaw 0: forward +Z, right -X. The line's slots are -s, 0, +s along right.
	orders.apply(RtsOrder.make(&"move", [a, b, c], Vector3(0, 0, 10), null, 0.0), 1)
	var s := 1.25 * 2.0 + 0.85
	var spots := {}
	for unit in [a, b, c]:
		spots[unit] = (got[unit] as RtsUnitOrder).spot()
	check(near(spots[a], Vector3(-s, 0, 10)), "the leftmost unit (x -5) takes the slot at -X: %s" % spots[a])
	check(near(spots[b], Vector3(0, 0, 10)), "the middle one the middle: %s" % spots[b])
	check(near(spots[c], Vector3(s, 0, 10)), "the rightmost the slot at +X: %s" % spots[c])
	check((got[a] as RtsUnitOrder).formation == &"line", "they stood in the line")
	check(near(orders.spacing_for([a]), 1.25 + 0.85) and near(orders.spacing_for([_unit(Vector3.ZERO, 1, 100.0)]), 10.0), "capped at max_spacing")


func test_the_majority_formation_and_its_tie() -> void:
	_setup()
	var a := _unit(Vector3(0, 0, 0))
	var b := _unit(Vector3(1, 0, 0))
	var c := _unit(Vector3(2, 0, 0))
	a.formation = &"wedge"
	b.formation = &"wedge"
	orders.apply(RtsOrder.make(&"move", [a, b, c], Vector3.ZERO), 1)
	check((got[c] as RtsUnitOrder).formation == &"wedge", "two wedges beat one line")
	b.formation = &"line"
	c.formation = &"skirmish"
	a.formation = &"skirmish"
	b.formation = &"wedge"
	c.formation = &"line"
	orders.apply(RtsOrder.make(&"move", [a, b, c], Vector3.ZERO), 1)
	check((got[a] as RtsUnitOrder).formation == &"line", "a three-way tie goes to the first in the catalog (line)")


func test_the_formation_command_moves_nobody() -> void:
	_setup()
	var a := _unit(Vector3.ZERO)
	var foreign := _unit(Vector3.ONE, 2)
	check(orders.apply(RtsOrder.make(RtsOrders.FORMATION, [a, foreign], Vector3.ZERO, null, 0.0, &"phalanx"), 1), "stored")
	check(a.formation == &"phalanx" and foreign.formation == &"", "on the slot's unit only")
	check(got.is_empty(), "nobody got an order")
	check(not orders.apply(RtsOrder.make(RtsOrders.FORMATION, [a], Vector3.ZERO, null, 0.0, &"blob"), 1) and a.formation == &"phalanx", "an unknown formation changes nothing")
	orders.apply(RtsOrder.make(&"move", [a], Vector3.ZERO, null, 0.0, &"circle"), 1)
	check(a.formation == &"circle" and (got[a] as RtsUnitOrder).formation == &"circle", "an order that carries a formation stores and uses it")


func test_guard_turns_with_the_body_and_stands_around_it() -> void:
	_setup()
	var a := _unit(Vector3(0, 0, 0))
	var friend := _unit(Vector3(0, 0, 20), 1, 2.0)
	(friend.body as Node3D).rotation.y = PI * 0.5
	orders.apply(RtsOrder.make(&"guard", [a], Vector3.ZERO, friend.body, 0.0), 1)
	var order := got[a] as RtsUnitOrder
	check(order.target == friend.body and near(order.point, Vector3(0, 0, 20)), "the target and its place")
	check(near(order.facing, PI * 0.5), "turned the way the guarded body faces")
	check(order.slot.x != 0.0 or order.slot.y != 0.0, "a slot around the body, not on it: %s" % order.slot)
	(friend.body as Node3D).position = Vector3(50, 0, 0)
	check(near(order.spot(), Vector3(50, 0, 0) + RtsSpace.right(order.facing) * order.slot.x + RtsSpace.ahead(order.facing) * order.slot.y), "the spot follows the body")


func test_attack_retargets_to_the_foe_nearest_each_slot() -> void:
	_setup()
	# Two units, a line at spacing 2.1 around the target: their spots are 1.05 to each side of it.
	var a := _unit(Vector3(10, 0, 0))
	var b := _unit(Vector3(-10, 0, 0))
	var target := _unit(Vector3(0, 0, 50), 2)
	var other := _unit(Vector3(1.05, 0, 50), 2)
	var ghost := _unit(Vector3(-1.05, 0, 50), 2)
	ghost.targetable = false
	orders.apply(RtsOrder.make(&"attack", [a, b], target.position(), target.body, 0.0), 1)
	check(got.has(a) and got.has(b), "both attack")
	check((got[a] as RtsUnitOrder).target == other.body, "the unit whose spot a foe stands on takes that foe")
	check((got[b] as RtsUnitOrder).target == target.body, "an untargetable foe is never taken: the clicked one")
	orders.retarget_range = -1.0
	orders.apply(RtsOrder.make(&"attack", [a, b], target.position(), target.body, 0.0), 1)
	check((got[a] as RtsUnitOrder).target == target.body and (got[b] as RtsUnitOrder).target == target.body, "no foe in range: the clicked one")


func test_retreat_calls_the_whole_side_to_its_anchor() -> void:
	_setup()
	var hero := _unit(Vector3(0, 0, -40))
	hero.tags = [&"anchor"]
	hero.selectable = false
	var a := _unit(Vector3(5, 0, 0))
	var b := _unit(Vector3(6, 0, 0))
	var foreign := _unit(Vector3(7, 0, 0), 2)
	check(orders.apply(RtsOrder.make(&"retreat", [], Vector3.ZERO), 1), "retreat applies with no units named")
	check(got.has(a) and got.has(b) and not got.has(foreign) and not got.has(hero), "every unit of the side but the anchor")
	var order := got[a] as RtsUnitOrder
	check(order.target == hero.body and near(order.point, hero.position()) and order.slot == Vector2.ZERO, "to the anchor, no formation")
	hero.tags = []
	got.clear()
	check(not orders.apply(RtsOrder.make(&"retreat", [], Vector3.ZERO), 1) and got.is_empty(), "no anchor: nothing")
	orders.anchor_for = func(_slot: int) -> Node: return foreign.body
	check(orders.apply(RtsOrder.make(&"retreat", [], Vector3.ZERO), 1), "a game's anchor rule")


func test_plain_data_round_trip() -> void:
	_setup()
	var a := _unit(Vector3.ZERO)
	var b := _unit(Vector3.ONE)
	var foe := _unit(Vector3(9, 0, 9), 2)
	var order := RtsOrder.make(&"attack", [a, b], Vector3(1, 2, 3), foe.body, 0.5, &"wedge", true)
	var data := order.to_array()
	var back := RtsOrder.from_array(data, orders)
	check(back != null and back.command == &"attack" and back.units == [a, b], "command and units")
	check(back.point == Vector3(1, 2, 3) and back.target == foe.body and near(back.facing, 0.5), "point, target, facing")
	check(back.formation == &"wedge" and back.queue, "formation and queue")
	var bytes := var_to_bytes(data)
	check(RtsOrder.from_array(bytes_to_var(bytes), orders) != null, "survives var_to_bytes")
	var ids := {a.body: "A", b.body: "B"}
	var named := order.to_array(func(node: Node) -> String: return ids.get(node, ""))
	check(named[2] == PackedStringArray(["A", "B"]), "a game's ids")
	var by_id := {"A": a.body, "B": b.body}
	var resolved := RtsOrder.from_array(named, null, func(id: String) -> Node: return by_id.get(id))
	check(resolved != null and resolved.units == [a, b] and resolved.target == null, "resolved by the game's ids")


func test_malformed_data_is_refused() -> void:
	_setup()
	var good := RtsOrder.make(&"move", [], Vector3.ZERO).to_array()
	check(RtsOrder.from_array(good, orders) != null, "the good one")
	check(RtsOrder.from_array("move", orders) == null, "not an array")
	check(RtsOrder.from_array([], orders) == null, "empty")
	var wrong_format := good.duplicate()
	wrong_format[0] = 99
	check(RtsOrder.from_array(wrong_format, orders) == null, "another layout version")
	var wrong_type := good.duplicate()
	wrong_type[3] = "here"
	check(RtsOrder.from_array(wrong_type, orders) == null, "a point that is not a Vector3")
	var nan := good.duplicate()
	nan[3] = Vector3(NAN, 0, 0)
	check(RtsOrder.from_array(nan, orders) == null, "a NaN point")
	var crowd := good.duplicate()
	var ids := PackedStringArray()
	ids.resize(RtsOrder.MAX_UNITS + 1)
	crowd[2] = ids
	check(RtsOrder.from_array(crowd, orders) == null, "too many units")
	var stranger := good.duplicate()
	stranger[2] = PackedStringArray(["/root/nothing/here"])
	var parsed := RtsOrder.from_array(stranger, orders)
	check(parsed != null and parsed.units.is_empty(), "an unknown path is left out")


func test_request_goes_through_send() -> void:
	_setup()
	var a := _unit(Vector3.ZERO)
	var requested: Array = []
	orders.requested.connect(func(order: RtsOrder) -> void: requested.append(order))
	orders.request(RtsOrder.make(&"move", [a], Vector3(3, 0, 3)))
	check(got.has(a) and requested.size() == 1, "by default request applies with local_slot")
	got.clear()
	var sent: Array = []
	orders.send = func(order: RtsOrder) -> void: sent.append(order.to_array())
	orders.request(RtsOrder.make(&"move", [a], Vector3(4, 0, 4)))
	check(sent.size() == 1 and got.is_empty() and requested.size() == 2, "a game's send gets it instead (a network client)")
	check(orders.apply(RtsOrder.from_array(sent[0], orders), 1) and got.has(a), "and the server applies the data with the sender's slot")
	check(requested.size() == 2, "apply never emits requested")


func test_rows_never_cross() -> void:
	_setup()
	var units: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 24:
		units.append(_unit(Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 0))))
	orders.apply(RtsOrder.make(&"move", units, Vector3(0, 0, 30), null, 0.0), 1)
	check(orders.last_rows == 2, "two rows of twelve")
	var ahead := RtsSpace.ahead(0.0)
	var right := RtsSpace.right(0.0)
	var front_min := INF
	var back_max := -INF
	var front: Array = []
	for unit in units:
		var order := got[unit] as RtsUnitOrder
		var forward := ahead.dot((unit as RtsUnit).position())
		if near(order.slot.y, 0.0):
			front_min = minf(front_min, forward)
			front.append(unit)
		else:
			back_max = maxf(back_max, forward)
	check(front.size() == 12 and front_min >= back_max, "the twelve furthest ahead took the front row")
	front.sort_custom(func(p: RtsUnit, q: RtsUnit) -> bool: return right.dot(p.position()) < right.dot(q.position()))
	var ordered := true
	for k in front.size() - 1:
		ordered = ordered and (got[front[k]] as RtsUnitOrder).slot.x <= (got[front[k + 1]] as RtsUnitOrder).slot.x
	check(ordered, "left to right inside the row")


func test_greedy_match_gives_each_unit_its_own_slot() -> void:
	_setup()
	var units: Array[RtsUnit] = []
	for i in 6:
		units.append(_unit(Vector3(i * 3, 0, 0)))
	var spots: Array[Vector3] = []
	for i in 6:
		spots.append(Vector3((5 - i) * 3, 0, 1))
	var matched := RtsOrders.match_greedy(units, spots)
	var used := {}
	var nearest := true
	for u in 6:
		used[matched[u]] = true
		nearest = nearest and near(spots[matched[u]].x, units[u].position().x)
	check(used.size() == 6, "six distinct slots")
	check(nearest, "each takes the slot right in front of it")
	check(RtsOrders.match_greedy(units, [Vector3.ZERO]).count(-1) == 5, "more units than slots: the rest get -1")


func test_2d_units_get_the_same_orders() -> void:
	_setup()
	var a := _unit(Vector3(-5, 0, 0), 1, 1.0, true)
	var b := _unit(Vector3(5, 0, 0), 1, 1.0, true)
	orders.apply(RtsOrder.make(&"move", [a, b], Vector3(0, 0, -100), null, PI), 1)
	var s := 1.25 + 0.85
	# Facing PI: forward is -Z (up the screen in 2D), right is +X.
	check(near((got[a] as RtsUnitOrder).spot_2d(), Vector2(-s * 0.5, -100), 0.01), "the left 2D unit stands left: %s" % (got[a] as RtsUnitOrder).spot_2d())
	check(near((got[b] as RtsUnitOrder).spot_2d(), Vector2(s * 0.5, -100), 0.01), "the right one right")
