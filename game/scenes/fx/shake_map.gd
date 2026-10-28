@tool
class_name ShakeMap
extends Resource

## How a played effect becomes camera shake (scenes/fx/effects/shake_map.tres): the distance
## fall-off only.
## CameraShake listens to FxBus.played on every peer and adds `trauma_of(kind, fx, distance)`;
## presentation only, no RPC. How hard an effect shakes is the effect's own `camera_trauma`
## (ParticleType, BeamType, or the root of an FxScene), not a table by name.
## - Full trauma within `full_within_m`, falling linearly to 0 at `max_distance_m` (horizontal
##   distance from the camera); nothing beyond.
## - Only the kinds in `felt_kinds` count (a trail's puffs never shake).

@export var full_within_m := 8.0
@export var max_distance_m := 40.0
@export var felt_kinds: Array[StringName] = [&"burst", &"scene"]


## Trauma an effect of `kind` adds at `distance_m` (0 when it has no `camera_trauma`, is not a felt
## kind or is too far).
func trauma_of(kind: StringName, fx: Resource, distance_m: float) -> float:
	if not felt_kinds.has(kind) or distance_m >= max_distance_m:
		return 0.0
	var base := base_of(fx)
	if base <= 0.0:
		return 0.0
	if distance_m <= full_within_m:
		return base
	return base * (max_distance_m - distance_m) / maxf(max_distance_m - full_within_m, 0.001)


## The `camera_trauma` the effect carries: its own field, or the one saved in the root of a scene.
static func base_of(fx: Resource) -> float:
	if fx is ParticleType:
		return (fx as ParticleType).camera_trauma
	if fx is BeamType:
		return (fx as BeamType).camera_trauma
	return FxScene.trauma_of(fx as PackedScene) if fx is PackedScene else 0.0
