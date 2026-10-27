class_name DamageOverTime
extends Node

## What a lasting dose of damage on a body shares (Poisoned now, Burning in 030l). The original updates
## such an effect once per frame: it deals `per_second / 60` and ends **after** the update whose frame reached `lifetime`
## (deal, then `if(frame>=lifetime) remove`, then `frame+=1`), so a dose of `lifetime`
## frames deals lifetime + 1 times.
## Ref: F122 (RFC-030k-a), sacengine updatePoison state.d:23582-23588.
##
## Someone calls step() once per physics tick and frees the dose when step() returns false: the owner of the doses when
## they add up (Poisoning runs the poison's in the order it keeps), or the dose itself when nothing adds up (Burning, F123).
## Server (or solo) only; Health is replicated, the puff goes through FxBus.

## Health per second and the frames it lasts; set before the owner adds it.
var per_second := 0.0
var lifetime := 0
## Updates already done.
var frame := 0
## Health kind (Health.DIRECT_RANGED, SPLASH_SPELL…) the damage is dealt as.
var kind: StringName = &"splash_spell"
var from_slot := 0
## F164b: the creature that dealt the dose (absolute path; empty = nobody drains). Each tick it feeds LifeDrain with what the
## dose took: the original's tick calls dealDamage with the attacker, which drains.
## Ref: sacengine poison 23585, 9415-9419, drain 8940.
var attacker_path := NodePath()
## DamageMod.ignoreFriendly: an ally takes ×1 with friendly fire on (Health._side_factor).
var ignore_friendly := true
## DamageMod.peirceShield (F123, the Pyromaniac's fire): Health skips the body's shields and states.
var pierce_shield := false
## The burst puffed on the body (at `fx_socket`) every `fx_every_ticks` updates, if the dose took health since the last puff. Null = none.
var fx: ParticleType
var fx_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
var fx_every_ticks := 30
## Health this dose took so far, and the updates it did (for the log).
var taken := 0.0
var updates := 0

var _dealt_since_fx := 0.0


## One update on `health`. False once the dose is over (after dealing on its last frame).
func step(health: Health) -> bool:
	_before_damage()
	updates += 1
	var dealt := health.damage_typed(per_second / float(MatchClock.TICKS_PER_SECOND), kind, from_slot, ignore_friendly, pierce_shield)
	taken += dealt
	if dealt > 0.0 and not attacker_path.is_empty():
		LifeDrain.feed(health.get_node_or_null(attacker_path), health.get_parent(), dealt)
	_dealt_since_fx += dealt
	if fx_every_ticks > 0 and frame % fx_every_ticks == 0:
		## Puff only if Health took it: a body it spares (own side with friendly fire off) must not look poisoned.
		var on := health.get_parent() as Node3D
		if _dealt_since_fx > 0.0 and fx != null and on:
			FxBus.broadcast(fx, BodyFacts.point(on, fx_socket))
		_dealt_since_fx = 0.0
	if frame >= lifetime:
		return false
	frame += 1
	return true


## Updates left, this one included (`lifetime - frame`, what an infection passes on).
func frames_left() -> int:
	return lifetime - frame


## What the variant does at the start of each update, before the damage. Default: nothing.
func _before_damage() -> void:
	pass


## The line the owner prints when the dose ends.
func end_line(who: String, health: Health) -> String:
	return "%s %s total %.1f en %d actualizaciones vida %d" % [_log_word(), who, taken, updates, roundi(health.current)]


func _log_word() -> String:
	return "daño"
