class_name PaceFactors
extends Node

## The one owner of a body's `speed_factor`. Everything that speeds a creature or a wizard up or
## slows it down (Speedup ×1.75, Sticky bombs ×0.75ⁿ, Blight mites ×0.8ⁿ…) gives its factor here
## under the name of its source; the body's speed_factor is the product of all of them, derived and
## written only when it changes. Nobody else writes speed_factor on a body that has this component
## (the Sac Doctor has none and keeps its own writer). The product walks the sources in name order,
## so it does not depend on the order they came in (idempotent: asking twice, or in another order,
## gives the same number). A factor of exactly 1 is the same as no factor. Server (or solo):
## speed_factor is simulated there; on a client the component does nothing.

## The body whose speed_factor it owns. Empty = the parent.
@export var body: Node3D

## source (StringName) -> factor (float).
var _factors: Dictionary = {}


## The PaceFactors of `node`, or null (a body without one keeps writing speed_factor by itself).
static func of(node: Node) -> PaceFactors:
	return (node.get_node_or_null("PaceFactors") as PaceFactors) if node else null


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	set_physics_process(false)


## Server (or solo). `source` pushes `factor` (replacing its previous one). 1.0 takes it away.
func set_factor(source: StringName, factor: float) -> void:
	if not is_multiplayer_authority():
		return
	if factor == 1.0:
		_factors.erase(source)
	else:
		_factors[source] = factor
	_apply()


## Server (or solo). `source` no longer changes the pace.
func clear(source: StringName) -> void:
	if not is_multiplayer_authority() or not _factors.has(source):
		return
	_factors.erase(source)
	_apply()


## The factor of one source (1 without one).
func factor_of(source: StringName) -> float:
	return float(_factors.get(source, 1.0))


## Π of all the factors, in source-name order.
func product() -> float:
	var names: Array = _factors.keys()
	names.sort()
	var result := 1.0
	for each: Variant in names:
		result *= float(_factors[each])
	return result


## The sources that are changing the pace now.
func sources() -> Array:
	var names: Array = _factors.keys()
	names.sort()
	return names


## Writes body.speed_factor = Π, only when it is not already that.
func _apply() -> void:
	if body == null or not "speed_factor" in body:
		return
	var now := product()
	if float(body.get("speed_factor")) == now:
		return
	body.set("speed_factor", now)
	if DebugLog.on(&"pace"):
		print(
			"pace %s ×%.4f %s (tick %d)" % [str(body.name), now, str(sources()), MatchClock.now()]
		)
