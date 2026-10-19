class_name NavBoxBlockers
extends RefCounted

## The box blockers of the map (the buildings), RFC-035 035g. F88 round 2: «does this straight line go through a building»
## is not something a navmesh knows (a path hugs a corner), so the boxes are kept and a line that crosses one (grown by `clearance_m`)
## is not clear. Without it, a creature at the foot of a tipi was sent straight through the box and pressed on its face for good
## (debug/map/crowd_tipi.tscn).

## One entry per box: [center (x, z), half extents (x, z), cos(yaw), sin(yaw), reach], `reach` being the radius that holds the box and the clearance.
var boxes: Array = []
var clearance_m := 0.5


## Forgets the boxes and sets the clearance of the next ones.
func reset(clearance: float) -> void:
	boxes = []
	clearance_m = clearance


func add(center: Vector2, half: Vector2, yaw: float) -> void:
	boxes.append([center, half, cos(yaw), sin(yaw), half.length() + clearance_m])


## Adds every box entry ([Vector2 center, Vector2 half, yaw], the blockers of NavService) of `entries`; discs are skipped.
func add_entries(entries: Array) -> void:
	for entry in entries:
		if entry.size() >= 3:
			add(entry[0], entry[1], float(entry[2]))


func is_empty() -> bool:
	return boxes.is_empty()


## True when the segment from `a` to `b` (flat) passes through a box grown by `clearance_m` on every side (slab test in the box's frame).
func crosses_box(a: Vector3, b: Vector3) -> bool:
	if boxes.is_empty():
		return false
	var lo_x := minf(a.x, b.x)
	var hi_x := maxf(a.x, b.x)
	var lo_z := minf(a.z, b.z)
	var hi_z := maxf(a.z, b.z)
	for box: Array in boxes:
		var center: Vector2 = box[0]
		var reach: float = box[4]
		if center.x + reach < lo_x or center.x - reach > hi_x or center.y + reach < lo_z or center.y - reach > hi_z:
			continue
		var half: Vector2 = box[1]
		var cos_y: float = box[2]
		var sin_y: float = box[3]
		## Into the box frame (rotated by -yaw, as a box turned `yaw` about Y).
		var ax := a.x - center.x
		var az := a.z - center.y
		var bx := b.x - center.x
		var bz := b.z - center.y
		var p := Vector2(ax * cos_y - az * sin_y, ax * sin_y + az * cos_y)
		var q := Vector2(bx * cos_y - bz * sin_y, bx * sin_y + bz * cos_y)
		if segment_in_box(p, q, half + Vector2(clearance_m, clearance_m)):
			return true
	return false


## Whether the segment p-q meets the box [-half, half] (Liang-Barsky clip).
static func segment_in_box(p: Vector2, q: Vector2, half: Vector2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := q - p
	for axis in 2:
		var start := p[axis]
		var delta := d[axis]
		var lo := -half[axis]
		var hi := half[axis]
		if absf(delta) < 0.000001:
			if start < lo or start > hi:
				return false
			continue
		var ta := (lo - start) / delta
		var tb := (hi - start) / delta
		if ta > tb:
			var swap := ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true
