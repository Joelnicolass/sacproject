class_name BeamPool
extends Node

## The bolts (BeamFx), one small pool per BeamType: a play reuses an idle bolt, and when all of a
## type (its `pool_max`) are playing the oldest starts over. The client builds them all when it
## loads (scenes/fx/effects/beams and its folders). A type without `scene` has no bolt, only the
## flash of its `light` at the end. Never in a headless process.
## What it does not do: pick the effect or the place (FxBus), talk to the network, or sound.

## How long the warm-up's bolts are (`flash_all`): short enough to stay inside the camera's view.
@export_range(0.5, 20.0, 0.5, "suffix:m") var warm_span_m: float = 2.0

## type -> Array[BeamFx] idle (hidden) / playing (oldest first).
var _idle: Dictionary[BeamType, Array] = {}
var _playing: Dictionary[BeamType, Array] = {}


## Plays `type` from `from` to `to`; with `follow` the end keeps its offset from that node while it
## lives.
func play(
	type: BeamType, from: Vector3, to: Vector3, beam_seed: int, follow: Node3D = null
) -> void:
	if type.scene == null:
		if type.light != null:
			type.light.light_up(get_tree(), null, to)
		return
	var beam := _take(type)
	if beam != null:
		beam.play(from, to, beam_seed, follow)


## Builds every bolt of FxWire.warm_dirs() up to `pool_max`.
func prewarm_all() -> void:
	for found: Resource in FxWire.all_effects():
		var type := found as BeamType
		if type != null and type.scene != null:
			_open(type)
			for i in type.pool_max:
				var beam := _build(type)
				if beam == null:
					break
				_idle[type].push_back(beam)


## Warm-up (WarmHook in fx_bus.tscn): one bolt of every type, from `stage` along its X for
## `warm_span_m`, for one drawn frame, then stopped. FxBus says nothing (no `played`: no sound, no
## shake) and the bolt never reaches its end (no strike, no scar).
func flash_all(stage: Node3D) -> void:
	var from := stage.global_position
	var to := from + stage.global_basis.x * warm_span_m
	var shown: Array[BeamFx] = []
	for found: Resource in FxWire.all_effects():
		var type := found as BeamType
		var beam := _take(type) if type != null and type.scene != null else null
		if beam != null:
			beam.play(from, to, 0)
			shown.append(beam)
	await RenderingServer.frame_post_draw
	for beam in shown:
		beam.stop()


func _take(type: BeamType) -> BeamFx:
	_open(type)
	var idle: Array = _idle[type]
	var playing: Array = _playing[type]
	var beam: BeamFx = null
	if not idle.is_empty():
		beam = idle.pop_back()
	elif playing.size() < type.pool_max:
		beam = _build(type)
		if beam == null:
			return null
	else:
		beam = playing.pop_front()
	playing.push_back(beam)
	return beam


func _open(type: BeamType) -> void:
	if not _playing.has(type):
		_idle[type] = []
		_playing[type] = []


func _build(type: BeamType) -> BeamFx:
	var beam := type.scene.instantiate() as BeamFx
	if beam == null:
		return null
	beam.type = type
	beam.pooled = true
	beam.name = (
		"beam_%s_%d"
		% [FxWire.label_of(type), (_playing[type] as Array).size() + (_idle[type] as Array).size()]
	)
	add_child(beam)
	beam.finished.connect(_release.bind(type, beam))
	return beam


func _release(type: BeamType, beam: BeamFx) -> void:
	var playing: Array = _playing.get(type, [])
	var at := playing.find(beam)
	if at < 0:
		return
	playing.remove_at(at)
	(_idle[type] as Array).push_back(beam)
