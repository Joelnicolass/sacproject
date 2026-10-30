class_name MatchSky
extends Node

## The match's sky clock in this process: the server's match seconds seen from here and the seed of
## the sky, so every peer (the dedicated server too) works out the same hour and weather with
## AtmosphereRules. It simulates nothing and sends nothing: MatchBiome starts it on the authority
## and BiomeLink carries `message()` in the biome message. The authority (solo, listen host,
## dedicated) counts with MatchClock, which stops while a solo match is paused. A client counts
## wall-clock seconds from the moment the message arrived plus the server's `at_s`, so it never
## drifts when its own tree pauses; its error is the one-way latency. It is the node `Context/Sky`
## of match.tscn and is live while it is in the tree. The static functions are how the map's
## Atmosphere and the audio read it (they live in other scenes); without a match the seed is 0 (no
## sky yet).
## The one who creates the match may pin the hour and the weather (MatchRules `sky_hour` and
## `weather`): they travel in the same message and `day_of` / `weather` hand them to every reader.

## The sky of the match in the tree (set in _enter_tree, cleared in _exit_tree); null = no match.
static var _live: MatchSky

## The day a pinned hour uses on a land whose look has no DayCycle of its own (match.tscn).
@export var default_day: DayCycle

var _seed := 0
var _hour := -1.0
var _weather: WeatherState
var _pinned_from: DayCycle
var _pinned: DayCycle
var _authority := false
var _at_s := 0.0
var _adopted_usec := 0


func _enter_tree() -> void:
	_live = self


func _exit_tree() -> void:
	if _live == self:
		_live = null


## The authority starts the sky: time is the match's own clock. `hour` 0..24 pins the hour (-1 =
## the land's own clock); `weather` forces one (null = the land's plan).
func begin(sky_seed: int, hour := -1.0, weather: WeatherState = null) -> void:
	_seed = sky_seed
	_authority = true
	_pin(hour, weather)


## A client takes the server's time, seed, hour and weather (the biome message): `at_s` was the
## server's match second when it sent it.
func adopt(at_s: float, sky_seed: int, hour := -1.0, weather: WeatherState = null) -> void:
	_seed = sky_seed
	_authority = false
	_at_s = at_s
	_adopted_usec = Time.get_ticks_usec()
	_pin(hour, weather)


## What the authority sends a client inside the biome message.
func message() -> Dictionary:
	return {
		"at_s": _seconds(),
		"sky_seed": _seed,
		"sky_hour": _hour,
		"weather": MatchWire.encode_weather(_weather),
	}


## Seconds of the match as the server counts them.
static func now_s() -> float:
	return _live._seconds() if _live != null else 0.0


## The sky's seed. 0 = no match yet. (Not `seed()`: that is the global RNG's, and the look folders
## grep for it.)
static func sky_seed() -> int:
	return _live._seed if _live != null else 0


static func is_active() -> bool:
	return sky_seed() != 0


## The day the land lives: `look_day` itself, or with the hour pinned a still copy of it (or of
## `default_day` when the land has none) that stays at that hour. Cached: the same instance while
## the pin and the land do not change.
static func day_of(look_day: DayCycle) -> DayCycle:
	if _live == null or _live._hour < 0.0:
		return look_day
	return _live._pinned_day(look_day)


## The weather the match forces; null = the land's plan.
static func weather() -> WeatherState:
	return _live._weather if _live != null else null


func _pin(hour: float, weather: WeatherState) -> void:
	_hour = clampf(hour, 0.0, 24.0) if hour >= 0.0 else -1.0
	_weather = weather
	_pinned_from = null
	_pinned = null


func _pinned_day(look_day: DayCycle) -> DayCycle:
	var source := look_day if look_day != null else default_day
	if source == null:
		return null
	if _pinned == null or _pinned_from != source:
		_pinned_from = source
		_pinned = source.duplicate() as DayCycle
		_pinned.length_s = 0.0
		_pinned.start_hour = _hour
	return _pinned


func _seconds() -> float:
	if _authority:
		return float(MatchClock.now()) / MatchClock.TICKS_PER_SECOND_F
	if _seed == 0:
		return 0.0
	return _at_s + float(Time.get_ticks_usec() - _adopted_usec) / 1000000.0
