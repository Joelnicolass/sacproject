@tool
class_name Atmosphere
extends LookLayer

## The atmosphere layer of the rig: the hour and the weather now, as one AtmosphereSample the sun, the environment and
## the ambient life read (`changed`); it writes no light, sky or fog itself. Hour and weather come from the match's sky
## clock and seed (MatchSky) with the look's DayCycle and WeatherPlan, so every peer sees the same. Hidden: neutral (the
## approved look, exactly). Its events (`hour_changed`, `night_changed`, Weather's `weather_changed` / `strike`) are
## presentation; a rules node derives the same state with AtmosphereRules on any peer. Freed with the rig on a server.

## The atmosphere moved (at most `update_hz` times a second, every frame during a storm flash; only on a change).
signal changed(sample: AtmosphereSample)
## A new whole hour began (0..23).
signal hour_changed(hour: int)
## The night began (true) or ended (false).
signal night_changed(is_night: bool)

## How often the light follows the atmosphere.
@export_range(1.0, 60.0, 1.0, "suffix:Hz") var update_hz: float = 10.0
## How often the sky (and its reflection cubemap, which re-bakes) follows it.
@export_range(0.5, 30.0, 0.5, "suffix:Hz") var sky_hz: float = 2.0
## Debug only: how many times faster the day goes (60 = a day in 24 s; not the weather). Networked: keep it at 1.
@export_range(0.0, 600.0, 1.0) var time_scale: float = 1.0
## Debug: pins the hour (0..24, captures). -1 = the clock's hour.
@export_range(-1.0, 24.0, 0.01) var frozen_hour: float = -1.0
## The seed when there is no match (debug scenes, the editor).
@export var fallback_seed: int = 58
## Debug: this plan instead of the look's.
@export var plan_override: WeatherPlan

@export_group("Editor preview")
## Editor only: shows this hour in the viewport (-1 = the biome's start hour, the approved light). Never saved into the look.
@export_range(-1.0, 24.0, 0.01) var preview_hour: float = -1.0:
	set(value):
		preview_hour = value
		if Engine.is_editor_hint() and is_node_ready():
			publish()
## Editor only: shows this weather in the viewport (empty = Clear, the approved look).
@export var preview_weather: WeatherState:
	set(value):
		preview_weather = value
		if Engine.is_editor_hint() and is_node_ready():
			publish()

@export_group("Now (read-only)")
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var hour_now: float = -1.0
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var weather_now: String = ""

var _cycle: DayCycle
var _plan: WeatherPlan
var _sun_elevation_deg := 45.0
var _current := AtmosphereSample.neutral()
var _own_s := 0.0
var _since_update := 0.0
var _since_log := 0.0
var _last_hour := -1
var _was_night := false

@onready var _time: TimeOfDay = %TimeOfDay
@onready var _weather: Weather = %Weather


func _ready() -> void:
	visibility_changed.connect(publish)
	set_process(not Engine.is_editor_hint())


func apply_look(profile: LookProfile, _rig: LookRig) -> void:
	_cycle = profile.day if profile else null
	_plan = profile.weather if profile else null
	_sun_elevation_deg = profile.light.sun_elevation_deg if profile and profile.light else 45.0
	publish()


func apply_quality(preset: LookQuality) -> void:
	if is_node_ready():
		_weather.set_density(preset.rain_density_scale if preset else 1.0)


func _process(delta: float) -> void:
	_own_s += delta
	_since_update += delta
	_since_log += delta
	if _since_update >= 1.0 / update_hz or _current.flash > 0.0:  # every frame while a storm flash lasts
		_since_update = 0.0
		publish()
	if _since_log >= 10.0:
		_since_log = 0.0
		if DebugLog.on(&"atmosphere"): print("atmosfera t=%.1f hora=%.2f clima=%s" % [now_s(), _current.hour, _weather_name()])


## The atmosphere now (neutral before a look applies).
func current() -> AtmosphereSample:
	return _current


## The match second the atmosphere is at (the match's sky clock, else this layer's own).
func now_s() -> float:
	return MatchSky.now_s() if MatchSky.is_active() else _own_s


## The seed the weather draws from.
func sky_seed() -> int:
	return MatchSky.sky_seed() if MatchSky.is_active() else fallback_seed


## Works out the sample now and says it when it changed. Idempotent.
func publish() -> void:
	if not is_node_ready():
		return
	var next := _sample_now()
	if next.is_close(_current, 1e-5):
		return
	_current = next
	hour_now = next.hour
	weather_now = _weather_name()
	changed.emit(next)
	_emit_events(next)


func _sample_now() -> AtmosphereSample:
	if (_cycle == null and _plan == null) or not is_visible_in_tree():
		_weather.quiet()
		return AtmosphereSample.neutral()
	var pin := frozen_hour
	if Engine.is_editor_hint():
		pin = preview_hour if preview_hour >= 0.0 else (_cycle.start_hour if _cycle else -1.0)
	var t := now_s()
	var day := _time.sample_at(_cycle, t * time_scale, pin)
	day.moon = AtmosphereRules.is_moon(_sun_elevation_deg, day)
	var plan: WeatherPlan = null if Engine.is_editor_hint() else (plan_override if plan_override else _plan)
	var sample := AtmosphereSample.mix(day, _weather.advance(plan, sky_seed(), t, preview_weather))
	return sample.as_neutral() if sample.is_neutral(1e-4) else sample


func _emit_events(sample: AtmosphereSample) -> void:
	if sample.hour < 0.0:
		return
	var whole := int(sample.hour)
	if whole != _last_hour:
		_last_hour = whole
		hour_changed.emit(whole)
	var is_night := sample.night >= 0.5
	if is_night != _was_night:
		_was_night = is_night
		night_changed.emit(is_night)


func _weather_name() -> String:
	return _current.weather.resource_path.get_file().get_basename() if _current.weather else "-"
