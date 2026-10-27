class_name AtmosphereRules
extends RefCounted

## The atmosphere's arithmetic, with no tree and no state: the hour, its light, the weather and the lightning at a
## match second. The same (cycle, seed, seconds) give the same answer on every peer, the dedicated server included, so
## a rules node can follow them from here without asking the look (which a server never builds).
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


## The lightning strikes in (t0_s, t1_s] as (match second, heading_deg, distance_m): the same on every peer and for any
## split of the span. Time is cut in slots of 2 × `min_gap_s`; `per_min` picks evenly which slots strike (a minute gets
## its share, never a burst or a long silence) and the strike falls in the middle half of its slot, so two are never
## closer than `min_gap_s` (photosensitivity; `per_min` tops out at 30 / `min_gap_s`).
static func strikes_between(sky_seed: int, t0_s: float, t1_s: float, per_min: float, min_gap_s := 4.0, near_m := 150.0,
		far_m := 600.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var slot := 2.0 * maxf(min_gap_s, 0.1)
	var chance := clampf(per_min * slot / 60.0, 0.0, 1.0)
	var salt := hash_int(sky_seed, 7919)  # the storm's own draw from the sky seed
	var phase := unit_hash(salt, -1)
	for k in range(int(floor(maxf(t0_s, 0.0) / slot)), int(floor(maxf(t1_s, 0.0) / slot)) + 1):
		if chance <= 0.0 or fposmod(float(k) * chance + phase, 1.0) >= chance:
			continue
		var t := (float(k) + 0.25 + 0.5 * unit_hash(salt, 4 * k + 1)) * slot
		if t > t0_s and t <= t1_s:
			out.append(Vector3(t, 360.0 * unit_hash(salt, 4 * k + 2), lerpf(near_m, far_m, unit_hash(salt, 4 * k + 3))))
	return out


## How much of the land at `d_m` shows through the depth fog (1 = all). Godot's depth fog: amount =
## smoothstep(begin, end, d) ^ curve * density (curve 1, as EnvironmentLayer leaves it), with the sample's multipliers.
static func fog_transmittance(sky: SkyLook, sample: AtmosphereSample, d_m: float) -> float:
	if sky == null or not sky.fog_enabled:
		return 1.0
	var span := fog_range(sky, sample)
	var amount := smoothstep(span.x, span.y, d_m) * sky.fog_density * sample.fog_density
	return 1.0 - clampf(amount, 0.0, 1.0)


## Where the depth fog begins and where it is thickest (m) for the sky's fog bent by the sample: the weather pulls the
## far end in (`fog_end`), the near end in (`fog_begin`) and keeps the play clear (`fog_clear_m`). EnvironmentLayer writes exactly this.
static func fog_range(sky: SkyLook, sample: AtmosphereSample) -> Vector2:
	var begin_m := maxf(sky.fog_begin_m * sample.fog_begin, sample.fog_clear_m)
	return Vector2(begin_m, maxf(sky.fog_end_m * sample.fog_end, begin_m + 1.0))


## The fog's color for the sky's fog bent by the sample: greyed by `sky_grey`, paled by the mist, tinted like the sky.
static func fog_color(sky: SkyLook, sample: AtmosphereSample) -> Color:
	var luma := sky.fog_color.get_luminance()
	var color := sky.fog_color.lerp(Color(luma, luma, luma), sample.sky_grey) if sample.sky_grey > 0.0 else sky.fog_color
	return (color.lerp(sample.mist_color, sample.mist) if sample.mist > 0.0 else color) * sample.sky_tint


## Integer hash of two numbers (splitmix64's finalizer): the same on every architecture, unlike `hash()`.
static func hash_int(a: int, b: int) -> int:
	var z := a * -7046029254386353131 + b  # a * 0x9E3779B97F4A7C15 + b (wraps at 64 bits)
	z = (z ^ (z >> 30) & 0x3FFFFFFFF) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27) & 0x1FFFFFFFFF) * -7723592293110705685  # 0x94D049BB133111EB
	return z ^ (z >> 31) & 0x1FFFFFFFF


## A number in [0, 1) from `hash_int`.
static func unit_hash(a: int, b: int) -> float:
	return float(hash_int(a, b) & 0xFFFFFF) / 16777216.0
