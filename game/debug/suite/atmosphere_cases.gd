extends RefCounted

## RFC-058 cases of rules_suite: the atmosphere's arithmetic, without a scene.
##   - (a) day_neutral_start: every god's DayCycle is neutral at its start hour (±1e-3) and its light is ~0 (≤ 0.05)
##     where the sun goes under the moon line (DayCycle.problems);
##   - (e) sky_neutral_start: at the start hour the sky's new uniforms are neutral, so the dresser keeps the SkyLook's
##     own material (the approved sky, exactly);
##   - (f) sky_clock_adopt: MatchSky.adopt(100, s) then now_s() ≈ 100 (±1 tick) and sky_seed() == s;
##   - (g) mix_commutative: AtmosphereSample.mix(a, b) == mix(b, a), and mix(a, neutral) == a.
## Every case returns {ok, ...}; a failing one prints the values. Prints ATMOSPHERE <case>=<bool>.

const GODS: Array[StringName] = [&"persephone", &"james", &"stratos", &"pyro", &"charnel"]


func run(_host: Node) -> Dictionary:
	var results: Dictionary[String, Dictionary] = {
		"day_neutral_start": _day_neutral_start(),
		"sky_neutral_start": _sky_neutral_start(),
		"sky_clock_adopt": _sky_clock_adopt(),
		"mix_commutative": _mix_commutative(),
	}
	var ok := true
	for case_name: String in results:
		var passed: bool = results[case_name].get("ok", false)
		ok = ok and passed
		print("ATMOSPHERE %s=%s" % [case_name, passed])
	return {"atmosphere": {"ok": ok, "cases": results}}


func _looks() -> Array[LookProfile]:
	var out: Array[LookProfile] = []
	for god in GODS:
		out.append(load("res://data/look/%s.tres" % god) as LookProfile)
	return out


func _day_neutral_start() -> Dictionary:
	var bad := PackedStringArray()
	for look in _looks():
		if look == null or look.day == null or look.light == null:
			bad.append("%s: sin Day o sin Light" % (look.god if look else &"?"))
			continue
		for problem in look.day.problems(look.light.sun_elevation_deg):
			bad.append("%s: %s" % [look.god, problem])
	if not bad.is_empty():
		print("ATMOSPHERE   day: %s" % bad)
	return {"ok": bad.is_empty(), "problems": bad}


func _sky_neutral_start() -> Dictionary:
	var bad := PackedStringArray()
	for look in _looks():
		if look == null or look.day == null or look.sky == null:
			continue
		var sample := AtmosphereRules.day_sample(look.day, look.day.start_hour)
		var sky := Sky.new()
		SkyDresser.new().dress(sky, look.sky, sample, Vector2.ZERO, 2.0, true)
		var plain := sample.stars == 0.0 and sample.moon_intensity == 0.0 and sample.cloud_cover == 0.0 \
				and sample.cloud_darken == 0.0 and sample.cloud_speed_mul == 1.0 and sample.sky_grey == 0.0 \
				and sample.sky_tint == Color.WHITE and sample.flash == 0.0
		if not plain or sky.sky_material != look.sky.material:
			bad.append("%s: %s" % [look.god, sample.numbers()])
	if not bad.is_empty():
		print("ATMOSPHERE   sky: %s" % bad)
	return {"ok": bad.is_empty(), "bad": bad}


func _sky_clock_adopt() -> Dictionary:
	MatchSky.adopt(100.0, 4242)
	var at := MatchSky.now_s()
	var same_seed := MatchSky.sky_seed() == 4242
	MatchSky.reset()
	var passed := absf(at - 100.0) <= 1.0 / MatchClock.TICKS_PER_SECOND_F and same_seed
	if not passed:
		print("ATMOSPHERE   adopt: now=%.4f seed_ok=%s" % [at, same_seed])
	return {"ok": passed, "now_s": at}


func _mix_commutative() -> Dictionary:
	var a := AtmosphereSample.neutral()
	a.hour = 21.5
	a.night = 0.8
	a.elevation_change_deg = -40.0
	a.moon = true
	a.light_tint = Color(0.6, 0.7, 1.0)
	a.light_energy = 0.25
	a.sky_tint = Color(0.3, 0.35, 0.5)
	a.stars = 0.9
	a.moon_intensity = 2.0
	var b := AtmosphereSample.neutral()
	b.sky_grey = 0.5
	b.fog_density = 1.6
	b.fog_end = 0.7
	b.rain = 0.8
	b.flash = 0.4
	b.cloud_cover = 0.7
	b.cloud_darken = 0.5
	b.cloud_speed_mul = 2.0
	b.light_energy = 0.6
	var ab := AtmosphereSample.mix(a, b)
	var ba := AtmosphereSample.mix(b, a)
	var identity := AtmosphereSample.mix(a, AtmosphereSample.neutral()).is_close(a, 0.0) \
			and AtmosphereSample.mix(AtmosphereSample.neutral(), b).is_close(b, 0.0)
	var passed := ab.is_close(ba, 1e-6) and identity
	if not passed:
		print("ATMOSPHERE   mix: ab=%s ba=%s identity=%s" % [ab.numbers(), ba.numbers(), identity])
	return {"ok": passed}
