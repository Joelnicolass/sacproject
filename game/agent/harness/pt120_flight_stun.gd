extends Node

## Developer probe of F120 (RFC-030i-a, N1), headless, mounted by res://agent/fixtures/pt120_flight_stun.tscn next to an
## instance of res://debug/units/f114_flyers.tscn. Two hybrid fliers of slot 1: the Blight is ordered 150 m east and stunned
## once it flies 3 m up (then ordered again while stunned); the Seraph is stunned on the ground and then ordered 150 m
## east (a walk that would take off). Logs the Flight states seen while stunned, the height drift and the flat drift.
##   godot --headless --path game --fixed-fps 60 res://agent/fixtures/pt120_flight_stun.tscn

const _ORDERS := preload("res://scenes/units/unit_orders.gd")
const FAR_M := 150.0
const STATES := ["GROUND", "TAKEOFF", "FLYING", "LANDING"]

@export var scene: Node
var _tick := 0
var _air: Node3D
var _ground: Node3D
var _cases: Dictionary = {}
var _air_ordered := false


func _physics_process(_delta: float) -> void:
	if scene == null:
		return
	_tick += 1
	if _air == null:
		_pick()
		return
	if not _air_ordered:
		_air_ordered = true
		_give(_air)
		_begin(_ground)
		_give(_ground)
		return
	if not _cases.has(_air) and int(_air.get_node("Flight").get("state")) == 2 and _above(_air) > 3.0:
		_begin(_air)
		_give(_air)
	for unit: Node3D in _cases:
		_watch(unit)
	if _cases.size() == 2 and _cases.values().all(func(c: Dictionary) -> bool: return bool(c["done"])):
		get_tree().quit()
	if _tick > 60 * 30:
		print("PT120 tiempo agotado")
		get_tree().quit()


func _pick() -> void:
	var units := scene.find_child("Units", true, false)
	if units == null or units.get_child_count() < 10 or _tick < 30:
		return
	for unit in units.get_children():
		var body := unit as UnitBody
		if body and body.owner_slot == 1 and body.creature_tag == "kacd":
			_air = body
		elif body and body.owner_slot == 1 and body.creature_tag == "grps":
			_ground = body


func _give(unit: Node3D) -> void:
	(unit.get_node("Orders") as _ORDERS).give(_ORDERS.Command.MOVE, null, unit.position + Vector3(FAR_M, 0.0, 0.0), Vector2.ZERO, 0.0)


func _begin(unit: Node3D) -> void:
	var ok := (unit.get_node("Afflictions/Stunned") as Stunned).stun_with_cooldown(480)
	_cases[unit] = {"ok": ok, "tick": _tick, "y": unit.position.y, "xz": Vector2(unit.position.x, unit.position.z),
		"states": {}, "dy": 0.0, "dxz": 0.0, "done": false, "above": _above(unit)}
	print("PT120 aturdo %s en el tick %d: %s, vuelo %s, altura %.3f" % [unit.get("creature_tag"), _tick, ok,
		STATES[int(unit.get_node("Flight").get("state"))], _above(unit)])


func _watch(unit: Node3D) -> void:
	var c: Dictionary = _cases[unit]
	if bool(c["done"]):
		return
	var held := (unit.get_node("Afflictions") as Afflictions).holds()
	var state: String = STATES[int(unit.get_node("Flight").get("state"))]
	if held:
		(c["states"] as Dictionary)[state] = true
		c["dy"] = maxf(float(c["dy"]), absf(unit.position.y - float(c["y"])))
		c["dxz"] = maxf(float(c["dxz"]), (Vector2(unit.position.x, unit.position.z) - (c["xz"] as Vector2)).length())
		return
	c["done"] = true
	print("PT120 %s aturdido %d ticks | vuelo durante: %s | deriva altura %.4f m | deriva plana %.4f m | altura al inicio %.3f, al levantarse %.3f, vuelo al levantarse %s" % [
		unit.get("creature_tag"), _tick - int(c["tick"]), ",".join((c["states"] as Dictionary).keys()), c["dy"], c["dxz"],
		c["above"], _above(unit), state])


func _above(unit: Node3D) -> float:
	var terrain := TerrainShape.of(scene)
	return unit.position.y - terrain.height_at(unit.position.x, unit.position.z)
