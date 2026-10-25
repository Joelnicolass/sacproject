extends RefCounted

## RFC-027 027d (F88) case of rules_suite: crowd_150. 150 creatures of three kinds (the tags and the 2 m grid of
## debug/orders/selection_many.tscn) stand on a flat floor and get one move order to a point 80 m ahead through Orders (the
## product's formation: rows of 12, greedy slot match). Every physics tick the case reads where each one is. A body
## that is still walking (mode MOVE) and has not gone `PROGRESS_M` from where it last made progress for more than
## `STUCK_S` seconds is «trabada»: the case passes with none, with every body out of MOVE before `LIMIT_S`, and with at
## most MAX_OFF_SLOT bodies ending more than OFF_SLOT_M from their formation slot.
## `run(host)` puts its floor and bodies under `host` and frees them at the end.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const ORDERS_SCRIPT := preload("res://scenes/orders/orders.gd")
const RULES := preload("res://data/match_rules.tres")

const TAGS: PackedStringArray = ["ycro", "oham", "palk"]
const COUNT := 150
const SPACING_M := 2.0
const ORDER_M := 80.0
## Far from the other cases (they work near the origin and around the map center).
const ORIGIN := Vector3(6000.0, 0.0, 6000.0)
const STUCK_S := 2.0
const PROGRESS_M := 0.5
const LIMIT_S := 60.0
const SETTLE_TICKS := 10
## At the end a body more than OFF_SLOT_M from the slot it was given is «off slot»; at most MAX_OFF_SLOT of them pass.
## They make way after they arrived: Orders matches the slots greedily, the front of the crowd takes the back slots and
## everyone else walks through the bodies already parked, which step aside (BodyAvoidance, idle priority) and stay where
## they ended. The bound guards against a regression; the crossing itself belongs to the slot match of Orders.
const OFF_SLOT_M := 2.0
const MAX_OFF_SLOT := 60
## Seconds the case waits after the last arrival before it measures off_slot.
const END_SETTLE_S := 5.0


## F88 round 4 (RFC-036 036f): crowd_return / crowd_return_held. RETURN_COUNT creatures get an order RETURN_M ahead (`move`,
## or `guard_area`, which holds the slot: `ordered` stays on) and settle; then a runner of the same slot is ordered straight
## through the middle of the formation and out the back. «Su lugar» is where each one stood before the runner (move) or
## its slot (guard_area). The creatures step aside for the runner (BodyAvoidance, idle priority) and stay where they end
## (no walk back, as the engine's avoidance has none). PASS: RETURN_TICKS_AFTER ticks after the runner is out of the
## formation's box (grown by RETURN_BOX_M), none is more than RETURN_OFF_M from its place and none is sunk in another (closer
## than SUNK_RATIO x the sum of both radii).
const RETURN_ORIGIN := Vector3(6400.0, 0.0, 6000.0)
const RETURN_COUNT := 36
const RETURN_M := 20.0
const RETURN_OFF_M := 3.5
const RETURN_TICKS_AFTER := 60
const RETURN_BOX_M := 1.5
## F88 round 5: the runner's goal is this far beyond the formation, and no creature may be carried more than RETURN_CARRY_M
## from its place while it crosses (it steps aside, it is not pushed along ahead of the runner).
const RETURN_BEYOND_M := 20.0
const RETURN_CARRY_M := 3.5
## Two bodies closer than this x the sum of their radii are sunk in each other.
const SUNK_RATIO := 0.5
## The widest of the three kinds, so the crossing shoves.
const RETURN_RUNNER_TAG := "oham"


func run(host: Node3D) -> Dictionary:
	var out := {"crowd_150": await crowd(host)}
	print("crowd_150 result: %s" % out["crowd_150"])
	out["crowd_return"] = await crowd_return(host, "move")
	out["crowd_return_held"] = await crowd_return(host, "guard_area")
	out["crowd_return_trogg"] = await crowd_return(host, "move", "ycro")
	out["crowd_return_grid"] = await crowd_return(host, "", "ycro")
	return out


func crowd_return(host: Node3D, command: String, runner_tag := RETURN_RUNNER_TAG) -> Dictionary:
	var tree := host.get_tree()
	var root := Node3D.new()
	root.name = "CrowdReturn"
	host.add_child(root)
	var floor_body := _floor()
	floor_body.position = Vector3(RETURN_ORIGIN.x, 0.0, RETURN_ORIGIN.z)
	root.add_child(floor_body)
	var orders := Node.new()
	orders.name = "ReturnOrders"
	orders.set_script(ORDERS_SCRIPT)
	orders.set("log_orders", false)
	root.add_child(orders)
	var units: Array[Node3D] = []
	var columns := ceili(sqrt(float(RETURN_COUNT)))
	for i in RETURN_COUNT:
		var at := RETURN_ORIGIN + Vector3((i % columns - 0.5 * (columns - 1)) * SPACING_M, 0.05, floori(float(i) / columns) * SPACING_M)
		units.append(_unit(root, TAGS[i % TAGS.size()], at))
	for _i in SETTLE_TICKS:
		await tree.physics_frame
	## command "" = no order: the crowd stands on its 2 m grid as debug/orders/selection_many.tscn spawns it (pt88b_open, part A).
	if not command.is_empty():
		orders.call("apply_for", 1, units, command, RETURN_ORIGIN + Vector3(0.0, 0.0, RETURN_M), null, 0.0)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var waited := 0
	while waited < int(LIMIT_S / dt) and units.any(func(u: Node3D) -> bool: return int(u.get("mode")) == UnitBody.Mode.MOVE):
		await tree.physics_frame
		waited += 1
	for _i in int(END_SETTLE_S / dt):
		await tree.physics_frame
	var places: Array[Vector2] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for unit in units:
		var place := _flat(unit)
		if command != "move" and not command.is_empty():
			var anchor := Vector3(unit.get_node("Orders").call("anchor"))
			place = Vector2(anchor.x, anchor.z)
		places.append(place)
		lo = Vector2(minf(lo.x, place.x), minf(lo.y, place.y))
		hi = Vector2(maxf(hi.x, place.x), maxf(hi.y, place.y))
	lo -= Vector2(RETURN_BOX_M, RETURN_BOX_M)
	hi += Vector2(RETURN_BOX_M, RETURN_BOX_M)
	## Straight down the column nearest the middle, so it goes through the bodies and not along a gap between columns.
	var lane := places[0].x
	for place in places:
		if absf(place.x - 0.5 * (lo.x + hi.x)) < absf(lane - 0.5 * (lo.x + hi.x)):
			lane = place.x
	var runner := _unit(root, runner_tag, Vector3(lane, 0.05, hi.y + 8.0))
	for _i in SETTLE_TICKS:
		await tree.physics_frame
	orders.call("apply_for", 1, [runner], "move", Vector3(runner.global_position.x, 0.0, lo.y - RETURN_BEYOND_M), null, 0.0)
	var entered := false
	var out_tick := -1
	var ticks := 0
	var worst_during := 0.0
	while ticks < int(LIMIT_S / dt):
		await tree.physics_frame
		ticks += 1
		var r := _flat(runner)
		var inside := r.x >= lo.x and r.x <= hi.x and r.y >= lo.y and r.y <= hi.y
		if inside:
			entered = true
		for i in units.size():
			worst_during = maxf(worst_during, _flat(units[i]).distance_to(places[i]))
		if entered and not inside:
			out_tick = ticks
			break
	for _i in RETURN_TICKS_AFTER:
		await tree.physics_frame
	var off := 0
	var worst := 0.0
	var offenders: PackedStringArray = []
	for i in units.size():
		var d := _flat(units[i]).distance_to(places[i])
		worst = maxf(worst, d)
		if d > RETURN_OFF_M:
			off += 1
			if offenders.size() < 6:
				offenders.append("%s %.2f m%s" % [units[i].name, d, " (ordered)" if bool(units[i].get("ordered")) else ""])
	## For the report only: how many are still off three seconds later (a slow return or one that never comes).
	for _i in 180:
		await tree.physics_frame
	var off_late := 0
	for i in units.size():
		if _flat(units[i]).distance_to(places[i]) > RETURN_OFF_M:
			off_late += 1
	var sunk := _sunk_pairs(units)
	root.free()
	var checks := {"runner_crossed": entered and out_tick > 0, "stay_near": off == 0, "not_carried": worst_during <= RETURN_CARRY_M, "none_sunk": sunk == 0}
	var result := {
		"ok": checks.values().all(func(v: bool) -> bool: return v), "checks": checks, "off": off, "worst_m": snappedf(worst, 0.01),
		"worst_during_m": snappedf(worst_during, 0.01), "sunk": sunk, "runner_out_s": snappedf(out_tick * dt, 0.01), "offenders": offenders, "off_3s_later": off_late,
	}
	print("crowd_return %s %s: %s" % [command, runner_tag, result])
	return result


func crowd(host: Node3D, count := COUNT, order_m := ORDER_M) -> Dictionary:
	var tree := host.get_tree()
	var root := Node3D.new()
	root.name = "CrowdCases"
	host.add_child(root)
	root.add_child(_floor())
	var orders := Node.new()
	orders.name = "CrowdOrders"
	orders.set_script(ORDERS_SCRIPT)
	orders.set("log_orders", false)
	root.add_child(orders)
	var units: Array[Node3D] = []
	var columns := ceili(sqrt(float(count)))
	for i in count:
		var col := i % columns
		var row := floori(float(i) / columns)
		var at := ORIGIN + Vector3((col - 0.5 * (columns - 1)) * SPACING_M, 0.05, row * SPACING_M)
		units.append(_unit(root, TAGS[i % TAGS.size()], at))
	for _i in SETTLE_TICKS:
		await tree.physics_frame
	var goal := ORIGIN + Vector3(0.0, 0.0, order_m)
	orders.call("apply_for", 1, units, "move", goal, null, 0.0)
	var slots: Array[Vector2] = []
	for unit in units:
		var anchor := Vector3(unit.get_node("Orders").call("anchor"))
		slots.append(Vector2(anchor.x, anchor.z))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var marks: Array[Vector2] = []
	var since := PackedInt32Array()
	var episode := PackedByteArray()
	for unit in units:
		marks.append(_flat(unit))
	since.resize(count)
	episode.resize(count)
	var stuck := 0
	var worst_s := 0.0
	var stuck_at: Array = []
	var ticks := 0
	var walking := count
	var limit := int(LIMIT_S / dt)
	while ticks < limit and walking > 0:
		await tree.physics_frame
		ticks += 1
		walking = 0
		for i in count:
			var unit := units[i]
			var here := _flat(unit)
			if int(unit.get("mode")) != UnitBody.Mode.MOVE:
				marks[i] = here
				since[i] = 0
				episode[i] = 0
				continue
			walking += 1
			if here.distance_to(marks[i]) >= PROGRESS_M:
				marks[i] = here
				since[i] = 0
				episode[i] = 0
				continue
			since[i] += 1
			var still_s := since[i] * dt
			worst_s = maxf(worst_s, still_s)
			if still_s > STUCK_S and episode[i] == 0:
				episode[i] = 1
				stuck += 1
				if stuck_at.size() < 8:
					var slot := Vector3(unit.get_node("Orders").call("anchor"))
					stuck_at.append("%s t=%.1fs at=(%.1f, %.1f) slot=(%.1f, %.1f)" % [
						unit.name, ticks * dt, here.x - ORIGIN.x, here.y - ORIGIN.z, slot.x - ORIGIN.x, slot.z - ORIGIN.z])
	# Those that made way settle after the walkers are past: wait for them.
	for _i in int(END_SETTLE_S / dt):
		await tree.physics_frame
	var off_slot := 0
	var worst_off := 0.0
	for i in count:
		var off := _flat(units[i]).distance_to(slots[i])
		worst_off = maxf(worst_off, off)
		if off > OFF_SLOT_M:
			off_slot += 1
	root.free()
	var checks := {
		"none_stuck": stuck == 0,
		"all_arrived": walking == 0,
		"near_slots": off_slot <= MAX_OFF_SLOT,
	}
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {
		"ok": ok, "checks": checks, "stuck": stuck, "worst_still_s": snappedf(worst_s, 0.01), "walking_at_end": walking, "off_slot": off_slot,
		"worst_off_slot_m": snappedf(worst_off, 0.01),
		"seconds": snappedf(ticks * dt, 0.01), "stuck_at": stuck_at,
	}


## Pairs of bodies closer than SUNK_RATIO x the sum of their radii (flat).
func _sunk_pairs(units: Array[Node3D]) -> int:
	var sunk := 0
	for a in units.size():
		for b in range(a + 1, units.size()):
			var limit := SUNK_RATIO * (BodyBox.half_size(units[a]) + BodyBox.half_size(units[b]))
			if _flat(units[a]).distance_to(_flat(units[b])) < limit:
				sunk += 1
	return sunk


func _floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	floor_body.position = Vector3(ORIGIN.x, 0.0, ORIGIN.z)
	return floor_body


func _unit(parent: Node3D, tag: String, at: Vector3) -> Node3D:
	var type := GameData.creature(tag)
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = "Crowd%s_%d" % [tag, parent.get_child_count()]
	unit.position = at
	unit.set("owner_slot", 1)
	unit.set("type", GameData.creature(tag))
	unit.set("model", type.model_id())
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	parent.add_child(unit)
	return unit


static func _flat(node: Node3D) -> Vector2:
	var at := node.global_position
	return Vector2(at.x, at.z)
