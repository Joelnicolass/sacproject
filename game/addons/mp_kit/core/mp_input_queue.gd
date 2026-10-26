class_name MpInputQueue
extends RefCounted

## Server side of a predicted player: the owner's input frames in seq order. Each frame is simulated exactly once, so
## the server runs the same ticks the owner predicted and corrections stay near zero. Packets repeat the last frames
## (redundancy); copies are dropped here. Pure data. Not: reading keys (MpInput), replaying (MpActor).
##
## Jitter buffer: the server waits until `depth` frames are queued, then takes one per tick, so packets that arrive
## unevenly still move the player evenly (the owner predicts, so only the others see it `depth` ticks later). Starved,
## it waits for `depth` again. Behind by more than CATCH_UP it takes two per tick. Never more than the budget: one per
## tick plus a small bank (BURST), so a client that sends frames faster than real time cannot move faster.

const BURST := 4
const CATCH_UP := 3
## Far behind (a stall, a clock that drifts): skip down to `depth` waiting frames. Rare; costs one correction.
const MAX_WAITING := 16

## Frames queued before the server starts taking them (about the network's jitter, in ticks).
var depth: int = 3
## Adaptive (MpInput turns it on): `depth` follows how late this owner's frames arrive, measured from the times
## add() is given: the 97th percentile of that lateness, in ticks, plus one (as Photon Fusion sizes its input
## buffer). It also grows by one at once when the queue runs dry, and shrinks by one only after SHRINK_TICKS calm
## ticks (taking one extra frame once, so the wait really gets shorter). `slack()` tells the owner how it stands.
var adaptive: bool = false
var min_depth: int = 1
var max_depth: int = 8
## Share of frames allowed to arrive too late (the percentile kept is 1 - this).
var late_tolerance: float = 0.03
const SHRINK_TICKS := 120
## Frames measured (2 s at 60 Hz).
const LATE_WINDOW := 120
## How fast the fastest-arrival baseline may creep up (a clock that drifts), in seconds per second.
const CREEP_PER_S := 0.002

var _calm_ticks: int = 0
var _drain: bool = false
var _lates := PackedFloat64Array()
var _base: float = 0.0
var _base_known: bool = false
var _last_arrival: float = 0.0
var _newest_seq: int = 0

var _waiting: Array[MpInputFrame] = []
var _last_seq: int = 0
var _budget: float = 1.0
var _primed: bool = false


func waiting() -> int:
	return _waiting.size()


## seq of the last frame handed out (0 before any).
func last_seq() -> int:
	return _last_seq


## Frames waiting beyond the depth (negative: the server is short of this owner's frames).
func slack() -> int:
	return _waiting.size() - depth


## The depth the measured lateness asks for (adaptive).
func wanted_depth() -> int:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var late := MpNetQuality.percentile(_lates, 1.0 - late_tolerance)
	return clampi(int(ceil(late / tick - 0.001)) + 1, min_depth, max_depth)


## `arrival_s` (adaptive): when the packet with this frame arrived, on this machine's clock.
func add(frame: MpInputFrame, arrival_s: float = -1.0) -> void:
	if frame == null or frame.seq <= _last_seq:
		return
	if adaptive and arrival_s >= 0.0 and frame.seq > _newest_seq:
		_measure(frame.seq, arrival_s)
	for i in _waiting.size():
		if _waiting[i].seq == frame.seq:
			return
		if _waiting[i].seq > frame.seq:
			_waiting.insert(i, frame)
			return
	_waiting.append(frame)


## The frames to simulate this tick, oldest first (empty: still buffering, starved, or the budget is spent).
func take_for_tick() -> Array[MpInputFrame]:
	_budget = minf(_budget + 1.0, 1.0 + BURST)
	if _waiting.size() > MAX_WAITING:
		_waiting = _waiting.slice(_waiting.size() - depth)
	var out: Array[MpInputFrame] = []
	if adaptive:
		depth = maxi(depth, wanted_depth())
	if _waiting.is_empty():
		if adaptive and _primed:
			depth = mini(depth + 1, max_depth)
			_calm_ticks = 0
		_primed = false
		return out
	if not _primed:
		if _waiting.size() < depth:
			return out
		_primed = true
	var count := 2 if _waiting.size() > depth + CATCH_UP or _drain else 1
	_drain = false
	while out.size() < count and not _waiting.is_empty() and _budget >= 1.0:
		var frame: MpInputFrame = _waiting.pop_front()
		out.append(frame)
		_last_seq = frame.seq
		_budget -= 1.0
	if adaptive:
		_calm_ticks = _calm_ticks + 1 if not _waiting.is_empty() else 0
		if _calm_ticks >= SHRINK_TICKS and depth > maxi(min_depth, wanted_depth()):
			depth -= 1
			_drain = true
			_calm_ticks = 0
	return out


## Lateness of a frame: how much later than the fastest one it came, given that the owner samples one per tick.
func _measure(seq: int, arrival_s: float) -> void:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var base := arrival_s - seq * tick
	if not _base_known or base < _base:
		_base = base
		_base_known = true
	else:
		_base = minf(base, _base + CREEP_PER_S * maxf(arrival_s - _last_arrival, 0.0))
	_last_arrival = arrival_s
	_newest_seq = seq
	_lates.append(base - _base)
	if _lates.size() > LATE_WINDOW:
		_lates.remove_at(0)
