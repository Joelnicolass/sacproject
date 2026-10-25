extends Node

## Developer probe of F116 (RFC-030e), headless, mounted by res://agent/fixtures/pt116_flight.tscn next to an instance of
## res://debug/units/f114_flyers.tscn. Gives every own creature the order a player's right click gives (Orders.give MOVE), first
## 150 m east, then 5 m, and logs each Flight state change, the height over the ground, the pace
## in the air and the clip role. Quits at the end.
##   godot --headless --path game --fixed-fps 60 res://agent/fixtures/pt116_flight.tscn

## 150 m east, to the X of the central fount (the bench leaves a 20 m gap in the row in front of it).
const FAR_M := 150.0
const _ORDERS := preload("res://scenes/units/unit_orders.gd")
const NEAR_M := 5.0
const MAX_PHASE_TICKS := 60 * 45

@export var scene: Node
var _units: Array[Node3D] = []
var _phase := "wait"
var _phase_tick := 0
var _tick := 0
var _last_state: Dictionary = {}
var _stats: Dictionary = {}
var _goal: Dictionary = {}
## Flat position of each unit on the last tick: the pace is the difference (the parent Units sits at the origin).
var _last_at: Dictionary = {}


func _physics_process(_delta: float) -> void:
	## AgentKit mounts every harness script under its autoload with no `scene`: only the fixture sets it.
	if scene == null:
		return
	_tick += 1
	_phase_tick += 1
	match _phase:
		"wait":
			var units := scene.find_child("Units", true, false)
			if units != null and units.get_child_count() >= 10 and _phase_tick > 30:
				for unit in units.get_children():
					if int(unit.get("owner_slot")) == 1:
						_units.append(unit as Node3D)
				_order(true)
		"far", "near":
			_watch()
			if _all_done() or _phase_tick > MAX_PHASE_TICKS:
				_summary()
				if _phase == "far":
					_order(false)
				else:
					get_tree().quit()


func _order(far: bool) -> void:
	_phase = "far" if far else "near"
	_phase_tick = 0
	_stats.clear()
	for unit in _units:
		var at := unit.position
		var point := at + Vector3(FAR_M, 0.0, 0.0) if far else at + Vector3(NEAR_M, 0.0, 0.0)
		_goal[unit] = point
		_stats[unit] = {"states": [], "max_above": 0.0, "max_air_pace": 0.0, "max_ground_pace": 0.0, "roles": {}, "done_tick": -1, "cap_air": 0.0, "cap_ground": 0.0}
		_last_state[unit] = int(unit.get_node("Flight").get("state"))
		_last_at[unit] = at
		(unit.get_node("Orders") as _ORDERS).give(_ORDERS.Command.MOVE, null, point, Vector2.ZERO, 0.0)
	print("PT116 orden %s en el tick %d" % [_phase, _tick])


func _watch() -> void:
	for unit in _units:
		var s: Dictionary = _stats[unit]
		var flight := unit.get_node("Flight")
		var state := int(flight.get("state"))
		var at := unit.position
		var above := at.y - _ground(at)
		var was: Vector3 = _last_at[unit]
		var pace := Vector2(at.x - was.x, at.z - was.z).length() * Engine.physics_ticks_per_second
		_last_at[unit] = at
		if state == 2:
			s["max_above"] = maxf(float(s["max_above"]), above)
			s["max_air_pace"] = maxf(float(s["max_air_pace"]), pace)
			s["cap_air"] = _height(unit)
		elif state == 0:
			s["max_ground_pace"] = maxf(float(s["max_ground_pace"]), pace)
			s["cap_ground"] = _height(unit)
		var role := (unit.get_node("ClipPose") as ClipPlayback).active_role()
		(s["roles"] as Dictionary)[role] = true
		if state != int(_last_state[unit]):
			var goal: Vector3 = _goal[unit]
			var gap := Vector2(goal.x - at.x, goal.z - at.z).length()
			(s["states"] as Array).append("%s@%.2fs(h=%.2f,d=%.1f)" % [["GROUND", "TAKEOFF", "FLYING", "LANDING"][state], _phase_tick / 60.0, above, gap])
			_last_state[unit] = state
		if int(s["done_tick"]) < 0 and int(unit.get("mode")) == UnitBody.Mode.IDLE and state == 0 and _phase_tick > 2:
			s["done_tick"] = _phase_tick


func _all_done() -> bool:
	for unit in _units:
		if int((_stats[unit] as Dictionary)["done_tick"]) < 0:
			return false
	return true


func _summary() -> void:
	for unit in _units:
		var s: Dictionary = _stats[unit]
		var type: CreatureType = unit.get("type")
		var goal: Vector3 = _goal[unit]
		var at := unit.position
		var miss := Vector2(goal.x - at.x, goal.z - at.z).length()
		var feet := at.y - _ground(at)
		var near := ""
		if int(s["done_tick"]) < 0:
			near = " | sin llegar, vecino " + _nearest(unit)
		print("PT116 %s %-10s run %.2f fly %.2f takeoff %.2fs land %.2fs | %s | h_max %.2f air %.2f ground %.2f | fin %.2fs falta %.2f m pies %.3f | cap tierra %.2f vuelo %.2f | clips %s" % [
			_phase, type.display_name, type.run_speed_m_s, type.fly_speed_m_s, type.clip_facts().seconds_at_30(&"takeoff"), type.clip_facts().seconds_at_30(&"land"),
			" ".join(s["states"]), s["max_above"], s["max_air_pace"], s["max_ground_pace"], int(s["done_tick"]) / 60.0, miss, feet,
			s["cap_ground"], s["cap_air"],
			",".join((s["roles"] as Dictionary).keys())] + near)


func _ground(at: Vector3) -> float:
	var terrain := GroundSurface.of(scene)
	return terrain.height_at(at.x, at.z)


## The closest other creature (flat distance between centers) and both radii, for a unit that never arrived.
func _nearest(unit: Node3D) -> String:
	var best: Node3D = null
	var best_d := INF
	for other in get_tree().get_nodes_in_group(&"unit"):
		var body := other as Node3D
		if body == unit or body == null:
			continue
		var d := Vector2(body.position.x - unit.position.x, body.position.z - unit.position.z).length()
		if d < best_d:
			best_d = d
			best = body
	if best == null:
		return "ninguno"
	return "%s a %.2f m (radios %.2f + %.2f), modo %d" % [best.name, best_d, _radius(unit), _radius(best), int(unit.get("mode"))]


func _radius(body: Node3D) -> float:
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col else null
	return capsule.radius if capsule else 0.0


## F135: the capsule height the body has now (Flight changes it while FLYING).
func _height(body: Node3D) -> float:
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col else null
	return capsule.height if capsule else 0.0
