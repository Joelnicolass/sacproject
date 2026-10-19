extends RefCounted

## RFC-036 036h (F209) cases of rules_suite, run by NavCases on its terrain and NavService: `edge_pushed_stays` (a body driven
## toward a hole or cliff edge by a velocity, as a crowd's avoidance does, is cut by EdgeClamp and stays on the land; the same
## drive without the clamp goes over: the control) and `edge_thrown_falls` (a unit thrown over the edge by a Tumbling falls and
## dies, has_fallen). The edge is found on the real map: land that is free on the navmesh with a hole `HOLE_M` wide ahead.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")
const SCAN_FROM := 300.0
const SCAN_TO := 2000.0
const SCAN_STEP := 8.0
## The hole ahead must be at least this wide (m) and the start this far from its lip.
const HOLE_M := 10
const LIP_M := 2
const DRIVE_SPEED := 6.0
const DRIVE_TICKS := 180
const THROW_SPEED := 8.0
const THROW_UP := 3.0
const FALL_TICKS := 900

var _terrain: Node
var _nav: NavService


func run(host: Node3D, terrain: Node, nav: NavService) -> Dictionary:
	_terrain = terrain
	_nav = nav
	var edge := _find_edge()
	if edge.is_empty():
		return {"edge_pushed_stays": {"ok": false, "reason": "no hole edge found"}, "edge_thrown_falls": {"ok": false, "reason": "no hole edge found"}}
	var start: Vector3 = edge["start"]
	var dir: Vector3 = edge["dir"]
	var out := {}
	out["edge_pushed_stays"] = await _pushed(host, start, dir)
	out["edge_thrown_falls"] = await _thrown(host, start, dir)
	return out


## A free land spot `LIP_M` from a hole of at least `HOLE_M`, and the direction (axis) toward it.
func _find_edge() -> Dictionary:
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var x := SCAN_FROM
	while x < SCAN_TO:
		var z := SCAN_FROM
		while z < SCAN_TO:
			if _terrain.call("is_on_ground", x, z):
				for dir in dirs:
					var lip := _lip_distance(x, z, dir)
					if lip < 0:
						continue
					var start := Vector3(x, 0.0, z) + dir * float(lip - LIP_M)
					var ground := float(_terrain.call("ground_height", start.x, start.z))
					if is_nan(ground):
						continue
					start.y = ground
					if _nav.is_free_at(start) and _nav.is_free_at(start - dir * 2.0):
						return {"start": start, "dir": dir}
			z += SCAN_STEP
		x += SCAN_STEP
	return {}


## Meters from (x, z) along `dir` to the first spot without ground, when the hole is HOLE_M wide and the ground runs unbroken until it; -1 otherwise.
func _lip_distance(x: float, z: float, dir: Vector3) -> int:
	for meters in range(1, int(SCAN_STEP) + 1):
		var at := Vector3(x, 0.0, z) + dir * float(meters)
		if not _terrain.call("is_on_ground", at.x, at.z):
			if meters <= LIP_M + 1:
				return -1
			for beyond in range(1, HOLE_M + 1):
				var past := at + dir * float(beyond)
				if _terrain.call("is_on_ground", past.x, past.z):
					return -1
			return meters
	return -1


## A capsule body driven toward the hole at DRIVE_SPEED for DRIVE_TICKS: with EdgeClamp it stays on the land; without it, it goes over.
func _pushed(host: Node3D, start: Vector3, dir: Vector3) -> Dictionary:
	var held := await _drive(host, start, dir, true)
	var free := await _drive(host, start, dir, false)
	var checks := {
		"stays_on_land": bool(_terrain.call("is_on_ground", held.x, held.z)),
		"does_not_sink": held.y > start.y - 2.0,
		"moved_toward_edge": (held - start).dot(dir) > 0.5,
		"control_goes_over": not bool(_terrain.call("is_on_ground", free.x, free.z)),
	}
	return _verdict(checks, {"start": start, "dir": dir, "held": held, "control": free})


func _drive(host: Node3D, start: Vector3, dir: Vector3, clamp: bool) -> Vector3:
	var body := CharacterBody3D.new()
	body.name = "EdgeDriven"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.position = start + Vector3(0.0, 0.95, 0.0)
	host.add_child(body)
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var delta := host.get_physics_process_delta_time()
	for _tick in DRIVE_TICKS:
		await host.get_tree().physics_frame
		body.velocity.y -= gravity * delta
		body.velocity.x = dir.x * DRIVE_SPEED
		body.velocity.z = dir.z * DRIVE_SPEED
		if clamp:
			body.velocity = EdgeClamp.clamp_velocity(body, body.velocity, delta)
		body.move_and_slide()
	var end := body.global_position
	body.free()
	return end


## A creature thrown over the lip by its Tumbling: it flies, falls below the land and bursts (has_fallen).
func _thrown(host: Node3D, start: Vector3, dir: Vector3) -> Dictionary:
	var type := GameData.creature("ycro")
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = "EdgeThrown"
	unit.position = start
	unit.set("owner_slot", 1)
	unit.set("creature_tag", "ycro")
	unit.set("model", str(type.model))
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	host.add_child(unit)
	for _tick in 5:
		await host.get_tree().physics_frame
	var tumbling := BodyNudge.tumbling_of(unit)
	var thrown := tumbling != null and tumbling.catapult(dir * THROW_SPEED + Vector3(0.0, THROW_UP, 0.0), 2)
	var ticks := 0
	while is_instance_valid(unit) and ticks < FALL_TICKS:
		await host.get_tree().physics_frame
		ticks += 1
	var gone := not is_instance_valid(unit)
	if not gone:
		unit.free()
	return _verdict({"was_thrown": thrown, "fell_and_died": gone}, {"ticks": ticks})


static func _verdict(checks: Dictionary, details: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	var out := details.duplicate()
	out["ok"] = ok
	out["checks"] = checks
	return out
