class_name MatchSky
extends Node

## The match's sky clock in this process: the server's match seconds seen from here and the seed of the sky, so every
## peer (the dedicated server too) works out the same hour and weather with AtmosphereRules. It simulates nothing and
## sends nothing: MatchBiome starts it on the authority and BiomeLink carries `message()` in the biome message.
## The authority (solo, listen host, dedicated) counts with MatchClock, which stops while a solo match is paused. A
## client counts wall-clock seconds from the moment the message arrived plus the server's `at_s`, so it never drifts
## when its own tree pauses; its error is the one-way latency.
## It is the node `Context/Sky` of match.tscn and is live while it is in the tree. The static functions are how the
## map's Atmosphere and the audio read it (they live in other scenes); without a match the seed is 0 (no sky yet).

## The sky of the match in the tree (set in _enter_tree, cleared in _exit_tree); null = no match.
static var _live: MatchSky

var _seed := 0
var _authority := false
var _at_s := 0.0
var _adopted_usec := 0


func _enter_tree() -> void:
	_live = self


func _exit_tree() -> void:
	if _live == self:
		_live = null


## The authority starts the sky: time is the match's own clock.
func begin(sky_seed: int) -> void:
	_seed = sky_seed
	_authority = true


## A client takes the server's time and seed (the biome message): `at_s` was the server's match second when it sent it.
func adopt(at_s: float, sky_seed: int) -> void:
	_seed = sky_seed
	_authority = false
	_at_s = at_s
	_adopted_usec = Time.get_ticks_usec()


## What the authority sends a client inside the biome message.
func message() -> Dictionary:
	return {"at_s": _seconds(), "sky_seed": _seed}


## Seconds of the match as the server counts them.
static func now_s() -> float:
	return _live._seconds() if _live != null else 0.0


## The sky's seed. 0 = no match yet. (Not `seed()`: that is the global RNG's, and the look folders grep for it.)
static func sky_seed() -> int:
	return _live._seed if _live != null else 0


static func is_active() -> bool:
	return sky_seed() != 0


func _seconds() -> float:
	if _authority:
		return float(MatchClock.now()) / MatchClock.TICKS_PER_SECOND_F
	if _seed == 0:
		return 0.0
	return _at_s + float(Time.get_ticks_usec() - _adopted_usec) / 1000000.0
