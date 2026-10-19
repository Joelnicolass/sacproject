@tool
class_name AltarCollapse
extends Node

## The visible destruction of an altar, the same on every peer: the pillars and the top sink
## for 4 s, the base rises and shrinks for 4 s and bursts for 3 s (AltarDestruction: disappearDuration,
## floatDuration, explodeDuration, state.d:5289-5291). It only plays: when the altar is gone
## is decided by MatchState's clock on the server.

signal finished

## sacengine 4 + 4 + 3 s (state.d:5289-5291); MatchRules.altar_collapse_s is the server's clock.
@export var duration_s := 11.0
## Share of the duration spent sinking (4/11) and floating (4/11); the rest is the burst.
@export_range(0.0, 1.0) var sink_fraction := 0.3636
@export_range(0.0, 1.0) var float_fraction := 0.3636
## Meters the pillars and the top sink (they are 22 m tall).
@export var sink_depth := 26.0
## Meters the base rises while it shrinks.
@export var float_height := 60.0
## ParticleType of FxBus played where the base bursts (wrath_explosion2).
@export var burst_fx := "wrath_explosion2"
## Models that sink and the one that rises: both are children of `visuals`.
@export var visuals: Node3D
@export var ring: Node3D

var _time := 0.0
var _total := 0.0
var _bursting := false
var _rest: Dictionary = {}


func _ready() -> void:
	set_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if visuals == null:
		warnings.append("Asigná en `visuals` el nodo con los modelos del altar.")
	if ring == null:
		warnings.append("Asigná en `ring` el modelo de la base, que sube y se achica.")
	return warnings


## `total_s` 0 uses duration_s. `elapsed_s` starts it halfway.
func play(total_s := 0.0, elapsed_s := 0.0) -> void:
	if visuals == null:
		return
	_remember_rest()
	_total = total_s if total_s > 0.0 else duration_s
	_time = clampf(elapsed_s, 0.0, _total)
	_bursting = false
	set_process(true)
	_show()


## Back to the standing pose.
func reset() -> void:
	set_process(false)
	_time = 0.0
	_bursting = false
	for node: Node3D in _rest:
		if is_instance_valid(node):
			node.transform = _rest[node]
			node.visible = true


func is_playing() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	_time += delta
	_show()
	if _time >= _total:
		set_process(false)
		finished.emit()


func _remember_rest() -> void:
	if not _rest.is_empty():
		return
	for child in visuals.get_children():
		var node := child as Node3D
		if node:
			_rest[node] = node.transform


func _show() -> void:
	var sink_end := _total * sink_fraction
	var float_end := sink_end + _total * float_fraction
	var sink := clampf(_time / maxf(sink_end, 0.001), 0.0, 1.0)
	var rise := clampf((_time - sink_end) / maxf(float_end - sink_end, 0.001), 0.0, 1.0)
	for node: Node3D in _rest:
		var rest: Transform3D = _rest[node]
		if node == ring:
			var up := float_height * rise * rise
			node.transform = Transform3D(rest.basis.scaled(Vector3.ONE * (1.0 - rise)), rest.origin + Vector3.UP * up)
			node.visible = _time < float_end
		else:
			node.transform = Transform3D(rest.basis, rest.origin + Vector3.DOWN * sink_depth * sink)
			node.visible = sink < 1.0
	if _time >= float_end and not _bursting:
		_bursting = true
		_burst()


func _burst() -> void:
	if Engine.is_editor_hint() or MpKit.is_dedicated() or ring == null:
		return
	var rest: Transform3D = _rest.get(ring, ring.transform)
	var parent := ring.get_parent() as Node3D
	var at := (parent.global_transform * rest.origin) if parent else ring.global_position
	FxBus.play(burst_fx, at + Vector3.UP * float_height)
