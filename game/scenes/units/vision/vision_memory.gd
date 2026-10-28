class_name VisionMemory
extends RefCounted

## What one Vision keeps in mind: the foes it saw lately (id -> tick) and the sides that saw its
## body strike one of theirs (side -> tick). It only stores and forgets; it does not look (Vision)
## nor combine sides (VisionSides).

var forget_ticks := 0:
	set(value):
		forget_ticks = value
		VisionSides.touch()
## The foes in sight at the last look (`_stamp`) and, once they left, the tick they were last seen
## (or FOREVER).
var _current: Dictionary = {}
var _stamp := -1
var _older: Dictionary = {}
var _exposed: Dictionary = {}


## The ids still in mind at tick `now`; the lapsed ones (and the freed bodies) are dropped on the
## way.
func ids(now: int) -> Array:
	var found: Array = _alive(_older, now, true)
	if _stamp >= 0 and not VisionRules.lapsed(_stamp, now, forget_ticks):
		found.append_array(_current.keys())
	return found


## The first tick after `now` at which something here lapses (a very large number when nothing
## will).
func next_lapse(now: int) -> int:
	var soonest := Vision.FOREVER
	if not _current.is_empty():
		soonest = _stamp + forget_ticks
	for id: int in _older:
		if _older[id] != Vision.FOREVER:
			soonest = mini(soonest, _older[id] + forget_ticks)
	return maxi(soonest, now + 1)


## Keeps in mind the foes (and founts) among `sight` for the side `mine` of `observer`, as of tick
## `now`. A foe that stays in sight is renewed by the new look; one that left is remembered for
## `forget_ticks` from the last look that had it; a structure or fount for good. A foe new to the
## memory makes the unions of the sides stale (VisionSides); one it did not have in mind at `now`
## (absent, or lapsed but not dropped yet) is announced on `VisionSides.events.learned`, once the
## memory is up to date.
func take_in(sight: Array, mine: int, observer: Node3D, now: int) -> void:
	if mine <= 0:
		return
	var fresh := {}
	var learned := false
	var news: Array[Node3D] = []
	for node: Node3D in sight:
		var kind := VisionSides.mark_kind(mine, node, observer)
		if kind == 0:
			continue
		var id := node.get_instance_id()
		fresh[id] = true
		learned = learned or not (_current.has(id) or _older.has(id))
		if not _remembers(id, now):
			news.append(node)
		if kind == 2:
			_older[id] = Vision.FOREVER
		else:
			_older.erase(id)
	for id: int in _current:
		if not fresh.has(id) and not _older.has(id):
			_older[id] = _stamp
	_current = fresh
	_stamp = now
	if learned:
		VisionSides.touch()
	for node in news:
		VisionSides.events.learned.emit(mine, node)


## Side `side` saw `body` (the owner of this memory) strike one of its own at `tick`: that side sees
## it for a while.
func expose_to(side: int, tick: int, body: Node3D) -> void:
	var news := not _exposed.has(side) or VisionRules.lapsed(_exposed[side], tick, forget_ticks)
	_exposed[side] = tick
	VisionSides.touch()
	if news and body != null:
		VisionSides.events.learned.emit(side, body)


## Every id this memory holds, lapsed or not; it drops nothing (VisionSides.remembered).
func held_ids() -> Array:
	var found: Array = _current.keys()
	found.append_array(_older.keys())
	return found


func has_exposures() -> bool:
	return not _exposed.is_empty()


## `id` is in mind at tick `now`: the test of `ids`, without dropping anything.
func _remembers(id: int, now: int) -> bool:
	if _older.has(id) and not VisionRules.lapsed(_older[id], now, forget_ticks):
		return true
	return _current.has(id) and _stamp >= 0 and not VisionRules.lapsed(_stamp, now, forget_ticks)


## The sides that saw this body hurt one of theirs and have not forgotten it.
func exposed_sides(now: int) -> Array:
	return _alive(_exposed, now, false)


func _alive(marks: Dictionary, now: int, bodies: bool) -> Array:
	for key: int in marks.keys():
		if (
			(bodies and not is_instance_id_valid(key))
			or VisionRules.lapsed(marks[key], now, forget_ticks)
		):
			marks.erase(key)
	return marks.keys()
