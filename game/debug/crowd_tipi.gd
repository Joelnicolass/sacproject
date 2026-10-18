extends Node

## F88 round 2 case (headless): the 150 creatures of debug/selection_many.tscn on High Noon get the march order of the
## pt88 playtest (80 m north, past the two tipis jwg1 Bld072 and Bld076) through Orders, the product's formation. Every
## physics tick the case reads each body. A body that still has its move order pending (UnitBody MOVE) and has not gone
## `PROGRESS_M` from where it last made progress for more than `STUCK_S` seconds is «trabada». PASS: none trabada and
## every body out of MOVE before `LIMIT_S`. It prints one line `crowd_tipi: PASS|FAIL {…}` and, with quit_when_done,
## quits. Run: Godot --headless --fixed-fps 60 --path game res://debug/crowd_tipi.tscn
## Before the fix (2026-10-16): 4 trabadas for good against the south faces of both tipis (Manahoar68, Trogg82 at Bld076;
## Manahoar104, Trogg130 at Bld072), MOVE with zero velocity until the end.
## Variant debug/crowd_rock.tscn (F88 round 3): the order of pt88b_rock, (1583, 1483), up the ridge east of the tipis, with
## the facing of a player who orders ahead (`face_goal`). It also asks that `watch_name` ends within `slot_m` of its slot and
## that no pair is sunk at the end (closer than `deep_ratio` x the sum of radii, as agent/harness/crowd_watch.gd).

const STUCK_S := 2.0
const PROGRESS_M := 0.5
const LIMIT_S := 45.0
## Gates of the navmesh backend (RFC-035 035g): every body out of MOVE by then, and 95 % of the searches under this.
const NAVMESH_ARRIVE_S := 25.0
const NAVMESH_P95_US := 300

## The group of the scene (orders_group.gd): it spawns the creatures.
@export var group: Node
## The world's Orders (orders.gd): the order goes through it, as the player's does.
@export var orders: Node
## Where the march goes: the point of the pt88 flow (aim_ahead 80), on the far side of the tipis.
@export var goal := Vector3(1522.0, 0.0, 1435.0)
@export var facing := 0.0
@export var expected := 150
@export var quit_when_done := true
## Face from the crowd's centroid to the goal (the formation looks where it goes, as a player's order ahead).
@export var face_goal := false
## Empty = no slot check.
@export var watch_name := ""
@export var slot_m := 2.0
## Pairs closer than this x (radius a + radius b) at the end are sunk; < 0 = no check.
@export var deep_ratio := -1.0
## Seconds the case waits after the last arrival before the end checks (returns of MakeWay).
@export var settle_s := 0.0

var _started := false


func _get_configuration_warnings() -> PackedStringArray:
	if group == null or orders == null:
		return PackedStringArray(["Asigná group y orders."])
	return PackedStringArray()


func _physics_process(_delta: float) -> void:
	if _started:
		return
	var own: Array = group.get("_own")
	var nav := get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if own.size() < expected or nav == null or not nav.is_ready():
		return
	_started = true
	_run.call_deferred(own.duplicate())


func _run(units: Array) -> void:
	var tree := get_tree()
	for _i in 30:
		await tree.physics_frame
	var yaw := facing
	if face_goal:
		var center := Vector3.ZERO
		for unit: Node3D in units:
			center += unit.global_position
		center /= units.size()
		yaw = atan2(goal.x - center.x, goal.z - center.z)
	orders.call("apply_for", 1, units, "move", goal, null, yaw)
	var count := units.size()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var marks: Array[Vector2] = []
	var since := PackedInt32Array()
	var episode := PackedByteArray()
	for unit: Node3D in units:
		marks.append(_flat(unit))
	since.resize(count)
	episode.resize(count)
	var stuck := 0
	var worst_s := 0.0
	var stuck_at: Array = []
	var ticks := 0
	var walking := count
	var limit := int(LIMIT_S / dt)
	var watched: Node3D = null
	for unit: Node3D in units:
		if unit.name == watch_name:
			watched = unit
	var watch_arrived_off := -1.0
	var watch_arrived_s := -1.0
	while ticks < limit and walking > 0:
		await tree.physics_frame
		ticks += 1
		walking = 0
		if watched != null and watch_arrived_s < 0.0 and int(watched.get("mode")) != UnitBody.Mode.MOVE:
			var anchor := Vector3(watched.get_node("Orders").call("anchor"))
			watch_arrived_s = ticks * dt
			watch_arrived_off = _flat(watched).distance_to(Vector2(anchor.x, anchor.z))
		for i in count:
			var unit: Node3D = units[i]
			if not is_instance_valid(unit):
				continue
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
			worst_s = maxf(worst_s, since[i] * dt)
			if since[i] * dt > STUCK_S and episode[i] == 0:
				episode[i] = 1
				stuck += 1
				if stuck_at.size() < 8:
					stuck_at.append("%s t=%.1fs at=(%.1f, %.1f)" % [unit.name, ticks * dt, here.x, here.y])
	for _i in int(settle_s / dt):
		await tree.physics_frame
	var ok := stuck == 0 and walking == 0
	var report := {"stuck": stuck, "walking_at_end": walking, "worst_still_s": snappedf(worst_s, 0.01),
			"seconds": snappedf(ticks * dt, 0.01), "stuck_at": stuck_at}
	var ordered := 0
	for unit: Node3D in units:
		if is_instance_valid(unit) and bool(unit.get("ordered")):
			ordered += 1
	report["ordered_at_end"] = ordered
	if not watch_name.is_empty():
		for unit: Node3D in units:
			if is_instance_valid(unit) and unit.name == watch_name:
				var slot := Vector3(unit.get_node("Orders").call("anchor"))
				var off := _flat(unit).distance_to(Vector2(slot.x, slot.z))
				report["watch_to_slot_m"] = snappedf(off, 0.01)
				report["watch_arrived"] = [snappedf(watch_arrived_s, 0.01), snappedf(watch_arrived_off, 0.01)]
				report["watch_at"] = [snappedf(unit.global_position.x, 0.1), snappedf(unit.global_position.z, 0.1)]
				report["watch_slot"] = [snappedf(slot.x, 0.1), snappedf(slot.z, 0.1)]
				ok = ok and off <= slot_m
	var off_slot := 0
	for unit: Node3D in units:
		var anchor := Vector3(unit.get_node("Orders").call("anchor"))
		if _flat(unit).distance_to(Vector2(anchor.x, anchor.z)) > 2.0:
			off_slot += 1
	report["off_slot_2m"] = off_slot
	if deep_ratio >= 0.0:
		var deep := _deep_pairs(units)
		report["deep_pairs"] = deep
		ok = ok and deep == 0
	## RFC-035 035g: the pathfinder's own numbers. With the navmesh backend its gates are part of the verdict (arrival, p95 of a search).
	var nav := tree.get_first_node_in_group(NavService.GROUP) as NavService
	if nav != null:
		var p95 := nav.search_percentile_us(0.95)
		report["nav"] = {"backend": nav.backend_name(), "searches": nav.searches, "total_us": nav.search_us_total, "p95_us": p95}
		if nav.backend_name() == "navmesh":
			ok = ok and ticks * dt <= NAVMESH_ARRIVE_S and p95 <= NAVMESH_P95_US
	print("%s: %s %s" % [str(get_parent().name).to_snake_case(), "PASS" if ok else "FAIL", JSON.stringify(report)])
	if quit_when_done:
		tree.quit(0 if ok else 1)


func _deep_pairs(units: Array) -> int:
	var deep := 0
	var radii := PackedFloat64Array()
	for unit: Node3D in units:
		radii.append(float(BodyLibrary.info(str(unit.get("model"))).get("radius", 0.35)))
	for i in units.size():
		for j in range(i + 1, units.size()):
			if _flat(units[i]).distance_to(_flat(units[j])) < deep_ratio * (radii[i] + radii[j]):
				deep += 1
	return deep


static func _flat(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)
