@tool
class_name Weather
extends Node3D

## The weather's part of the atmosphere: which weather there is at a match second (the plan and the sky's seed,
## through AtmosphereRules, so every peer agrees) and how far a change has blended. It tells `Precipitation` what
## falls and how much and `Storm` the weather that rules (its lightning and the sky's flash), and says when the ruling
## weather changes and when a strike lands. It writes no light: Atmosphere mixes its sample.
## A rules node that needs the weather derives it the same way (AtmosphereRules.state_at) without this node.

## The ruling weather changed (at the middle of a blend).
signal weather_changed(from: WeatherState, to: WeatherState)
## A lightning strike hit the ground at `at` (the `Storm` child drew it). Presentation only.
signal strike(at: Vector3)

@export var precipitation: PrecipitationFall
## The lightning. Empty = a storm with no strikes and no flash.
@export var storm: StormStrikes

## The ruling weather now (null before a plan).
var state_now: WeatherState

## The plan of the last `advance` (Atmosphere's, read again only by `warm`).
var _plan: WeatherPlan


func _ready() -> void:
	if storm:
		storm.struck.connect(func(at: Vector3) -> void: strike.emit(at))


## Warm-up (the WarmHook child): everything that can fall in this plan falls for a moment, one after the other. The lightning's
## bolt and flash are warmed by FxBus's own hook.
func warm(_stage: Node3D) -> void:
	if precipitation == null or _plan == null:
		return
	var states: Array[WeatherState] = [_plan.first]
	for chance in _plan.chances:
		states.append(chance.state if chance else null)
	var shown: Array[PrecipitationLook] = []
	for state in states:
		if state != null and state.precipitation != null and not state.precipitation in shown:
			shown.append(state.precipitation)
			await precipitation.flash(state.precipitation)


## The weather at `t_s` with `plan` and `sky_seed`; `preview` (editor) shows that state alone, fully.
func advance(plan: WeatherPlan, sky_seed: int, t_s: float, preview: WeatherState) -> AtmosphereSample:
	_plan = plan
	var now: Array = [preview, preview, 1.0] if preview else AtmosphereRules.states_at(plan, sky_seed, t_s)
	var sample := AtmosphereRules.state_sample(preview) if preview else AtmosphereRules.weather_at(plan, sky_seed, t_s)
	_rule(sample.weather)
	var from: WeatherState = now[0]
	var to: WeatherState = now[1]
	var look: PrecipitationLook = to.precipitation if to and to.precipitation else (from.precipitation if from else null)
	if precipitation:
		precipitation.show_fall(look, sample.rain)
	if storm:
		sample.flash = storm.follow(null if preview else sample.weather, sky_seed, t_s)
	return sample


## Nothing falls (the layer is hidden or has no look).
func quiet() -> void:
	_rule(null)
	if precipitation:
		precipitation.show_fall(null, 0.0)
	if storm:
		storm.quiet()


## The quality preset's density of the drops.
func set_density(scale: float) -> void:
	if precipitation:
		precipitation.set_density(scale)


func _rule(state: WeatherState) -> void:
	if state == state_now:
		return
	var before := state_now
	state_now = state
	weather_changed.emit(before, state)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if precipitation else PackedStringArray(["Falta el socket Precipitation."])
