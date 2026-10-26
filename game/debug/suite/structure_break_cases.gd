extends RefCounted

## RFC-056 (F391) cases of rules_suite: what a building does when it falls, headless and solo. A Manalith on a fount falls in the
## same tick it reaches 0 (fount free, out of its groups, no mana, no target, one burst) and leaves the tree `linger_s` later; a
## hut bursts once, hides its parts and shows its ruin as a normal child; an indestructible one never bursts; one that falls before
## `arm_after_s` (a late join) shows the ruin and no burst; a probe child with only `building` and two connects hears `damaged`
## on every hit and `destroyed` once. Prints `structure_break_cases: falla <case>.<check>` for each failed check.

const TOWER_SCENE := preload("res://scenes/structures/buildings/_jman.tscn")
const HUT_SCENE := preload("res://scenes/structures/buildings/james_hut.tscn")
const STONE_SCENE := preload("res://scenes/structures/buildings/charnel_cabe.tscn")
const FOUNT_SCENE := preload("res://scenes/map/props/manafount.tscn")
const LINGER_TOLERANCE_TICKS := 1


## The extension pattern of the README: a child with only `building` that listens.
class Probe:
	extends Node

	var building: MapBuilding
	var hurts: Array[float] = []
	var falls := 0

	func _ready() -> void:
		building.damaged.connect(func(fraction_left: float) -> void: hurts.append(fraction_left))
		building.destroyed.connect(func(_building: MapBuilding) -> void: falls += 1)


var _host: Node
var _root: Node3D


func run(host: Node) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "StructureBreakCases"
	_host.add_child(_root)
	var out := {}
	out["structure_break_tower"] = await _tower()
	out["structure_break_hut"] = await _hut()
	out["structure_break_indestructible"] = await _indestructible()
	out["structure_break_late_join"] = await _late_join()
	_root.queue_free()
	return out


## Criteria 1, 2 and 8 on a Manalith of slot 2 over a fount: two hits of half its health.
func _tower() -> Dictionary:
	var checks := {}
	var fount := FOUNT_SCENE.instantiate() as ManafountBody
	_root.add_child(fount)
	var tower := TOWER_SCENE.instantiate() as CastTower
	tower.owner_slot = 2
	tower.fount = fount
	var parts := _place(tower, Vector3.ZERO, 0.0)
	await _frames(2)
	var breaker := parts[0] as StructureBreak
	var probe := parts[1] as Probe
	var bursts: Array[Vector3] = []
	breaker.broke.connect(func(at: Vector3) -> void: bursts.append(at))
	checks["taken_while_standing"] = not fount.is_free() and tower.is_targetable()
	var half := tower.health.maximum * 0.5
	tower.health.damage(half, 1)
	checks["first_hit_no_fall"] = not tower.is_destroyed() and bursts.is_empty()
	tower.health.damage(half, 1)
	var fell_at := MatchClock.now()
	checks["destroyed"] = tower.is_destroyed()
	checks["one_burst"] = bursts.size() == 1
	checks["fount_free_same_tick"] = fount.is_free()
	checks["out_of_tower_group"] = not tower.is_in_group(CastTower.TOWER_GROUP)
	checks["out_of_structure_group"] = not tower.is_in_group(&"structure")
	checks["no_mana"] = tower.mana_source.process_mode == Node.PROCESS_MODE_DISABLED
	checks["no_target"] = not tower.is_targetable()
	checks["probe_hurts"] = probe.hurts.size() == 2 and is_equal_approx(probe.hurts[0], 0.5) and is_equal_approx(probe.hurts[1], 0.0)
	checks["probe_one_fall"] = probe.falls == 1
	var expected := MatchClock.ticks_for(tower.linger_s)
	var left := -1
	for _i in 180:
		await _host.get_tree().physics_frame
		if not is_instance_valid(tower) or tower.is_queued_for_deletion():
			left = MatchClock.now() - fell_at
			break
	checks["linger_ticks"] = left
	checks["leaves_after_linger"] = left >= 0 and absi(left - expected) <= LINGER_TOLERANCE_TICKS + 1
	fount.queue_free()
	return _verdict("structure_break_tower", checks)


## Criteria 1, 3 and 8 on a hut (5000, with a ruin).
func _hut() -> Dictionary:
	var checks := {}
	var hut := HUT_SCENE.instantiate() as MapBuilding
	var parts := _place(hut, Vector3(200.0, 0.0, 0.0), 0.0)
	await _frames(2)
	var breaker := parts[0] as StructureBreak
	var probe := parts[1] as Probe
	var bursts := [0]
	breaker.broke.connect(func(_at: Vector3) -> void: bursts[0] += 1)
	hut.health.damage(hut.health.maximum * 0.5, 1)
	hut.health.damage(hut.health.maximum * 0.5, 1)
	await _frames(1)
	var ruin := _ruin_of(hut)
	checks["destroyed"] = hut.is_destroyed()
	checks["one_burst"] = bursts[0] == 1
	checks["parts_hidden"] = not hut.visuals.visible
	checks["ruin_shown"] = ruin != null and ruin.ruin != null and (ruin.ruin as Node3D).visible
	checks["ruin_not_internal"] = ruin != null and ruin.ruin != null and ruin.get_children(false).has(ruin.ruin)
	checks["no_collision"] = hut.collision_layer == 0 and hut.collision.disabled
	checks["probe_hurts"] = probe.hurts.size() == 2 and probe.hurts.back() == 0.0
	checks["probe_one_fall"] = probe.falls == 1
	hut.health.damage(100.0, 1)
	checks["no_second_fall"] = probe.falls == 1 and bursts[0] == 1 and probe.hurts.size() == 2
	hut.queue_free()
	return _verdict("structure_break_hut", checks)


## Criterion 1: a building with no health never bursts, whatever hits it.
func _indestructible() -> Dictionary:
	var checks := {}
	var stone := STONE_SCENE.instantiate() as MapBuilding
	var parts := _place(stone, Vector3(400.0, 0.0, 0.0), 0.0)
	await _frames(2)
	var bursts := [0]
	(parts[0] as StructureBreak).broke.connect(func(_at: Vector3) -> void: bursts[0] += 1)
	stone.health.damage(10000.0, 1)
	stone.health.kill(1)
	checks["indestructible"] = stone.is_indestructible()
	checks["standing"] = not stone.is_destroyed()
	checks["no_burst"] = bursts[0] == 0
	checks["probe_silent"] = (parts[1] as Probe).falls == 0
	stone.queue_free()
	return _verdict("structure_break_indestructible", checks)


## Criterion 6 (proxy): a hut that falls before `arm_after_s` (2 s, the default) shows its ruin and does not burst.
func _late_join() -> Dictionary:
	var checks := {}
	var hut := HUT_SCENE.instantiate() as MapBuilding
	var parts := _place(hut, Vector3(600.0, 0.0, 0.0), -1.0)
	await _frames(2)
	var breaker := parts[0] as StructureBreak
	var bursts := [0]
	breaker.broke.connect(func(_at: Vector3) -> void: bursts[0] += 1)
	checks["not_armed"] = not breaker.is_armed()
	hut.health.current = 0.0
	var ruin := _ruin_of(hut)
	checks["destroyed"] = hut.is_destroyed()
	checks["no_burst"] = bursts[0] == 0
	checks["ruin_shown"] = ruin != null and ruin.ruin != null
	hut.queue_free()
	return _verdict("structure_break_late_join", checks)


## Adds `building` at `at` with a Probe child; `arm_s` >= 0 replaces the StructureBreak's arm_after_s. [StructureBreak, Probe].
func _place(building: MapBuilding, at: Vector3, arm_s: float) -> Array:
	var breaker: StructureBreak = null
	for child in building.get_children():
		if child is StructureBreak:
			breaker = child as StructureBreak
	if breaker != null and arm_s >= 0.0:
		breaker.arm_after_s = arm_s
	var probe := Probe.new()
	probe.name = "Probe"
	probe.building = building
	building.add_child(probe)
	building.position = at
	_root.add_child(building)
	return [breaker, probe]


func _ruin_of(building: MapBuilding) -> BuildingRuin:
	for child in building.get_children():
		if child is BuildingRuin:
			return child as BuildingRuin
	return null


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("structure_break_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
