class_name MpInputQueue
extends RefCounted

## Server side of a predicted player: the owner's input frames in seq order, one per tick, each simulated once, so the
## server runs the same ticks the owner predicted and corrections stay near zero. The server never stops simulating a
## player (the others would see it freeze): when the next frame has not come in time (late, or its packets lost) it
## repeats the last one, as Overwatch, Unity Netcode and Photon Fusion do, and drops that frame when it comes. The
## owner kept the same keys on most ticks, so the guess is usually right; when it is not, the owner is corrected (the
## correction fades on its screen). After MAX_GUESSES guesses in a row the keys are let go (a client that froze).
## All of it runs at the clock's pace, not the server's ticks: a server whose ticks run faster than real time
## (`--fixed-fps`) takes and guesses frames no faster than the owner makes them, and one that fell behind (a hitch,
## then a burst of ticks) catches up with the frames it banked.
## Copies and frames that come too late are dropped here. Pure data. Not: reading keys (MpInput), replaying (MpActor).
##
## Jitter buffer: the server waits until `depth` frames are queued, then takes one per tick, so packets that arrive
## unevenly still move the player evenly (the owner predicts, so only the others see it `depth` ticks later). The
## server never changes its pace to resize the buffer (the others would see the player hitch): `slack()` tells the
## owner, which samples one frame more or one less now and then (MpInput, as Overwatch's client speeds up or slows
## down). Only far ahead (more than CATCH_UP beyond the depth) it takes two per tick. Never more than the budget: one
## real tick plus a small bank (BURST), so a client that sends frames faster than real time cannot move faster.

const BURST := 4
const CATCH_UP := 8
## Far behind (a clock that drifts), past what catching up handles (max_depth + CATCH_UP): skip down to `depth`
## waiting frames. Rare; costs one correction.
const MAX_WAITING := 48
## Ticks in a row the last frame is repeated while the owner's frames do not come (0.25 s at 60 Hz); then no keys.
const MAX_GUESSES := 15

## Frames queued before the server starts taking them (about the network's jitter, in ticks).
var depth: int = 3
## Adaptive (MpInput turns it on): `depth` follows how late this owner's frames arrive, measured from the times
## add() is given (the ones that came too late included): the 97th percentile of that lateness, in ticks, plus one
## (as Photon Fusion sizes its input buffer). It grows at once, and shrinks by one only after SHRINK_TICKS calm ticks;
## the owner then sends a little less until the wait is that short. `slack()` tells the owner how it stands.
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
var _lates := PackedFloat64Array()
var _base: float = 0.0
var _base_known: bool = false
var _last_arrival: float = 0.0
var _newest_seq: int = 0

var _waiting: Array[MpInputFrame] = []
var _last_seq: int = 0
var _last_frame: MpInputFrame
var _guesses_in_row: int = 0
## Real time of the last take_for_tick (seconds; -1 = none yet): the budget grows by the real ticks since.
var _last_call_s: float = -1.0
## Ticks simulated with a repeated frame so far (a test or a metric can read it).
var guessed: int = 0
var _budget: float = 0.0
var _primed: bool = false


func waiting() -> int:
	return _waiting.size()


## Waiting frames that follow the last one handed out without a gap (only these can be taken).
func ready() -> int:
	if _waiting.is_empty():
		return 0
	## A fresh queue starts at its first frame, whatever seq it has.
	var next := _last_seq + 1 if _last_seq > 0 else _waiting[0].seq
	var count := 0
	for frame in _waiting:
		if frame.seq != next:
			break
		next += 1
		count += 1
	return count


## seq of the last frame handed out (0 before any).
func last_seq() -> int:
	return _last_seq


## Frames ready beyond the depth (negative: the server is short of this owner's frames).
func slack() -> int:
	return ready() - depth


## The depth the measured lateness asks for (adaptive).
func wanted_depth() -> int:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var late := MpNetQuality.percentile(_lates, 1.0 - late_tolerance)
	return clampi(int(ceil(late / tick - 0.001)) + 1, min_depth, max_depth)


## `arrival_s` (adaptive): when the packet with this frame arrived, on this machine's clock.
func add(frame: MpInputFrame, arrival_s: float = -1.0) -> void:
	if frame == null:
		return
	## Measured even when it comes too late to be used: that lateness is what the buffer must cover.
	if adaptive and arrival_s >= 0.0 and frame.seq > _newest_seq:
		_measure(frame.seq, arrival_s)
	if frame.seq <= _last_seq:
		return
	for i in _waiting.size():
		if _waiting[i].seq == frame.seq:
			return
		if _waiting[i].seq > frame.seq:
			_waiting.insert(i, frame)
			return
	_waiting.append(frame)


## The frames to simulate this tick, oldest first (empty: still buffering, or the budget is spent). `now_s`: this
## machine's real time (seconds), so the budget follows the clock; without it each call is one tick.
func take_for_tick(now_s: float = -1.0) -> Array[MpInputFrame]:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var elapsed := 1.0 if now_s < 0.0 or _last_call_s < 0.0 else maxf(now_s - _last_call_s, 0.0) / tick
	_last_call_s = now_s
	_budget = minf(_budget + elapsed, 1.0 + BURST)
	if _waiting.size() > MAX_WAITING:
		_waiting = _waiting.slice(_waiting.size() - depth)
		_last_seq = _waiting[0].seq - 1
	var out: Array[MpInputFrame] = []
	if adaptive:
		depth = maxi(depth, wanted_depth())
	var ready_now := ready()
	if not _primed:
		if ready_now == 0 or ready_now < depth:
			return out
		_primed = true
	if ready_now == 0:
		## Starved: the next frame is late or lost. Repeat the last one (its seq goes by); its lateness, once it comes,
		## makes the buffer longer.
		_calm_ticks = 0
		if _budget >= 1.0:
			out.append(_guess())
			_budget -= 1.0
		return out
	_guesses_in_row = 0
	var count := mini(2 if ready_now > depth + CATCH_UP else 1, ready_now)
	while out.size() < count and _budget >= 1.0:
		var frame: MpInputFrame = _waiting.pop_front()
		out.append(frame)
		_last_seq = frame.seq
		_last_frame = frame
		_budget -= 1.0
	if adaptive:
		_calm_ticks = _calm_ticks + 1 if not _waiting.is_empty() else 0
		if _calm_ticks >= SHRINK_TICKS and depth > maxi(min_depth, wanted_depth()):
			depth -= 1
			_calm_ticks = 0
	return out


## The frame for the next seq when the owner's has not come: the last one again (no new press), or no keys at all
## once MAX_GUESSES went by.
func _guess() -> MpInputFrame:
	var frame := _last_frame.next()
	_guesses_in_row += 1
	guessed += 1
	if _guesses_in_row > MAX_GUESSES:
		frame.strengths.fill(0.0)
	_last_seq = frame.seq
	_last_frame = frame
	_waiting = _waiting.filter(func(f: MpInputFrame) -> bool: return f.seq > _last_seq)
	return frame


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
