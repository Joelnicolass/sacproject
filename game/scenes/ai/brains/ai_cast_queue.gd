class_name AiCastQueue
extends RefCounted

## The queue of casts of a wizard: forced entries first, then by score, best first; a new entry goes
## before the ones with its score; an entry with the same spell tag replaces the old one. Entries
## are Dictionaries {forced (bool), score, target (AiTrack|null), obj (AiTrack|null), range, spell
## (Resource)}. The queue is emptied at every replan of the wizard. Static.
## Ref: shiny.d:2638-2662 `enqueueCast`, 0x48ced0 + 0x48ce40; shiny.d:3333


## `forced`: the original's flag 1 (it goes first and waits for the mana it needs).
static func make(
	forced: bool, score: float, target: AiTrack, spell: Resource, range_m: float, obj: AiTrack
) -> Dictionary:
	return {
		"forced": forced,
		"score": score,
		"target": target,
		# obj0 == 0 falls back to the target.
		# Ref: shiny.d:2640
		"obj": obj if obj != null else target,
		"range": range_m,
		"spell": spell,
	}


## Returns the index the entry took.
static func enqueue(queue: Array, entry: Dictionary) -> int:
	var tag := str((entry["spell"] as Resource).get("tag")) if entry["spell"] != null else ""
	if not tag.is_empty():
		for i in queue.size():
			var other: Resource = queue[i]["spell"]
			if other != null and str(other.get("tag")) == tag:
				queue.remove_at(i)
				break
	var at := 0
	while at < queue.size():
		var q: Dictionary = queue[at]
		var q_forced: bool = q["forced"]
		var n_forced: bool = entry["forced"]
		if q_forced != n_forced:
			if n_forced:
				break
		elif float(q["score"]) <= float(entry["score"]):
			break
		at += 1
	queue.insert(at, entry)
	return at
