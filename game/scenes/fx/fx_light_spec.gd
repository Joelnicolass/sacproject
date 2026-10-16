class_name FxLightSpec
extends Resource

## The light a ParticleType burst gives off (RFC-029 029c): an OmniLight3D without shadow that rises
## over `attack_s` and dies over `decay_s`. A template shared by every type that points to it: never
## edited at runtime. The rig's FxLightLayer owns the lights; without that layer nothing lights up.

## Usually the brightness-weighted mean of the type's atlas, so the light keeps the sprite's palette.
@export var color: Color = Color.WHITE
## Peak `light_energy` of the OmniLight3D.
@export_range(0.0, 32.0, 0.05) var energy: float = 2.0
## `omni_range` in meters.
@export_range(0.5, 40.0, 0.1, "suffix:m") var range_m: float = 8.0
## Seconds from 0 to the peak.
@export_range(0.0, 2.0, 0.005, "suffix:s") var attack_s: float = 0.03
## Seconds from the peak back to 0.
@export_range(0.01, 4.0, 0.005, "suffix:s") var decay_s: float = 0.4
## Shape of the fall: 1 = linear, 2 = fast at first and a long tail.
@export_range(0.25, 4.0, 0.05) var decay_power: float = 1.0
## Meters above the burst point (a burst on the ground lights it from a little above).
@export_range(-4.0, 8.0, 0.05, "suffix:m") var height_m: float = 0.5
## `omni_attenuation` (1 = the engine's default falloff).
@export_range(0.1, 4.0, 0.05) var attenuation: float = 1.0


func total_s() -> float:
	return attack_s + decay_s


## 0..1 of `energy` at `t` seconds since the burst.
func envelope(t: float) -> float:
	if t < 0.0 or t >= total_s():
		return 0.0
	if t < attack_s:
		return t / attack_s
	return pow(1.0 - (t - attack_s) / decay_s, decay_power)
