extends Node3D

## 055c2 cost of Vision with a crowd (the plan asks for 150 units): `count` Trogg and Druid bodies, half of each side, on a grid. It times
## every Vision.refresh() walking the groups and with the physics area, the side queries (VisionSides.sees from every body to every foe),
## the physics step with 150 monitoring areas, and checks both ways see the same bodies in the same order.
## Run (no window needed):  godot --headless --fixed-fps 60 res://debug/units/vision_perf.tscn
## Prints `VISION_PERF {json}`. Budget (plan 055c): refresh_per_tick_ms of either mode well under 1 ms at 150 units; if the area is not
## cheaper than the groups, leave `use_area` off (the default). Nothing here is read by the game.

const TAG := "VISION_PERF "
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const TROGG := preload("res://data/catalog/creatures/trogg.tres")
const DRUID := preload("res://data/catalog/creatures/druid.tres")

@export var count := 150
@export var columns := 15
@export var spacing_m := 20.0
@export var rounds := 20
@export var physics_frames := 60

var _eyes: Array[Vision] = []
var _bodies: Array[UnitBody] = []


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	var report := await run()
	print(TAG + JSON.stringify(report))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(report["same_answer"]) else 1)


func run() -> Dictionary:
	_spawn()
	await get_tree().physics_frame
	var report := {"units": count, "visions": _eyes.size()}
	var by_groups := _time_mode(false)
	report["groups"] = by_groups
	var groups_signature := _signature()
	report["groups"]["physics_ms"] = await _physics_ms()
	for eyes in _eyes:
		eyes.use_area = true
		eyes.watching = true
		eyes.set_physics_process(false)
	await get_tree().physics_frame
	report["area"] = _time_mode(true)
	report["area"]["physics_ms"] = await _physics_ms()
	report["same_answer"] = _signature() == groups_signature
	report["period_ticks"] = _eyes[0]._period
	report["note"] = "refresh_per_tick_ms = refresh_us_mean x visions / period_ticks / 1000"
	for body in _bodies:
		body.queue_free()
	return report


func _spawn() -> void:
	for index in count:
		var body := UNIT_SCENE.instantiate() as UnitBody
		body.name = "Unit_%03d" % index
		body.type = TROGG if index % 2 == 0 else DRUID
		body.owner_slot = 1 if index % 2 == 0 else 2
		body.idle_aggro = false
		body.position = Vector3(float(index % columns) * spacing_m, 0.0, float(floori(float(index) / float(columns))) * spacing_m)
		add_child(body)
		body.set_physics_process(false)
		body.vision.watching = false
		_bodies.append(body)
		_eyes.append(body.vision)


## Every Vision looks `rounds` times (one after the other, as the cycle would spread them), then every body asks the side about every foe.
func _time_mode(by_area: bool) -> Dictionary:
	var started := Time.get_ticks_usec()
	for _round in rounds:
		for eyes in _eyes:
			eyes.refresh()
	var refresh_us := float(Time.get_ticks_usec() - started) / float(rounds * _eyes.size())
	started = Time.get_ticks_usec()
	var asked := 0
	for _round in rounds:
		VisionSides.touch()
		for body in _bodies:
			for other in _bodies:
				if other.owner_slot != body.owner_slot:
					VisionSides.sees(body.owner_slot, other)
					asked += 1
	var sees_us := float(Time.get_ticks_usec() - started) / float(maxi(1, asked))
	var in_sight := 0
	for eyes in _eyes:
		in_sight += eyes.in_sight().size()
	return {
		"by_area": by_area,
		"refresh_us_mean": snappedf(refresh_us, 0.1),
		"refresh_per_tick_ms": snappedf(refresh_us * float(_eyes.size()) / float(_eyes[0]._period) / 1000.0, 0.001),
		"sees_query_us": snappedf(sees_us, 0.001),
		"in_sight_mean": snappedf(float(in_sight) / float(_eyes.size()), 0.1),
	}


## Mean physics time of a frame (ms) over `physics_frames` frames.
func _physics_ms() -> float:
	var total := 0.0
	for _frame in physics_frames:
		await get_tree().physics_frame
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return snappedf(total / float(physics_frames), 0.001)


## Who every body sees, in order: the same text in both modes means the same answer.
func _signature() -> String:
	var lines := PackedStringArray()
	for eyes in _eyes:
		var names := PackedStringArray()
		for node in eyes.in_sight():
			names.append(String(node.name))
		lines.append("%s:%s" % [eyes.body.name, ",".join(names)])
	return "\n".join(lines).sha256_text()
