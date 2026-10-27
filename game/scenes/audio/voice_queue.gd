class_name VoiceQueue
extends RefCounted

## Who speaks next on a voice channel that says one line at a time (AdvisorVoice). Pure: it knows
## keys and priorities, never a stream nor a player, so the cases try it without audio. The rules (simplified):
## - A line of a higher priority than the one speaking cuts it (PLAY_NOW) and drops the queued lines below its own.
## - A line of the same or a lower priority never cuts: it waits in the queue (QUEUED) while there is room (`max_queued`).
## - A key already speaking or waiting is DROPPED (the same warning twice in a row says nothing new).
## - When the line ends, `finish()` hands the next one: the highest priority waiting, the oldest among equals.
## Ref: RFC-052 052e (F364); sacengine queueDialogSound, dialogPolicy.

enum Offer { PLAY_NOW, QUEUED, DROPPED }

## Lines waiting at most (the one speaking is not counted).
var max_queued := 3
## The line speaking: {key: StringName, priority: int}, or empty.
var current: Dictionary = {}

var _queued: Array[Dictionary] = []


func _init(p_max_queued := 3) -> void:
	max_queued = maxi(p_max_queued, 0)


## What happens to the line `key` of `priority`. PLAY_NOW: the caller (re)starts the channel with it (it is `current`).
func offer(key: StringName, priority: int) -> Offer:
	if key.is_empty() or is_speaking(key) or is_waiting(key):
		return Offer.DROPPED
	for i in range(_queued.size() - 1, -1, -1):
		if int(_queued[i].priority) < priority:
			_queued.remove_at(i)
	if current.is_empty() or priority > int(current.priority):
		current = {"key": key, "priority": priority}
		return Offer.PLAY_NOW
	if _queued.size() >= max_queued:
		return Offer.DROPPED
	_queued.append({"key": key, "priority": priority})
	return Offer.QUEUED


## The line speaking ended: the next one becomes `current` and is returned ({} when nobody waits).
func finish() -> Dictionary:
	current = {}
	if _queued.is_empty():
		return {}
	var best := 0
	for i in range(1, _queued.size()):
		if int(_queued[i].priority) > int(_queued[best].priority):
			best = i
	current = _queued[best]
	_queued.remove_at(best)
	return current


func is_speaking(key: StringName) -> bool:
	return not current.is_empty() and current.key == key


func is_waiting(key: StringName) -> bool:
	for line in _queued:
		if line.key == key:
			return true
	return false


## Keys waiting, in arrival order.
func waiting() -> Array[StringName]:
	var out: Array[StringName] = []
	for line in _queued:
		out.append(line.key)
	return out


func clear() -> void:
	current = {}
	_queued.clear()
