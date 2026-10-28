@tool
class_name DayCycle
extends Resource

## How one biome's day goes by: the curves and colors that bend its approved light over 24 hours. Embedded in the
## god's look (`data/look/<god>.tres` -> Day). At `start_hour` everything is neutral (multipliers 1, amounts 0), so the
## match starts on the approved light; the night is a cold, dim light that is never black.
## Curves run over the hour, 0..24 (a curve whose domain is 0..1 is read as hour / 24). A tint is white by day, goes to
## its dusk color by `dusk` and to its night color by `night` (two curves and six colors, not three gradients).
## It holds no state: AtmosphereRules reads it.

## Real seconds of a whole day. 0 = no cycle: the biome stays at `start_hour`.
@export_range(0.0, 7200.0, 1.0, "suffix:s") var length_s: float = 1440.0
## The hour the approved light shows; the match starts here.
@export_range(0.0, 24.0, 0.01) var start_hour: float = 10.0

@export_group("Sun and moon")
## Added to the LightLook's sun elevation. Where the sun goes under the horizon the light turns into the moon.
@export var elevation_change_deg: Curve
## Multiplies the sun's (and the moon's) energy. Keep it near 0 where the elevation crosses 0 (no pop sun -> moon).
@export var light_energy: Curve
## The sun's color at dusk and the moon's at night (multipliers).
@export var light_dusk: Color = Color(1.0, 0.78, 0.58)
## Near white: the night darkens the land, it does not paint it blue (a pale ground would read as snow).
@export var light_night: Color = Color(0.9, 0.93, 1.0)
## The moon light's compass angle, measured from the sun's azimuth, and its height.
@export_range(-180.0, 180.0, 1.0, "degrees") var moon_azimuth_offset_deg: float = 150.0
@export_range(5.0, 89.0, 1.0, "degrees") var moon_elevation_deg: float = 40.0

@export_group("Ambient and sky")
@export var ambient_energy: Curve
@export var ambient_dusk: Color = Color(1.0, 0.9, 0.82)
@export var ambient_night: Color = Color(0.92, 0.93, 0.98)
## The whole sky and the fog color at dusk and at night (multipliers).
@export var sky_dusk: Color = Color(0.9, 0.72, 0.62)
@export var sky_night: Color = Color(0.34, 0.36, 0.44)
## 0 = day, 1 = dusk colors (the low sun).
@export var dusk: Curve
## 0 = day, 1 = night: night colors, the night life and sounds.
@export var night: Curve
## How many stars show (0..1).
@export var stars: Curve
## Brightness of the moon disc in the sky (added to the sky's own).
@export var moon_intensity: Curve


## Compass angle of the moon light for a biome whose sun is at `sun_azimuth_deg`.
func moon_azimuth_deg(sun_azimuth_deg: float) -> float:
	return wrapf(sun_azimuth_deg + moon_azimuth_offset_deg, -180.0, 180.0)


## The moon light's (azimuth, elevation) in degrees for the biome's `light`.
func moon_dir_deg(light: LightLook) -> Vector2:
	return Vector2(moon_azimuth_deg(light.sun_azimuth_deg), moon_elevation_deg)


## What is wrong with this cycle (empty = nothing): the inspector warning of Atmosphere and the suite's case.
func problems(sun_elevation_deg: float) -> PackedStringArray:
	var found := PackedStringArray()
	var start := AtmosphereRules.day_sample(self, start_hour)
	if not start.is_neutral(1e-3):
		found.append("The cycle is not neutral at the start hour (%.2f)." % start_hour)
	for step in 240:
		var hour := float(step) * 0.1
		var a := sun_elevation_deg + AtmosphereRules.curve_at(elevation_change_deg, hour, 0.0)
		var b := sun_elevation_deg + AtmosphereRules.curve_at(elevation_change_deg, hour + 0.1, 0.0)
		if (
			signf(a - AtmosphereRules.MOON_BELOW_DEG) != signf(b - AtmosphereRules.MOON_BELOW_DEG)
			and AtmosphereRules.curve_at(light_energy, hour, 1.0) > 0.05
		):
			found.append(
				(
					"The light does not go out (%.2f) where the sun crosses the horizon (%.1f h)."
					% [AtmosphereRules.curve_at(light_energy, hour, 1.0), hour]
				)
			)
	return found
