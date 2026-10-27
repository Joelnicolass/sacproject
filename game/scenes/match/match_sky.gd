class_name MatchSky
extends RefCounted

## The match's sky clock in this process: the server's match seconds seen from here and the seed of the sky, so every
## peer (the dedicated server too) works out the same hour and weather with AtmosphereRules. It simulates nothing and
## sends nothing: MatchBiome carries `message()` in the biome message it already sends.
## The authority (solo, listen host, dedicated) counts with MatchClock, which stops while a solo match is paused. A
## client counts wall-clock seconds from the moment the message arrived plus the server's `at_s`, so it never drifts
## when its own tree pauses; its error is the one-way latency.

static var _seed := 0
static var _authority := false
static var _at_s := 0.0
static var _adopted_usec := 0


## No match: seed 0 (Atmosphere falls back to its own seed and clock). MatchBiome calls it in _ready on every peer.
static func reset() -> void:
	_seed = 0
	_authority = false
	_at_s = 0.0
	_adopted_usec = 0


## The authority starts the sky: time is the match's own clock.
static func begin(sky_seed: int) -> void:
	_seed = sky_seed
	_authority = true


## A client takes the server's time and seed (the biome message): `at_s` was the server's match second when it sent it.
static func adopt(at_s: float, sky_seed: int) -> void:
	_seed = sky_seed
	_authority = false
	_at_s = at_s
	_adopted_usec = Time.get_ticks_usec()


## Seconds of the match as the server counts them.
static func now_s() -> float:
	if _authority:
		return float(MatchClock.now()) / MatchClock.TICKS_PER_SECOND_F
	if _seed == 0:
		return 0.0
	return _at_s + float(Time.get_ticks_usec() - _adopted_usec) / 1000000.0


## The sky's seed. 0 = no match yet. (Not `seed()`: that is the global RNG's, and the look folders grep for it.)
static func sky_seed() -> int:
	return _seed


static func is_active() -> bool:
	return _seed != 0


## What the authority sends a client inside the biome message.
static func message() -> Dictionary:
	return {"at_s": now_s(), "sky_seed": _seed}
