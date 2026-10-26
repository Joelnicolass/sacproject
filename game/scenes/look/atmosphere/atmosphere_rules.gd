class_name AtmosphereRules
extends RefCounted

## The atmosphere's arithmetic, with no tree and no state: the hour at a match second and the light of an hour. The
## same (cycle, seed, seconds) give the same answer on every peer, the dedicated server included, so a rules node can
## follow the hour or the weather from here without asking the look (which a server never builds).
## Uses no random generator: chance comes from `hash_int`, an integer hash of its own (the same on every machine).

## Under this sun elevation the one light is the moon (shadows of a lower sun are too long to read).
const MOON_BELOW_DEG := 5.0
## Highest sun the light takes.
const SUN_TOP_DEG := 89.0


## Hour of the day at match second `t_s`: `start_hour` at 0, a whole day every `length_s`. No cycle: 10.
static func hour_at(cycle: DayCycle, t_s: float) -> float:
	if cycle == null:
		return 10.0
	if cycle.length_s <= 0.0:
		return cycle.start_hour
	return fposmod(cycle.start_hour + t_s / cycle.length_s * 24.0, 24.0)


## True while it is night at `t_s` (the night life and sounds; a rules node could read the same).
static func is_night(cycle: DayCycle, t_s: float) -> bool:
	return day_sample(cycle, hour_at(cycle, t_s)).night >= 0.5


## The day's part of the atmosphere at `hour`. No cycle: neutral.
static func day_sample(cycle: DayCycle, hour: float) -> AtmosphereSample:
	var out := AtmosphereSample.neutral()
	if cycle == null:
		return out
	out.hour = hour
	out.elevation_change_deg = curve_at(cycle.elevation_change_deg, hour, 0.0)
	out.light_energy = curve_at(cycle.light_energy, hour, 1.0)
	out.ambient_energy = curve_at(cycle.ambient_energy, hour, 1.0)
	out.night = clampf(curve_at(cycle.night, hour, 0.0), 0.0, 1.0)
	var dusk := clampf(curve_at(cycle.dusk, hour, 0.0), 0.0, 1.0)
	out.light_tint = tint(cycle.light_dusk, cycle.light_night, dusk, out.night)
	out.ambient_tint = tint(cycle.ambient_dusk, cycle.ambient_night, dusk, out.night)
	out.sky_tint = tint(cycle.sky_dusk, cycle.sky_night, dusk, out.night)
	out.stars = clampf(curve_at(cycle.stars, hour, 0.0), 0.0, 1.0)
	out.moon_intensity = maxf(curve_at(cycle.moon_intensity, hour, 0.0), 0.0)
	return out


## The sun's elevation for a biome whose approved sun is at `sun_elevation_deg`, and whether the light is the moon.
static func light_elevation(sun_elevation_deg: float, sample: AtmosphereSample) -> float:
	return clampf(sun_elevation_deg + sample.elevation_change_deg, MOON_BELOW_DEG, SUN_TOP_DEG)


static func is_moon(sun_elevation_deg: float, sample: AtmosphereSample) -> bool:
	return sun_elevation_deg + sample.elevation_change_deg < MOON_BELOW_DEG


## A curve at `hour`; `fallback` when there is none. A curve with domain 0..1 is read at hour / 24.
static func curve_at(curve: Curve, hour: float, fallback: float) -> float:
	if curve == null or curve.point_count == 0:
		return fallback
	var x := hour if curve.max_domain > 1.0 else hour / 24.0
	return curve.sample(x)


## White by day, the dusk color by `dusk`, then the night color by `night` (both 0 = white, exactly).
static func tint(dusk_color: Color, night_color: Color, dusk: float, night: float) -> Color:
	return Color.WHITE.lerp(dusk_color, dusk).lerp(night_color, night)


## Integer hash of two numbers (splitmix64's finalizer): the same on every architecture, unlike `hash()`.
static func hash_int(a: int, b: int) -> int:
	var z := a * -7046029254386353131 + b  # a * 0x9E3779B97F4A7C15 + b (wraps at 64 bits)
	z = (z ^ (z >> 30) & 0x3FFFFFFFF) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27) & 0x1FFFFFFFFF) * -7723592293110705685  # 0x94D049BB133111EB
	return z ^ (z >> 31) & 0x1FFFFFFFF


## A number in [0, 1) from `hash_int`.
static func unit_hash(a: int, b: int) -> float:
	return float(hash_int(a, b) & 0xFFFFFF) / 16777216.0
