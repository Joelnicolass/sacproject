class_name SoundLog
extends RefCounted

## A ring of the last `capacity` sound requests, played or dropped, for the cases and the lab
## (the audio is never judged by ear: the criterion is an entry here). Each entry is a Dictionary:
## {emitter, event, stream (resource path or ""), tick (process frame), played (bool), reason (&"" or why it was dropped)}.

var capacity := 64
var _entries: Array[Dictionary] = []


func _init(p_capacity := 64) -> void:
	capacity = maxi(p_capacity, 1)


func add(
	emitter: StringName,
	event: StringName,
	stream: AudioStream,
	played: bool,
	reason: StringName = &""
) -> void:
	(
		_entries
		. append(
			{
				"emitter": emitter,
				"event": event,
				"stream": stream.resource_path if stream != null else "",
				"tick": Engine.get_process_frames(),
				"played": played,
				"reason": reason,
			}
		)
	)
	while _entries.size() > capacity:
		_entries.pop_front()


## Oldest first.
func entries() -> Array[Dictionary]:
	return _entries.duplicate()


func last() -> Dictionary:
	return _entries.back() if not _entries.is_empty() else {}


func size() -> int:
	return _entries.size()


func clear() -> void:
	_entries.clear()
