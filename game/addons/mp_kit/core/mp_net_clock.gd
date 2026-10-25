class_name MpNetClock
extends RefCounted

## The server's clock as seen from this machine, shared by every actor of the process. The server stamps its
## states with `stamp()`, its simulation time (physics ticks / ticks per second: perfectly even, unlike the wall
## clock at which ticks happen to run); a client learns the offset from those stamps. Not: the game's own timers.
##
## The offset follows the least-delayed packet (the highest stamp - local time): it jumps up at once and only
## creeps down, so one slow packet never drags the whole timeline back. A big jump down (a new server) resets it.

## How fast the offset may creep down, in seconds per second.
const DECAY_PER_S := 0.002
## An offset this much lower than the current one means another server: start over.
const RESET_S := 1.0

static var _offset: float = 0.0
static var _known: bool = false
static var _last_local: float = 0.0


## Seconds on this machine (monotonic).
static func local_time() -> float:
	return Time.get_ticks_usec() / 1000000.0


## The server's simulation time now (> 0): the stamp of the states it sends this tick.
static func stamp() -> float:
	return 1.0 + float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## The best guess of the server's simulation time now (on the server, its own).
static func server_time() -> float:
	if MpKit.is_authority():
		return stamp()
	return local_time() + _offset


## Server time minus local time, as learned so far.
static func offset() -> float:
	return _offset


static func is_known() -> bool:
	return _known


## A client got a state stamped `stamp` now.
static func observe(stamp: float) -> void:
	var now := local_time()
	var sample := stamp - now
	if not _known or sample > _offset or sample < _offset - RESET_S:
		_offset = sample
		_known = true
	else:
		_offset = maxf(sample, _offset - DECAY_PER_S * maxf(now - _last_local, 0.0))
	_last_local = now


static func reset() -> void:
	_known = false
	_offset = 0.0
