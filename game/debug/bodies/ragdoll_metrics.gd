extends RefCounted

## RFC-055 055a-5: how a hanging or fallen ragdoll is measured, as plain numbers over the world positions of its bones. Pure functions:
## the gallery and the cases feed them, they touch no node. `ref_m` is the size of the standing body (the longest side of its rest pose).
## What it does not do: move a body, decide when to measure, print.

## Hang: speed of the fastest bone, 3 s after the hook stops (m/s).
const MAX_SPEED_M_S := 0.5
## Hang and fall: the longest side of the bones over `ref_m`.
const MAX_EXTENT_RATIO := 2.0
## Hang: the longest bone segment over its rest length.
const MAX_STRETCH_RATIO := 1.3
## Hang: how far the anchor bone may be from where the hook says it is (m).
const MAX_ANCHOR_ERROR_M := 0.05
## Hang: how far under the anchor the lowest bone hangs, over `ref_m` (a body that did not hang stays near 0).
const MIN_DROP_RATIO := 0.3
## Fall: how high the highest bone is over the floor, over `ref_m` (a body that lies down is low).
const MAX_TOP_RATIO := 0.45


static func has_nan(points: PackedVector3Array) -> bool:
	for p in points:
		if is_nan(p.x) or is_nan(p.y) or is_nan(p.z) or is_inf(p.x) or is_inf(p.y) or is_inf(p.z):
			return true
	return false


## Speed of the fastest bone between two samples `dt` seconds apart.
static func max_speed(before: PackedVector3Array, now: PackedVector3Array, dt: float) -> float:
	var fastest := 0.0
	for i in mini(before.size(), now.size()):
		fastest = maxf(fastest, before[i].distance_to(now[i]) / dt)
	return fastest


## The longest side of the box around the bones, over the size of the standing body.
static func extent_ratio(points: PackedVector3Array, ref_m: float) -> float:
	return longest_side(points) / maxf(ref_m, 0.01)


## The longest bone segment over its rest length (a segment shorter than 1 cm at rest does not count).
static func stretch_ratio(rest: PackedVector3Array, now: PackedVector3Array, parents: PackedInt32Array) -> float:
	var worst := 1.0
	for i in mini(rest.size(), now.size()):
		var up := parents[i]
		var rest_len := rest[i].distance_to(rest[up]) if up >= 0 else 0.0
		if rest_len > 0.01:
			worst = maxf(worst, now[i].distance_to(now[up]) / rest_len)
	return worst


## Distance between the anchor bone and the place the hook says it must be.
static func anchor_error_m(anchor: Vector3, expected: Vector3) -> float:
	return anchor.distance_to(expected)


## How far under the anchor the lowest bone hangs, over the size of the standing body.
static func drop_ratio(points: PackedVector3Array, anchor_y: float, ref_m: float) -> float:
	var lowest := anchor_y
	for p in points:
		lowest = minf(lowest, p.y)
	return (anchor_y - lowest) / maxf(ref_m, 0.01)


## How high the highest bone is over the floor, over the size of the standing body.
static func top_ratio(points: PackedVector3Array, floor_y: float, ref_m: float) -> float:
	var highest := floor_y
	for p in points:
		highest = maxf(highest, p.y)
	return (highest - floor_y) / maxf(ref_m, 0.01)


## How far on the ground `now` is from `start` (meters, height ignored).
static func drift_m(start: Vector3, now: Vector3) -> float:
	return Vector2(now.x - start.x, now.z - start.z).length()


static func longest_side(points: PackedVector3Array) -> float:
	if points.is_empty():
		return 0.0
	var low := points[0]
	var high := points[0]
	for p in points:
		low = low.min(p)
		high = high.max(p)
	var size := high - low
	return maxf(size.x, maxf(size.y, size.z))


## The thresholds a measured hang breaks (empty = passes). `m` holds the numbers by the names of the functions above.
static func hang_failures(m: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if m.get("nan", false):
		out.append("nan")
	for check: Array in [["max_speed", MAX_SPEED_M_S], ["extent_ratio", MAX_EXTENT_RATIO], ["stretch_ratio", MAX_STRETCH_RATIO], ["anchor_error_m", MAX_ANCHOR_ERROR_M]]:
		if float(m.get(check[0], 0.0)) > float(check[1]):
			out.append(String(check[0]))
	if float(m.get("drop_ratio", 0.0)) < MIN_DROP_RATIO:
		out.append("drop_ratio")
	return out


## The thresholds a measured fall breaks. `max_drift_m` is the driver's own limit; `frozen` says the pose was held after `settle_s`.
static func fall_failures(m: Dictionary, max_drift_m: float) -> PackedStringArray:
	var out := PackedStringArray()
	if m.get("nan", false):
		out.append("nan")
	if float(m.get("top_ratio", 0.0)) >= MAX_TOP_RATIO:
		out.append("top_ratio")
	if float(m.get("drift_m", 0.0)) > max_drift_m + 0.5:
		out.append("drift_m")
	if not m.get("frozen", false):
		out.append("frozen")
	return out


## "key=1.23 ..." for the numbers of `m`, sorted by name.
static func summary(m: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys := m.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [key, ("%.2f" % m[key]) if m[key] is float else str(m[key])])
	return " ".join(parts)
