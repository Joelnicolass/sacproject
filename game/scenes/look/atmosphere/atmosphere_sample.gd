class_name AtmosphereSample
extends RefCounted

## The atmosphere at one moment, as numbers the look layers read: how the hour and the weather change the approved
## light, the sky and the fog. A value, never saved. `neutral()` changes nothing (the biome's approved look, exactly);
## the multipliers are 1 there and the amounts 0.
## The day and the weather each give one; `mix` joins them (commutative, with the neutral as its identity).

## Hour of the day, 0..24. -1 = no hour (the weather's sample, or no cycle).
var hour := -1.0
## 0 = day, 1 = full night (what AmbientLife and the night sounds read).
var night := 0.0
## Added to the sun's elevation of the biome's LightLook.
var elevation_change_deg := 0.0
## True while the one light is the moon (the sun is under the horizon).
var moon := false
## Multipliers of the sun (or moon) light.
var light_tint := Color.WHITE
var light_energy := 1.0
## Multipliers of the Environment's ambient light.
var ambient_tint := Color.WHITE
var ambient_energy := 1.0
## Multiplies the whole sky and the fog color (and the sky's ambient and reflections).
var sky_tint := Color.WHITE
## 0 = the sky's own colors, 1 = grey.
var sky_grey := 0.0
## Multipliers of the fog's density and of its far end.
var fog_density := 1.0
var fog_end := 1.0
## 0..1: how much it rains (drops and the sound bed).
var rain := 0.0
## 0..1: the storm flash now (058-3).
var flash := 0.0
## How many stars show (0..1) and the moon disc's brightness added to the sky's own.
var stars := 0.0
var moon_intensity := 0.0
## Extra cloud cover (0 = the sky's own clouds), how much darker they are, and how much faster they drift.
var cloud_cover := 0.0
var cloud_darken := 0.0
var cloud_speed_mul := 1.0
## The weather state this sample comes from (null in the day's sample).
var weather: Resource  # a WeatherState (058-2)


static func neutral() -> AtmosphereSample:
	return AtmosphereSample.new()


## The day and the weather together: product of the multipliers, max of the amounts, sum (capped) of the flash.
static func mix(a: AtmosphereSample, b: AtmosphereSample) -> AtmosphereSample:
	var out := AtmosphereSample.new()
	out.hour = maxf(a.hour, b.hour)
	out.night = maxf(a.night, b.night)
	out.elevation_change_deg = a.elevation_change_deg + b.elevation_change_deg
	out.moon = a.moon or b.moon
	out.light_tint = a.light_tint * b.light_tint
	out.light_energy = a.light_energy * b.light_energy
	out.ambient_tint = a.ambient_tint * b.ambient_tint
	out.ambient_energy = a.ambient_energy * b.ambient_energy
	out.sky_tint = a.sky_tint * b.sky_tint
	out.sky_grey = maxf(a.sky_grey, b.sky_grey)
	out.fog_density = a.fog_density * b.fog_density
	out.fog_end = a.fog_end * b.fog_end
	out.rain = maxf(a.rain, b.rain)
	out.flash = minf(a.flash + b.flash, 1.0)
	out.stars = maxf(a.stars, b.stars)
	out.moon_intensity = maxf(a.moon_intensity, b.moon_intensity)
	out.cloud_cover = maxf(a.cloud_cover, b.cloud_cover)
	out.cloud_darken = maxf(a.cloud_darken, b.cloud_darken)
	out.cloud_speed_mul = a.cloud_speed_mul * b.cloud_speed_mul
	out.weather = a.weather if a.weather != null else b.weather
	return out


## True when every number is within `eps` of `other`'s (and the light is the same body).
func is_close(other: AtmosphereSample, eps: float) -> bool:
	if other == null or moon != other.moon or weather != other.weather:
		return false
	var mine := numbers()
	var theirs := other.numbers()
	for i in mine.size():
		if absf(mine[i] - theirs[i]) > eps:
			return false
	return true


## True when it changes nothing (within `eps`): the layers then show the approved look exactly.
func is_neutral(eps: float) -> bool:
	var plain := neutral()
	plain.hour = hour
	plain.weather = weather
	return is_close(plain, eps)


## Every number in a fixed order (comparisons, logs).
func numbers() -> PackedFloat32Array:
	return PackedFloat32Array([
		hour, night, elevation_change_deg, light_tint.r, light_tint.g, light_tint.b, light_energy,
		ambient_tint.r, ambient_tint.g, ambient_tint.b, ambient_energy, sky_tint.r, sky_tint.g, sky_tint.b, sky_grey,
		fog_density, fog_end, rain, flash, stars, moon_intensity, cloud_cover, cloud_darken, cloud_speed_mul,
	])


## The same moment with the look left as it is (hour and weather kept): what a snap to neutral shows.
func as_neutral() -> AtmosphereSample:
	var plain := neutral()
	plain.hour = hour
	plain.weather = weather
	return plain
