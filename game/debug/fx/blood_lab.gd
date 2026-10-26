extends Node3D

## Laboratory of the blood: the flat test map (its real Terrain and GroundScars), a fixed camera and three bodies. Every body that
## loses health bleeds red; Stone wears data/fx/blood/none.tres only here, to show that a type with nothing shows nothing.
## Keys: `debug_hit` (K) takes `hit_fraction` of the next body, `debug_hit_heavy` (Shift+K) takes `heavy_fraction`, `debug_gib` (L)
## bursts the next creature (Gib.burst: the cloud, the spray and SprayMarks' pool).
## A hit lowers Health.current, exactly what any peer sees of a blow. Remote tab: World/<body>/BloodFx `sprays` / `marks`.
## `-- --blood-script` (with a window: the marks need GroundScars) runs BloodChecks; `-- --blood-headless` checks that nothing
## is active headless. Both print `BLOOD <check>: PASS|FAIL` and quit 0 / 1.

@export var checks: BloodChecks
## Bodies the keys hit, in turn.
@export var targets: Array[Node3D] = []
@export var status: Label
@export_range(0.0, 1.0) var hit_fraction := 0.2
@export_range(0.0, 1.0) var heavy_fraction := 0.45

var _next := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--blood-script"):
		checks.run.call_deferred()
	elif args.has("--blood-headless"):
		checks.run_headless.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if targets.is_empty():
		return
	if event.is_action_pressed(&"debug_gib", false, true):
		_gib_next()
	elif event.is_action_pressed(&"debug_hit_heavy", false, true):
		_hit_next(heavy_fraction)
	elif event.is_action_pressed(&"debug_hit", false, true):
		_hit_next(hit_fraction)


func _hit_next(fraction: float) -> void:
	var body := _take_next()
	if body != null:
		BloodChecks.hit(body, fraction)
		_show("golpe del %d %% a %s" % [roundi(fraction * 100.0), body.name])


func _gib_next() -> void:
	var body := _take_next() as UnitBody
	if body != null and Gib.burst(body):
		_show("gib de %s" % body.name)


## The next body still alive in `targets` (a gib frees one), or null.
func _take_next() -> Node3D:
	for i in targets.size():
		var index := _next % targets.size()
		_next += 1
		if is_instance_valid(targets[index]):
			return targets[index]
	return null


func _show(text: String) -> void:
	if status:
		status.text = "K: golpe 20 % · Shift+K: golpe 45 % · L: gib · último: " + text
