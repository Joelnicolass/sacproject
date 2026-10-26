class_name ReachFacts
extends RefCounted

## The reaches the rules need (soul pickup, mana of a fount and an altar, the Manahoar aura, arming and leashing a Guardian), read once
## from the scene `reach_places.tscn` and kept. The measures are decoded to the mm (SceneStateReader.mm), the doubles `MatchRules`
## held before they moved into the scene.
## Read from the scene's SceneState, NEVER instantiated: an instance of its Area3D would move the simulation.
## What it does not do: move anything, choose a scene (MatchRules.reach_places does) or apply a reach to a unit.

const _DEFAULT_SCENE := preload("res://scenes/match/reach_places.tscn")

static var _cache: Dictionary[PackedScene, ReachFacts] = {}

## Souls: the radius on the ground and how far up and down a wizard picks one up.
var soul_m := 5.0
var soul_up_m := 5.0
## Mana: how far a fount and an altar feed.
var fount_m := 50.0
var altar_m := 50.0
## Manahoar: the aura radius, the distance up to which it gives its peak, and the distance where it gives nothing.
var manahoar_aura_m := 40.0
var manahoar_peak_m := 50.0
var manahoar_end_m := 1000.0
## Guardian: how close to a building it can be armed, how far it strays, how close to the building it is sent back, and where on it
## the leash is measured from (relative to its feet).
var guardian_arm_m := 50.0
var guardian_leash_m := 50.0
var guardian_return_m := 20.0
var guardian_leash_from := Vector3(0.0, 0.9, 0.0)


## The facts of the reach scene `scene` (built once and shared). Null reads the default reaches. A dictionary lookup after the first call.
static func of(scene: PackedScene) -> ReachFacts:
	if scene == null:
		scene = _DEFAULT_SCENE
	if not _cache.has(scene):
		var built := ReachFacts.new()
		built._read(scene.get_state())
		_cache[scene] = built
	return _cache[scene]


## The facts of the reach scene `rules` points at.
static func of_rules(rules: MatchRules) -> ReachFacts:
	return of(rules.reach_places if rules != null else null)


func _read(state: SceneState) -> void:
	var nodes := SceneStateReader.nodes_of(state)
	var root: Dictionary = nodes.get(".", {})
	soul_m = SceneStateReader.radius(nodes, root, "soul", soul_m)
	soul_up_m = SceneStateReader.half_height(nodes, root, "soul", soul_up_m)
	fount_m = SceneStateReader.radius(nodes, root, "fount", fount_m)
	altar_m = SceneStateReader.radius(nodes, root, "altar", altar_m)
	manahoar_aura_m = SceneStateReader.radius(nodes, root, "manahoar_aura", manahoar_aura_m)
	manahoar_peak_m = SceneStateReader.radius(nodes, root, "manahoar_peak", manahoar_peak_m)
	manahoar_end_m = SceneStateReader.radius(nodes, root, "manahoar_end", manahoar_end_m)
	guardian_arm_m = SceneStateReader.radius(nodes, root, "guardian_arm", guardian_arm_m)
	guardian_leash_m = SceneStateReader.radius(nodes, root, "guardian_leash", guardian_leash_m)
	guardian_return_m = SceneStateReader.radius(nodes, root, "guardian_return", guardian_return_m)
	if root.has("guardian_leash_from"):
		## Kept as the 32-bit Vector3 the scene saves, like the 0.9 the bond always added.
		guardian_leash_from = SceneStateReader.marker(nodes, root, "guardian_leash_from")
