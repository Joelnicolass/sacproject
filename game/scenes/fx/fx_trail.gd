class_name FxTrail
extends Node3D

## A projectile's trail (RFC-029 029b): plays an FxBus type every `interval_s` of time where its
## parent flies, so it leaves as many puffs per second at 30 fps as at 120. Puffs owed in a long
## frame are spread along the path flown during it. Presentation only: never runs headless.

## Played once per puff.
signal puffed(at: Vector3)

## FxBus type (res://data/fx/<name>.tres).
@export var type_name := ""
## 2/60 s matches the old one puff every 2 render frames at 60 fps.
@export_range(0.005, 1.0, 0.001, "suffix:s") var interval_s := 2.0 / 60.0
## Off: no puffs and the clock waits (a Rock still rising out of the ground).
@export var emitting := true
## Puffs owed after a hitch beyond this many are dropped.
@export_range(1, 16) var max_per_frame := 4

var _clock := 0.0
var _last := Vector3.INF


## Adds a trail to `host` (also before it enters the tree). Null in a headless process.
static func attach(host: Node3D, type: String, seconds: float) -> FxTrail:
	if DisplayServer.get_name() == "headless" or type.is_empty():
		return null
	var trail := FxTrail.new()
	trail.name = "Trail"
	trail.type_name = type
	trail.interval_s = seconds
	host.add_child(trail)
	return trail


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()


func _process(delta: float) -> void:
	var here := global_position
	var host := get_parent()
	if not emitting or type_name.is_empty() or (host and host.is_queued_for_deletion()):
		_last = here
		return
	var from := here if _last == Vector3.INF else _last
	_last = here
	_clock += delta
	var owed := mini(int(_clock / interval_s), max_per_frame)
	if owed <= 0:
		return
	_clock = fmod(_clock, interval_s)
	for i in owed:
		## The last puff is here; earlier ones step back along this frame's path.
		var at := from.lerp(here, float(i + 1) / float(owed))
		FxBus.play(type_name, at)
		puffed.emit(at)
