@tool
class_name FxScene
extends Node3D

## The root of an effect that is a whole scene (a ring of spikes, a shower of rocks, a piece of
## ground that falls): FxBus instances it at a place on every peer, calls `play(params)` once and
## the scene frees itself when it ends. It also carries how much the camera shakes when it plays, so
## the shake lives next to the look and not in a table by name.
## What it does not do: decide when it plays (the spell or unit that broadcasts it), touch the
## simulation, or run in a headless process.

## Per scene: the `camera_trauma` it saves (read from its SceneState, never instanced).
static var _trauma_cache: Dictionary[PackedScene, float] = {}

## How hard the camera shakes near this effect, 0 to 1 (full inside ShakeMap.full_within_m, fading
## with distance).
@export_range(0.0, 1.0, 0.01) var camera_trauma := 0.0


## FxBus calls this once, after the scene is in the tree and at its place. `params` are the numbers
## of the event.
func play(_params: Dictionary) -> void:
	pass


## The `camera_trauma` saved in the root of `scene` (0 when none). A dictionary lookup after the
## first call.
static func trauma_of(scene: PackedScene) -> float:
	if scene == null:
		return 0.0
	if not _trauma_cache.has(scene):
		var value := 0.0
		var state := scene.get_state()
		if state.get_node_count() > 0:
			for i in state.get_node_property_count(0):
				if state.get_node_property_name(0, i) == &"camera_trauma":
					value = float(state.get_node_property_value(0, i))
		_trauma_cache[scene] = value
	return _trauma_cache[scene]
