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
## Multiplier of how dark the sun's shadows are (1 = as approved; an overcast sky softens them).
var shadow := 1.0
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
## The fog starts no closer than this (0 = where the sky says): a mist that hides the far land, not the play.
var fog_clear_m := 0.0
## Multiplier of where the fog begins (below 1 the mist comes closer, never closer than `fog_clear_m`).
var fog_begin := 1.0
## 0..1: how far the fog color goes to the pale `mist_color` (a white mist over any biome's fog).
var mist := 0.0
var mist_color := Color.WHITE
## 0..1: how much it rains (drops and the sound bed).
var rain := 0.0
## 0..1: the storm flash now.
var flash := 0.0
## How many stars show (0..1) and the moon disc's brightness added to the sky's own.
var stars := 0.0
var moon_intensity := 0.0
## Extra cloud cover (0 = the sky's own clouds), how much darker they are, and how much faster they drift.
var cloud_cover := 0.0
var cloud_darken := 0.0
var cloud_speed_mul := 1.0
## The weather state this sample comes from (null in the day's sample).
var weather: WeatherState


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
	out.shadow = a.shadow * b.shadow
	out.ambient_tint = a.ambient_tint * b.ambient_tint
	out.ambient_energy = a.ambient_energy * b.ambient_energy
	out.sky_tint = a.sky_tint * b.sky_tint
	out.sky_grey = maxf(a.sky_grey, b.sky_grey)
	out.fog_density = a.fog_density * b.fog_density
	out.fog_end = a.fog_end * b.fog_end
	out.fog_clear_m = maxf(a.fog_clear_m, b.fog_clear_m)
	out.fog_begin = a.fog_begin * b.fog_begin
	out.mist = maxf(a.mist, b.mist)
	out.mist_color = a.mist_color if a.mist >= b.mist else b.mist_color
	out.rain = maxf(a.rain, b.rain)
	out.flash = minf(a.flash + b.flash, 1.0)
	out.stars = maxf(a.stars, b.stars)
	out.moon_intensity = maxf(a.moon_intensity, b.moon_intensity)
	out.cloud_cover = maxf(a.cloud_cover, b.cloud_cover)
	out.cloud_darken = maxf(a.cloud_darken, b.cloud_darken)
	out.cloud_speed_mul = a.cloud_speed_mul * b.cloud_speed_mul
	out.weather = a.weather if a.weather != null else b.weather
	return out


## `a` turned into `b` by `w` (0..1): each number eased linearly; the weather is the one past half.
static func blend(a: AtmosphereSample, b: AtmosphereSample, w: float) -> AtmosphereSample:
	var out := AtmosphereSample.new()
	var x := a.numbers()
	var y := b.numbers()
	for i in x.size():
		x[i] = lerpf(x[i], y[i], w)
	out._take(x)
	out.moon = b.moon if w >= 0.5 else a.moon
	out.weather = b.weather if w >= 0.5 else a.weather
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
		shadow, fog_clear_m, fog_begin, mist, mist_color.r, mist_color.g, mist_color.b,
	])


func _take(n: PackedFloat32Array) -> void:
	hour = n[0]; night = n[1]; elevation_change_deg = n[2]
	light_tint = Color(n[3], n[4], n[5]); light_energy = n[6]
	ambient_tint = Color(n[7], n[8], n[9]); ambient_energy = n[10]
	sky_tint = Color(n[11], n[12], n[13]); sky_grey = n[14]
	fog_density = n[15]; fog_end = n[16]; rain = n[17]; flash = n[18]
	stars = n[19]; moon_intensity = n[20]; cloud_cover = n[21]; cloud_darken = n[22]; cloud_speed_mul = n[23]
	shadow = n[24]; fog_clear_m = n[25]; fog_begin = n[26]
	mist = n[27]; mist_color = Color(n[28], n[29], n[30])


## The same moment with the look left as it is (hour and weather kept): Atmosphere snaps a sample within a hair of
## neutral to this, so the start of a match shows the approved look byte for byte.
func as_neutral() -> AtmosphereSample:
	var plain := neutral()
	plain.hour = hour
	plain.weather = weather
	return plain
