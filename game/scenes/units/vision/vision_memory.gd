class_name VisionMemory
extends RefCounted

## What one Vision keeps in mind: the foes it saw lately (id -> tick) and the sides that saw its body strike one of theirs (side -> tick).
## It only stores and forgets; it does not look (Vision) nor combine sides (VisionSides).

var forget_ticks := 0
var _marks: Dictionary = {}
var _exposed: Dictionary = {}


## The ids still in mind at tick `now`; the lapsed ones (and the freed bodies) are dropped on the way.
func ids(now: int) -> Array:
	return _alive(_marks, now, true)


## Keeps in mind the foes (and founts) among `sight` for the side `mine` of `observer`: a structure or fount for good, a creature until
## `forget_ticks` pass. A foe new to the memory makes the unions of the sides stale (VisionSides).
func take_in(sight: Array, mine: int, observer: Node3D, now: int) -> void:
	if mine <= 0:
		return
	var learned := false
	for other: Variant in sight:
		var node := other as Node3D
		var fount := node.is_in_group(&"manafount")
		if fount or TargetRules.is_valid_foe_of(mine, node, observer):
			learned = learned or not _marks.has(node.get_instance_id())
			_marks[node.get_instance_id()] = Vision.FOREVER if fount or node.is_in_group(&"structure") else now
	if learned:
		VisionSides.touch()


func expose_to(side: int, tick: int) -> void:
	_exposed[side] = tick
	VisionSides.touch()


## The sides that saw this body hurt one of theirs and have not forgotten it.
func exposed_sides(now: int) -> Array:
	return _alive(_exposed, now, false)


func _alive(marks: Dictionary, now: int, bodies: bool) -> Array:
	for key: int in marks.keys():
		if (bodies and not is_instance_id_valid(key)) or VisionRules.lapsed(marks[key], now, forget_ticks):
			marks.erase(key)
	return marks.keys()
