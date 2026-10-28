class_name NavChanges
extends RefCounted

## What changed on the map since the navmesh was last baked: ground that moved (a hole, a crater)
## and blockers that came or went (an altar, a tower, a structure, a fallen building), as rects on
## the ground in metres. It says WHERE to bake again, never when (NavService) or how (NavRebake).
## Idempotent: the same change told twice is one area, and `take` empties it.
## Not: the bake itself, the swap, or the groups that block.

## The blockers the last bake holds, by hash, so a new list can be compared with it (one entry per
## collision shape, see NavService.blockers).
var _known := {}
var _areas: Array[Rect2] = []


## `entries` is the list of blockers the last bake holds.
func reset(entries: Array) -> void:
	_known = _by_hash(entries)


## Ground or a building changed over `rect` (x, z in metres).
func add_area(rect: Rect2) -> void:
	if rect.size.x >= 0.0 and rect.size.y >= 0.0:
		_areas.append(rect)


## The areas added plus the boxes of the blockers that appeared or went since the saved list; empty
## when nothing changed. `entries` becomes the saved list and the added areas are forgotten.
func take(entries: Array) -> Array[Rect2]:
	var now := _by_hash(entries)
	var out: Array[Rect2] = _areas.duplicate()
	for key in now:
		if not _known.has(key):
			out.append(_box_of(now[key]))
	for key in _known:
		if not now.has(key):
			out.append(_box_of(_known[key]))
	_known = now
	_areas.clear()
	return out


## The ground box of a building: its box `box` (own frame) put at `at`.
static func area_of_box(box: AABB, at: Transform3D) -> Rect2:
	var world := at * box
	return Rect2(world.position.x, world.position.z, world.size.x, world.size.z)


static func _by_hash(entries: Array) -> Dictionary:
	var out := {}
	for entry in entries:
		out[entry.hash()] = entry
	return out


## [center, radius] or [center, half extents, yaw]: the square that holds it.
static func _box_of(entry: Array) -> Rect2:
	var center: Vector2 = entry[0]
	var reach: float = entry[1] if entry[1] is float else (entry[1] as Vector2).length()
	return Rect2(center - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
