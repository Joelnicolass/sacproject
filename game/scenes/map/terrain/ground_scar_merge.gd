class_name GroundScarMerge
extends RefCounted

## How a peer back from a drop merges the marks a donor gives it with the ones it paints itself while it catches up: per picture
## and place (GroundScarRecord.key_of) it counts how many it painted and the most the donor says it has, and paints only what
## raises the larger of the two. A mark both of them paint (a rock that lands on both) shows once, whichever comes first; two
## marks the donor really has at one place show twice.
## What it does not do: paint (GroundScars), keep the list (GroundScarRecord) or send (GroundScarsNet). No tree, no GPU.

var _seen: Dictionary = {}  # place key -> Vector2i(painted here, the most the donor has)


## `painted`: place key -> how many marks this peer already has there (all its own).
func _init(painted: Dictionary) -> void:
	for key: String in painted:
		_seen[key] = Vector2i(int(painted[key]), 0)


## How many times to paint a mark this peer saw itself: 1, or 0 when the donor already gave it.
func own_copies(path: String, at: Vector3) -> int:
	if not GroundScarRecord.travels(path):
		return 1
	var key := GroundScarRecord.key_of(path, at)
	var seen: Vector2i = _seen.get(key, Vector2i.ZERO)
	_seen[key] = seen + Vector2i(1, 0)
	return 1 if seen.x + 1 > seen.y else 0


## How many times to paint the `ordinal`-th mark the donor has at that place: what it adds over what this peer already has.
func given_copies(path: String, at: Vector3, ordinal: int) -> int:
	if not GroundScarRecord.travels(path):
		return 0
	var key := GroundScarRecord.key_of(path, at)
	var seen: Vector2i = _seen.get(key, Vector2i.ZERO)
	_seen[key] = Vector2i(seen.x, maxi(seen.y, ordinal))
	return maxi(0, ordinal - maxi(seen.x, seen.y))
