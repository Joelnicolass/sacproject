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


## The weather's part of the atmosphere at match second `t_s` (blending at the start of a segment). No plan: neutral.
static func weather_at(plan: WeatherPlan, sky_seed: int, t_s: float) -> AtmosphereSample:
	var now := states_at(plan, sky_seed, t_s)
	if now[0] == null:
		return AtmosphereSample.neutral()
	var to := state_sample(now[1])
	return to if now[2] >= 1.0 or now[0] == now[1] else AtmosphereSample.blend(state_sample(now[0]), to, now[2])


## The weather that rules at `t_s` (the one past half of a blend).
static func state_at(plan: WeatherPlan, sky_seed: int, t_s: float) -> WeatherState:
	var now := states_at(plan, sky_seed, t_s)
	return now[1] if now[2] >= 0.5 else now[0]


## [from: WeatherState, to: WeatherState, w: float]: the previous segment's weather, this one's and how far the blend
## between them is (1 = done). [null, null, 1] without a plan.
static func states_at(plan: WeatherPlan, sky_seed: int, t_s: float) -> Array:
	if plan == null:
		return [null, null, 1.0]
	var seg := maxf(plan.segment_s, 1.0)
	var t := maxf(t_s, 0.0)
	var k := int(floor(t / seg))
	var to := segment_state(plan, sky_seed, k)
	if k == 0 or plan.blend_s <= 0.0:
		return [to, to, 1.0]
	var w := smoothstep(0.0, plan.blend_s, t - float(k) * seg)
	return [segment_state(plan, sky_seed, k - 1), to, w]


## The weather of segment `k`: the plan's first for k = 0, then a weighted draw by the sky's seed (or the list in order).
static func segment_state(plan: WeatherPlan, sky_seed: int, k: int) -> WeatherState:
	var usable := plan.chances.filter(func(c: WeatherChance) -> bool: return c != null and c.state != null and c.weight > 0.0)
	if k <= 0 or usable.is_empty():
		return plan.first
	if plan.in_order:
		return usable[k % usable.size()].state
	var total := 0.0
	for chance: WeatherChance in usable:
		total += chance.weight
	var pick := unit_hash(sky_seed, k) * total
	for chance: WeatherChance in usable:
		pick -= chance.weight
		if pick < 0.0:
			return chance.state
	return usable.back().state


## A state's numbers as a sample (neutral for none).
static func state_sample(state: WeatherState) -> AtmosphereSample:
	return state.to_sample() if state else AtmosphereSample.neutral()


## How much of the land at `d_m` shows through the depth fog (1 = all). Godot's depth fog: amount =
## smoothstep(begin, end, d) ^ curve * density (curve 1, as EnvironmentLayer leaves it), with the sample's multipliers.
static func fog_transmittance(sky: SkyLook, sample: AtmosphereSample, d_m: float) -> float:
	if sky == null or not sky.fog_enabled:
		return 1.0
	var end_m := maxf(sky.fog_end_m * sample.fog_end, sky.fog_begin_m + 0.01)
	var amount := smoothstep(sky.fog_begin_m, end_m, d_m) * sky.fog_density * sample.fog_density
	return 1.0 - clampf(amount, 0.0, 1.0)


## Integer hash of two numbers (splitmix64's finalizer): the same on every architecture, unlike `hash()`.
static func hash_int(a: int, b: int) -> int:
	var z := a * -7046029254386353131 + b  # a * 0x9E3779B97F4A7C15 + b (wraps at 64 bits)
	z = (z ^ (z >> 30) & 0x3FFFFFFFF) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27) & 0x1FFFFFFFFF) * -7723592293110705685  # 0x94D049BB133111EB
	return z ^ (z >> 31) & 0x1FFFFFFFF


## A number in [0, 1) from `hash_int`.
static func unit_hash(a: int, b: int) -> float:
	return float(hash_int(a, b) & 0xFFFFFF) / 16777216.0
