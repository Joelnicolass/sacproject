extends Node

## Counts the bodies that fell off the ground while a bench match runs, on any map. Every half second it asks
## FallCheck.has_fallen (the product's own rule: over no land and 25 m under the lowest land) of every unit and wizard, and after
## `run_s` of match time (physics ticks, so it follows --fixed-fps) prints FALL WATCH PASS when none did and some bodies were
## seen, FAIL otherwise, and quits. A wall clock limit quits it too. It changes no game state.
## Run: a child of a bench scene, for example with debug/rules/ai_duel_quiet.tres (two AIs, no NPCs) and `-- --map=<tag>`.

const TICKS_PER_SECOND := 60
const CHECK_EVERY_TICKS := 30
const WALL_LIMIT_S := 1500.0

## Seconds of match time to watch.
@export_range(1.0, 3600.0, 1.0, "suffix:s") var run_s := 180.0

var _ticks := 0
var _fallen := {}
var _seen := {}


func _ready() -> void:
	get_tree().create_timer(WALL_LIMIT_S).timeout.connect(_finish.bind(2))


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _ticks % CHECK_EVERY_TICKS == 0:
		for group in ["unit", "wizard"]:
			for body: Node in get_tree().get_nodes_in_group(group):
				_look_at(body)
	if _ticks >= int(run_s * TICKS_PER_SECOND):
		_finish(0)


func _look_at(body: Node) -> void:
	var body_3d := body as Node3D
	if body_3d == null:
		return
	_seen[body.get_instance_id()] = true
	if FallCheck.has_fallen(body_3d):
		_fallen[body.get_instance_id()] = true


func _finish(code: int) -> void:
	set_physics_process(false)
	var ok := code == 0 and _fallen.is_empty() and not _seen.is_empty()
	print("FALL WATCH %s: %d bodies fell, %d bodies seen in %d ticks" % ["PASS" if ok else "FAIL", _fallen.size(), _seen.size(), _ticks])
	get_tree().quit(0 if ok else 1)
