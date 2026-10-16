extends RefCounted

## RFC-027 027d (F88) case of rules_suite: crowd_150. 150 creatures of three kinds (the tags and the 2 m grid of
## debug/selection_many.tscn) stand on a flat floor and get one move order to a point 80 m ahead through Orders (the
## product's formation: rows of 12, greedy slot match). Every physics tick the case reads where each one is. A body
## that is still walking (mode MOVE) and has not gone `PROGRESS_M` from where it last made progress for more than
## `STUCK_S` seconds is «trabada»: the case passes with none, with every body out of MOVE before `LIMIT_S`, and with at
## most MAX_OFF_SLOT bodies ending more than OFF_SLOT_M from their formation slot.
## It also gives the mean of BodySeparation per tick (`sep_ms`, measure on during the case).
## `run(host)` puts its floor and bodies under `host` and frees them at the end; it restores the separation stream.

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const ORDERS_SCRIPT := preload("res://scenes/world/orders.gd")
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
const SEPARATION_SEED := 27
## At the end a body more than OFF_SLOT_M from the slot it was given is «off slot»; at most MAX_OFF_SLOT of them pass.
## They are shoved after they arrived: Orders matches the slots greedily, the front of the crowd takes the back slots and
## everyone else walks through the bodies already parked, whose push-out carries them along (make_way walks back the ones
## it can, MakeWay «Return»). Measured in F88: 45 of 150 (111 without the return). The bound guards against a
## regression; the crossing itself belongs to the slot match of Orders, not to BodySeparation.
const OFF_SLOT_M := 2.0
const MAX_OFF_SLOT := 60
## Seconds the case waits after the last arrival before it measures off_slot.
const END_SETTLE_S := 5.0


func run(host: Node3D) -> Dictionary:
	return {"crowd_150": await crowd(host)}


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
	var state_was := MatchSeed.separation.state
	var seed_was := MatchSeed.separation.seed
	MatchSeed.separation.seed = SEPARATION_SEED
	var measure_was := BodySeparation.measure
	BodySeparation.measure = true
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
	var sep_total := 0.0
	BodySeparation.take_us()
	var limit := int(LIMIT_S / dt)
	while ticks < limit and walking > 0:
		await tree.physics_frame
		sep_total += float(BodySeparation.take_us()) / 1000.0
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
	# Those that made way or were pushed out walk back after the walkers are past (MakeWay.RETURN_TICKS): wait for them.
	for _i in int(END_SETTLE_S / dt):
		await tree.physics_frame
	var off_slot := 0
	var worst_off := 0.0
	for i in count:
		var off := _flat(units[i]).distance_to(slots[i])
		worst_off = maxf(worst_off, off)
		if off > OFF_SLOT_M:
			off_slot += 1
	BodySeparation.measure = measure_was
	MatchSeed.separation.seed = seed_was
	MatchSeed.separation.state = state_was
	root.free()
	var sep_ms := sep_total / maxf(1.0, float(ticks))
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
		"seconds": snappedf(ticks * dt, 0.01), "sep_ms": snappedf(sep_ms, 0.001), "stuck_at": stuck_at,
	}


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
	unit.set("creature_tag", tag)
	unit.set("model", str(type.model))
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	parent.add_child(unit)
	return unit


static func _flat(node: Node3D) -> Vector2:
	var at := node.global_position
	return Vector2(at.x, at.z)
