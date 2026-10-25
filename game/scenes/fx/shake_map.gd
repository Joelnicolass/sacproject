@tool
class_name ShakeMap
extends Resource

## RFC-053 053f (F375): which FX of FxBus shake the camera, and how much (data/fx/shake_map.tres). CameraShake listens to
## FxBus.played on every peer and adds `trauma_of(kind, name, distance)`; presentation only, no RPC.
## - Keys of `trauma_by_fx`: the FX name as FxBus gets it (a ParticleType such as `wrath_explosion1`), or a broadcast scene by
##   its file name without extension (`quake_ring`), as `key_of` names them.
## - Full trauma within `full_within_m`, falling linearly to 0 at `max_distance_m` (horizontal distance from the camera);
##   nothing beyond. Only the kinds in `felt_kinds` count (a trail's puffs never shake).
## The product's map: `wrath_explosion1` (the explosion of Wrath, Fireball and Swarm), `wrath_explosion2` (those again, and the
## altar's burst when it falls, AltarCollapse.burst_fx) and `quake_ring` (Quake).

@export var trauma_by_fx: Dictionary[StringName, float] = {}
@export var full_within_m := 8.0
@export var max_distance_m := 40.0
@export var felt_kinds: Array[StringName] = [&"burst", &"scene"]


## Trauma an FX of `kind` named `fx_name` adds at `distance_m` (0 when it is not in the map or too far).
func trauma_of(kind: StringName, fx_name: String, distance_m: float) -> float:
	if not felt_kinds.has(kind) or distance_m >= max_distance_m:
		return 0.0
	var base := float(trauma_by_fx.get(StringName(key_of(kind, fx_name)), 0.0))
	if base <= 0.0:
		return 0.0
	if distance_m <= full_within_m:
		return base
	return base * (max_distance_m - distance_m) / maxf(max_distance_m - full_within_m, 0.001)


## The key an FX goes by: a scene by its file name (no folder, no extension), the rest by its name.
static func key_of(kind: StringName, fx_name: String) -> String:
	return fx_name.get_file().get_basename() if kind == &"scene" else fx_name
