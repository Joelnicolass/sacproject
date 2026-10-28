class_name SacrificeFacts
extends RefCounted

## The distances of the sacrifice the rules need (the ring of the doctors, the push, how far a
## doctor reaches, where the creature hangs, where the vortex opens), read once from the scene
## `sacrifice_places.tscn` and kept. The measures are decoded to the mm (SceneStateReader.mm), the
## doubles `MatchRules` held before they moved into the scene. Read from the scene's SceneState,
## NEVER instantiated: an instance of its Area3D would move the simulation.
## What it does not do: move anything, choose a scene (MatchRules.sacrifice_places does) or know the
## ritual's phases.

const _DEFAULT_SCENE := preload("res://scenes/sacrifice/sacrifice_places.tscn")

static var _cache: Dictionary[PackedScene, SacrificeFacts] = {}

## Ritual: the ring of the doctors, the same ring closed in, the push and its full-speed core, the
## carrier's stop, the hang over the site.
var ring_m := 20.0
var ring_end_m := 17.0
var push_m := 20.0
var push_core_m := 5.0
var carrier_stop_m := 20.0
var hang_up_m := 15.0
## Carry: how far up and behind the doctor the body hangs, how far a doctor reaches to pick up a
## soul and to pump the captive.
var carry_up_m := 3.5
var carry_back_m := 2.7
var pickup_m := 10.0
var pump_reach_m := 2.0
## Drop: how far out and up the vortex opens from the target, and how far below it the doctor leaves
## it.
var drop_out_m := 20.0
var drop_up_m := 15.0
var exit_down_m := 2.25


## The facts of the places scene `scene` (built once and shared). Null reads the default places. A
## dictionary lookup after the first call.
static func of(scene: PackedScene) -> SacrificeFacts:
	if scene == null:
		scene = _DEFAULT_SCENE
	if not _cache.has(scene):
		var built := SacrificeFacts.new()
		built._read(scene.get_state())
		_cache[scene] = built
	return _cache[scene]


## The facts of the places scene `rules` points at.
static func of_rules(rules: MatchRules) -> SacrificeFacts:
	return of(rules.sacrifice_places if rules != null else null)


## How much the ring closes in during the last fifth of the walk.
func walk_shrink_m() -> float:
	return ring_m - ring_end_m


func _read(state: SceneState) -> void:
	var nodes := SceneStateReader.nodes_of(state)
	var root: Dictionary = nodes.get(".", {})
	ring_m = SceneStateReader.radius(nodes, root, "ring", ring_m)
	ring_end_m = SceneStateReader.radius(nodes, root, "ring_end", ring_end_m)
	push_m = SceneStateReader.radius(nodes, root, "push", push_m)
	push_core_m = SceneStateReader.radius(nodes, root, "push_core", push_core_m)
	carrier_stop_m = SceneStateReader.radius(nodes, root, "carrier_stop", carrier_stop_m)
	pickup_m = SceneStateReader.radius(nodes, root, "pickup", pickup_m)
	pump_reach_m = SceneStateReader.radius(nodes, root, "pump_reach", pump_reach_m)
	if root.has("ritual_hang"):
		hang_up_m = SceneStateReader.mm(SceneStateReader.marker(nodes, root, "ritual_hang").y)
	if root.has("carry_hang"):
		var hang := SceneStateReader.marker(nodes, root, "carry_hang")
		carry_up_m = SceneStateReader.mm(hang.y)
		carry_back_m = SceneStateReader.mm(-hang.z)
	if root.has("vortex"):
		var vortex := SceneStateReader.marker(nodes, root, "vortex")
		drop_up_m = SceneStateReader.mm(vortex.y)
		drop_out_m = SceneStateReader.mm(-vortex.z)
	if root.has("exit"):
		exit_down_m = SceneStateReader.mm(-SceneStateReader.marker(nodes, root, "exit").y)
