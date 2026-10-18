extends RefCounted

## RFC-038 038a / 038b cases of rules_suite.
## formation_slots (038a): the eight FormationType .tres against the formulas of sacengine `getFormationOffsets` (state.d:417-475),
## written here again as plain vector math, and `line.tres` against a verbatim copy of the `Orders._formation` that RFC-038
## replaced (rows of 12, flank around a guarded body), for 1, 5, 12 and 17 bodies, with and without a target.
## formation_server (038b): the "formation" command stores the id on each creature of the slot and moves nobody; an unknown id
## or a foreign creature changes nothing; the next order uses the group's majority (ties: catalog order); a wedge order puts
## every unit within SLOT_M of its slot once it has walked.

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const ORDERS_SCRIPT := preload("res://scenes/world/orders.gd")
const UnitOrders := preload("res://scenes/world/units/unit_orders.gd")
const RULES := preload("res://data/match_rules.tres")
const CATALOG := preload("res://data/orders/formations.tres")

const TOL := 0.0001
const SLOT_M := 1.0
const ORIGIN := Vector3(6800.0, 0.0, 6000.0)
const ORDER_M := 20.0
const LIMIT_S := 30.0
const SETTLE_TICKS := 10
const SPACING_SAMPLE := 3.0
const TARGET_SAMPLE := 4.2


func run(host: Node3D) -> Dictionary:
	return {
		"formation_slots": slots_case(),
		"formation_server": await server_case(host),
	}


func slots_case() -> Dictionary:
	var failures: PackedStringArray = []
	if CATALOG.formations.size() != 8:
		failures.append("catalog has %d formations" % CATALOG.formations.size())
	var commands := [UnitOrders.Command.MOVE, UnitOrders.Command.GUARD, UnitOrders.Command.ATTACK]
	var checked := 0
	for formation in CATALOG.formations:
		var counts := [1, 5, 12, 17] if formation.id == &"line" else [1, 5, 12]
		for count: int in counts:
			for command: int in commands:
				for target_distance: float in [0.0, TARGET_SAMPLE]:
					var got := formation.slots(count, SPACING_SAMPLE, target_distance, command)
					var want := _expected(formation.id, count, SPACING_SAMPLE, target_distance, command)
					checked += 1
					if got.size() != want.size():
						failures.append("%s n=%d: %d slots, want %d" % [formation.id, count, got.size(), want.size()])
						continue
					for i in got.size():
						if got[i].distance_to(want[i]) > TOL:
							failures.append("%s n=%d cmd=%d td=%.1f slot %d: %s, want %s" % [formation.id, count, command, target_distance, i, got[i], want[i]])
							break
	return {"ok": failures.is_empty(), "checked": checked, "failures": failures.slice(0, 6)}


func _expected(id: StringName, n: int, u: float, td: float, command: int) -> Array[Vector2]:
	var r: Array[Vector2] = []
	var root2 := sqrt(2.0)
	var guard := command == UnitOrders.Command.GUARD
	var attack := command == UnitOrders.Command.ATTACK
	match id:
		&"line":
			return _legacy_line(n, u, td, command)
		&"flank_left":
			for i in n:
				var x := -(n * u) + u * i
				if td > 0.0 and not attack:
					x -= td - u
				r.append(Vector2(x, 0.0))
		&"flank_right":
			for i in n:
				var x := u + u * i
				if td > 0.0 and not attack:
					x += td - u
				r.append(Vector2(x, 0.0))
		&"phalanx":
			for i in n:
				var row := floori(i / 4.0)
				var in_row := mini(maxi(0, n - row * 4), 4)
				var y := -row * u
				if td > 0.0 and guard:
					y -= 6.0 + td
				r.append(Vector2(-0.5 * (in_row - 1) * u + u * (i % 4), y))
		&"semicircle":
			var radius := maxf(maxf(td, 0.5 * u), (n - 1) * u / PI)
			for i in n:
				var angle := 0.5 * PI if n == 1 else PI * i / (n - 1)
				r.append(Vector2(-cos(angle) * radius, -sin(angle) * radius))
		&"circle":
			var radius := maxf(td, n * u / (2.0 * PI))
			for i in n:
				var angle := 2.0 * PI * i / n
				r.append(Vector2(-cos(angle) * radius, -sin(angle) * radius))
		&"wedge":
			var scale := maxf(u, td / 1.5)
			var tip := 0.0 if attack else 3.0 * 0.5 * root2 * scale
			for i in n:
				var k := floori(n / 2.0)
				if i <= k:
					r.append(Vector2(-(k - i) * 0.5 * root2 * scale, tip - (k - i) * 0.5 * root2 * scale))
				else:
					r.append(Vector2((i - k) * 0.5 * root2 * scale, tip - (i - k) * 0.5 * root2 * scale))
		&"skirmish":
			var drop := 0.5 * root2 * u
			for i in n:
				var y := -drop if (i & 1) == 1 else 0.0
				if td > 0.0 and guard:
					y += td + drop
				r.append(Vector2(-0.5 * (n - 1) * u + u * i, y))
	return r


## Verbatim body of `Orders._formation` before RFC-038 (row_size 12), with spacing and target distance already worked out.
func _legacy_line(total: int, spacing: float, around: float, kind: int) -> Array[Vector2]:
	var row_size := 12
	var per_row := total if row_size <= 0 else mini(row_size, total)
	var slots: Array[Vector2] = []
	for i in total:
		var row := floori(float(i) / per_row)
		var col := i % per_row
		var n := mini(per_row, total - row * per_row)
		var x := -0.5 * (n - 1) * spacing + spacing * col
		if row == 0 and around > 0.0 and kind == UnitOrders.Command.GUARD:
			if n % 2 == 1:
				x += -around if 2 * col < n + 1 else around - spacing
			else:
				x += -(around - 0.5 * spacing) if 2 * col < n else around - 0.5 * spacing
		slots.append(Vector2(x, -row * spacing))
	return slots


func server_case(host: Node3D) -> Dictionary:
	var tree := host.get_tree()
	var root := Node3D.new()
	root.name = "FormationCases"
	host.add_child(root)
	root.add_child(_floor())
	var orders := Node.new()
	orders.name = "FormationOrders"
	orders.set_script(ORDERS_SCRIPT)
	orders.set("log_orders", false)
	root.add_child(orders)
	var checks := {}
	var units: Array[Node3D] = []
	for i in 8:
		units.append(_unit(root, 1, ORIGIN + Vector3((i % 4) * 3.0 - 4.5, 0.05, floorf(i / 4.0) * 3.0)))
	var foreign := _unit(root, 2, ORIGIN + Vector3(0.0, 0.05, -10.0))
	for _i in SETTLE_TICKS:
		await tree.physics_frame
	var before := _positions(units)
	checks["default_line"] = _all_ids(units, &"line")
	# An unknown id changes nothing; a known one is stored on the own creatures only and moves nobody.
	orders.call("apply_for", 1, units, "formation", ORIGIN, null, 0.0, &"no_such_formation")
	checks["unknown_rejected"] = _all_ids(units, &"line")
	orders.call("apply_for", 1, [foreign], "formation", ORIGIN, null, 0.0, &"circle")
	checks["foreign_untouched"] = _id(foreign) == &"line"
	orders.call("apply_for", 1, units + [foreign], "formation", ORIGIN, null, 0.0, &"wedge")
	checks["wedge_stored"] = _all_ids(units, &"wedge")
	checks["foreign_skipped"] = _id(foreign) == &"line"
	checks["nobody_moved"] = _positions(units) == before and _all_idle(units)
	# Majority: three wedge + two skirmish -> wedge; the offsets the creatures were given are the wedge slots.
	var group := units.slice(0, 5)
	orders.call("apply_for", 1, group.slice(0, 2), "formation", ORIGIN, null, 0.0, &"skirmish")
	var goal := ORIGIN + Vector3(0.0, 0.0, ORDER_M)
	orders.call("apply_for", 1, group, "move", goal, null, 0.0)
	checks["majority_wedge"] = _offsets_match(orders, group, &"wedge", UnitOrders.Command.MOVE)
	# Tie (two circle, two skirmish): the one first in the catalog.
	var tie := units.slice(4, 8)
	orders.call("apply_for", 1, tie.slice(0, 2), "formation", ORIGIN, null, 0.0, &"circle")
	orders.call("apply_for", 1, tie.slice(2, 4), "formation", ORIGIN, null, 0.0, &"skirmish")
	orders.call("apply_for", 1, tie, "move", goal + Vector3(30.0, 0.0, 0.0), null, 0.0)
	checks["tie_catalog_order"] = _offsets_match(orders, tie, &"circle", UnitOrders.Command.MOVE)
	# A full wedge order: every unit ends within SLOT_M of its slot.
	orders.call("apply_for", 1, units, "formation", ORIGIN, null, 0.0, &"wedge")
	var wedge_goal := ORIGIN + Vector3(-20.0, 0.0, 40.0)
	orders.call("apply_for", 1, units, "move", wedge_goal, null, 0.0)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var ticks := 0
	while ticks < int(LIMIT_S / dt) and not _all_idle(units):
		await tree.physics_frame
		ticks += 1
	for _i in int(2.0 / dt):
		await tree.physics_frame
	var worst := 0.0
	for unit in units:
		var anchor := Vector3(unit.get_node("Orders").call("anchor"))
		worst = maxf(worst, Vector2(unit.global_position.x - anchor.x, unit.global_position.z - anchor.z).length())
	checks["wedge_within_slot"] = worst <= SLOT_M
	checks["wedge_offsets"] = _offsets_match(orders, units, &"wedge", UnitOrders.Command.MOVE)
	root.free()
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {"ok": ok, "checks": checks, "worst_off_slot_m": snappedf(worst, 0.01), "seconds": snappedf(ticks * dt, 0.1)}


## The offsets the creatures were given are, as a set, the slots of `formation_id` for that group.
func _offsets_match(orders: Node, units: Array, formation_id: StringName, command: int) -> bool:
	var size := 0.0
	for unit in units:
		size = maxf(size, 2.0 * float(orders.call("_half_size", unit)))
	var spacing := minf(float(orders.get("spacing_per_size")) * size + float(orders.get("spacing_base")), float(orders.get("max_spacing")))
	var want := CATALOG.find(formation_id).slots(units.size(), spacing, 0.0, command)
	var got: Array[Vector2] = []
	for unit in units:
		got.append(unit.get_node("Orders").get("offset"))
	for slot in want:
		var found := -1
		for i in got.size():
			if got[i].distance_to(slot) <= TOL:
				found = i
				break
		if found < 0:
			return false
		got.remove_at(found)
	return got.is_empty()


func _id(unit: Node) -> StringName:
	return unit.get_node("Orders").get("formation_id")


func _all_ids(units: Array, id: StringName) -> bool:
	for unit in units:
		if _id(unit) != id:
			return false
	return true


func _all_idle(units: Array) -> bool:
	for unit in units:
		if int(unit.get("mode")) == UnitBody.Mode.MOVE:
			return false
	return true


func _positions(units: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for unit in units:
		result.append((unit as Node3D).global_position)
	return result


func _floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	floor_body.position = Vector3(ORIGIN.x, 0.0, ORIGIN.z)
	return floor_body


func _unit(parent: Node3D, slot: int, at: Vector3) -> Node3D:
	var type := GameData.creature("ycro")
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = "FormationUnit%d" % parent.get_child_count()
	unit.position = at
	unit.set("owner_slot", slot)
	unit.set("creature_tag", "ycro")
	unit.set("model", str(type.model))
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	parent.add_child(unit)
	return unit
