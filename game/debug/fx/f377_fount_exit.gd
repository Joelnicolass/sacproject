extends Node

## RFC-053 053h (F377): a structure on a manafount must not touch its emitters once the fount left the tree.
## The scene holds two pairs under `World`, both with emitters that draw headless (f377_drawing_emitter.gd):
## - case 1: `Fount` with `Manalith` beside it. Only the Manalith is freed: the fount is free again and its jet is on.
## - case 2: `ExitManalith` holds `ExitFount` as a child, so the fount exits the tree before its Manalith (as when the
##   map leaves before the structures). The whole `World` is freed, then the run quits.
## Prints `F377 <check>: PASS|FAIL` and `F377 PASS|FAIL`; quits 0 / 1. The runner also fails when the log contains
## `get_global_transform` (agent/runs/run_rfc053.sh 053h). Watchdog: `timeout_s` real seconds.

## Real seconds (not game time: --fixed-fps would stretch a game-time timer).
@export var timeout_s := 20.0
@export var world: Node3D
@export var fount: ManafountBody
@export var manalith: Node3D
@export var exit_fount: ManafountBody

var _done := false
var _failed := false


func _ready() -> void:
	_watchdog()
	_run.call_deferred()


func _watchdog() -> void:
	var limit := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _done:
		await get_tree().process_frame
		if Time.get_ticks_msec() > limit and not _done:
			_done = true
			print("F377 FAIL timeout")
			get_tree().quit(1)


func _run() -> void:
	await get_tree().process_frame
	var free_fx: SpriteEmitter = fount.get_node(^"%FreeFx")
	var column_fx: SpriteEmitter = fount.get_node(^"%ManalithFx")
	_check("probe emitter draws headless", free_fx.get_script() != load("res://scenes/fx/sprite_emitter.gd") and free_fx.type != null)
	_check("case1 occupied at start", not fount.is_free() and not free_fx.is_active() and column_fx.is_active())
	_check("case2 occupied at start", not exit_fount.is_free())
	manalith.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("case1 fount free after the Manalith", fount.is_free())
	_check("case1 free FX active", free_fx.is_active() and free_fx.emitting and not column_fx.is_active())
	print("F377 case2 freeing the world")
	world.free()
	await get_tree().process_frame
	_check("case2 world freed", not is_instance_valid(world))
	_done = true
	print("F377 ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _check(label: String, ok: bool) -> void:
	print("F377 %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed = true
