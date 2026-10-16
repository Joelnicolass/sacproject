extends Node3D

## RFC-029 029c (REVIEW-F97 B1): the effect-light pool must never let a far, weak light take the place
## of a near, strong one, also while that one is still rising (attack). Runs headless too: FxLightLayer
## itself does not need a window. Prints `fx_robo <case> ok|FALLA ...` and `fx_robo total ok|FALLA`.
## Cases, all in one frame unless said: A 8 near bursts then 1 far spark; B 8 sparks then 6 near bursts;
## C 8 near bursts, one frame, then 1 far spark; D 12 interleaved (6 bursts 5–30 m, 6 sparks 2–40 m).
## Pass `-- --quit` to quit with a window (headless always quits).

@export var strong: FxLightSpec
@export var weak: FxLightSpec
@export var quality: LookQuality

@onready var _layer: FxLightLayer = %FxLight

var _sources: Array[RefCounted] = []
var _failed := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_layer.apply_look(LookProfile.new(), null)
	_layer.apply_quality(quality)
	var cap := _layer.max_lights()

	for i in 8:
		_flash(strong, 5.0, i)
	_flash(weak, 50.0, 0)
	_check("A", _count(strong) == cap)

	_reset()
	for i in 8:
		_flash(weak, 3.0, i)
	for i in 6:
		_flash(strong, 5.0, i)
	_check("B", _count(strong) == 6 and _count(weak) == cap - 6)

	_reset()
	for i in 8:
		_flash(strong, 5.0, i)
	await get_tree().process_frame
	_flash(weak, 50.0, 0)
	_check("C", _count(strong) == cap)

	_reset()
	for i in 6:
		_flash(weak, 2.0 + 7.6 * i, i)
		_flash(strong, 5.0 + 5.0 * i, i)
	_check("D", _count(strong) == 6)

	_reset()
	print("fx_robo total %s" % ("FALLA" if _failed else "ok"))
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--quit"):
		get_tree().quit(1 if _failed else 0)


## A light of `spec` `distance` meters in front of the camera, from a new source (a new burst).
func _flash(spec: FxLightSpec, distance: float, lane: int) -> void:
	var source := RefCounted.new()
	_sources.append(source)
	_layer.flash(source, spec, Vector3(float(lane) - 3.5, 0.0, -distance))


func _count(spec: FxLightSpec) -> int:
	return _layer.lit_specs().count(spec)


func _check(tag: String, ok: bool) -> void:
	_failed = _failed or not ok
	print("fx_robo %s %s fuertes %d debiles %d activas %d tope %d" % [
		tag, "ok" if ok else "FALLA", _count(strong), _count(weak), _layer.active_count(), _layer.max_lights()])


func _reset() -> void:
	_layer.hide()
	_layer.show()
	_sources.clear()
