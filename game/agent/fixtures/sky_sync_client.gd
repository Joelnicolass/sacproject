extends Node

## RFC-058 058-3: one headless player of `agent/runs/run_058_sync.sh`. It joins the dedicated started by hand, takes the
## slot it is given and, every `--sky-every-s` wall seconds, prints what its sky says:
##   `SKY <name> reloj=<unix s> t=<match s> hora=<h> clima=<state> semilla=<n>` and, for the span since its last line,
##   `SKY <name> rayo t=<match s> rumbo=<deg> dist=<m>` for each lightning strike.
## A headless process frees the look rig, so the probe asks exactly what the rig's Atmosphere and StormStrikes ask: MatchSky
## (the server's seconds and the sky seed from the biome message) and AtmosphereRules, with the look of `--sky-god` and the
## storm plan `debug/look/storm_only.tres`; the gap and the distances are the `Storm` node's own (atmosphere.tscn).
## `--sky-drop-at-s=N` (player B): N seconds in, it leaves the match, waits `--sky-away-s` and joins again: the same seat must
## come back (same slot), with the same seed and clock. `--sky-run-s` how long it prints (300 by default).
## Prints `PASS …` / `FAIL …` per check and `SKY <name> PASS|FAIL`; exit 0 / 1.

const LOCAL_HOST := "127.0.0.1"
const RUNNER_META := "sky_sync_runner"
const STEP_S := 60.0
const STORM_PLAN := preload("res://debug/look/storm_only.tres")
const ATMOSPHERE := preload("res://scenes/look/atmosphere/atmosphere.tscn")

var _name := ""
var _fails := 0
var _slot := 0
var _look: LookProfile
var _gap_s := 4.0
var _near_m := 150.0
var _far_m := 600.0
var _last_t := -1.0


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "SkySyncRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_name = MpBoot.user_value("e2e-name", "?")
	_look = load("res://data/look/%s.tres" % MpBoot.user_value("sky-god", "charnel")) as LookProfile
	_read_storm_knobs()
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	_run.call_deferred()


## The gap and the distances of the real Storm node (never added to the tree: nothing of it runs).
func _read_storm_knobs() -> void:
	var atmosphere := ATMOSPHERE.instantiate()
	var storm := atmosphere.get_node("Weather/Storm") as StormStrikes
	if storm:
		_gap_s = storm.min_gap_s
		_near_m = storm.min_strike_m
		_far_m = storm.max_strike_m
	atmosphere.free()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _wall_s() -> float:
	return Time.get_ticks_msec() / 1000.0


func _sit() -> bool:
	_slot = 0
	MatchSky.reset()  # the next biome message sets it again; until then the sky of the last world must not count
	_check(SacrificeFlow.join_lan(LOCAL_HOST) == OK, "%s joins the dedicated" % _name)
	return await _until(func() -> bool: return _slot != 0 and MatchSky.is_active())


func _run() -> void:
	_check(_look != null and _look.day != null, "%s has the look of --sky-god with a day" % _name)
	_check(await _sit(), "%s gets a slot and the sky" % _name)
	var first_slot := _slot
	var run_s := float(MpBoot.user_value("sky-run-s", "300"))
	var every_s := float(MpBoot.user_value("sky-every-s", "10"))
	var drop_at_s := float(MpBoot.user_value("sky-drop-at-s", "-1"))
	var away_s := float(MpBoot.user_value("sky-away-s", "10"))
	var start := _wall_s()
	var next_line := start
	var dropped := false
	while _wall_s() - start < run_s and _fails == 0:
		if not dropped and drop_at_s >= 0.0 and _wall_s() - start >= drop_at_s:
			dropped = true
			print("SKY %s sale" % _name)
			MpKit.leave()
			_last_t = -1.0
			await _until(func() -> bool: return false, away_s)
			_check(await _sit(), "%s is back with a slot and the sky" % _name)
			_check(_slot == first_slot, "%s sits in the same seat again (slot %d, before %d)" % [_name, _slot, first_slot])
			print("SKY %s vuelve slot=%d" % [_name, _slot])
		if _wall_s() >= next_line:
			next_line += every_s
			_line()
		await get_tree().create_timer(0.05).timeout
	MpKit.leave()
	print("SKY %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _line() -> void:
	var t := MatchSky.now_s()
	var sky_seed := MatchSky.sky_seed()
	var state := AtmosphereRules.state_at(STORM_PLAN, sky_seed, t)
	print("SKY %s reloj=%.3f t=%.3f hora=%.4f clima=%s semilla=%d" % [_name, Time.get_unix_time_from_system(), t,
			AtmosphereRules.hour_at(_look.day, t), state.resource_path.get_file().get_basename(), sky_seed])
	if _last_t >= 0.0:
		for strike in AtmosphereRules.strikes_between(sky_seed, _last_t, t, state.strikes_per_min, _gap_s, _near_m, _far_m):
			print("SKY %s rayo t=%.3f rumbo=%.3f dist=%.3f" % [_name, strike.x, strike.y, strike.z])
	_last_t = t
