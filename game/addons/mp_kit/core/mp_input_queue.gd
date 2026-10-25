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

var _waiting: Array[MpInputFrame] = []
var _last_seq: int = 0
var _budget: float = 1.0
var _primed: bool = false


func waiting() -> int:
	return _waiting.size()


## seq of the last frame handed out (0 before any).
func last_seq() -> int:
	return _last_seq


func add(frame: MpInputFrame) -> void:
	if frame == null or frame.seq <= _last_seq:
		return
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
	if _waiting.is_empty():
		_primed = false
		return out
	if not _primed:
		if _waiting.size() < depth:
			return out
		_primed = true
	var count := 2 if _waiting.size() > depth + CATCH_UP else 1
	while out.size() < count and not _waiting.is_empty() and _budget >= 1.0:
		var frame: MpInputFrame = _waiting.pop_front()
		out.append(frame)
		_last_seq = frame.seq
		_budget -= 1.0
	return out
