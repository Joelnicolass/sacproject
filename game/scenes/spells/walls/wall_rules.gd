class_name WallRules
extends RefCounted

## The maths of a wall on the ground, with no tree: which way it runs, how tall it stands at a given age, how its ends slope down, how a
## cast ramps up, and whether a body's box is inside it. A wall is a centre, a unit direction on the ground (x, z) and an interval
## [left, right] of metres along that direction; its thickness is across it. It does not move, hurt or draw anything (SpellWall, WallTouch
## and the look do).
## Ref: sacengine WallPosition, isInWall, castFirewall, Firewall.scale / height (state.d:11118-11131, 19935-19966, 3690-3697).


## The way the wall runs: perpendicular to the line from the caster to the click. A click on the caster itself gives the way he faces.
static func direction_for(caster: Vector3, point: Vector3, facing: Vector3) -> Vector2:
	var line := Vector2(point.x - caster.x, point.z - caster.z)
	var run := Vector2(-line.y, line.x)
	if run.length_squared() > 0.001 * 0.001:
		return run.normalized()
	var ahead := Vector2(facing.x, facing.z)
	return ahead.normalized() if ahead.length_squared() > 0.0 else Vector2.RIGHT


## The unit vector across the wall (the side it is thick on).
static func across(dir: Vector2) -> Vector2:
	return Vector2(dir.y, -dir.x)


## Metres along the wall of `point`, from the centre.
static func along(point: Vector3, center: Vector3, dir: Vector2) -> float:
	return Vector2(point.x - center.x, point.z - center.z).dot(dir)


## Metres across the wall of `point` from its axis (signed).
static func lateral(point: Vector3, center: Vector3, dir: Vector2) -> float:
	return Vector2(point.x - center.x, point.z - center.z).dot(across(dir))


## The yaw that turns a node's +x onto `dir` (Godot's rotation.y about up).
static func yaw_of(dir: Vector2) -> float:
	return atan2(-dir.y, dir.x)


## How tall the wall stands, 0 to 1, at `age` ticks: it rises over `rise_ticks`; once `vanish_at` is set (-1 = never yet) it sinks at the
## speed of a full wall over `vanish_ticks`, from wherever it was.
static func rise(age: int, rise_ticks: int, vanish_at: int, vanish_ticks: int) -> float:
	var at := age if vanish_at < 0 else mini(age, vanish_at)
	var up := 1.0 if rise_ticks <= 0 else clampf(float(at) / float(rise_ticks), 0.0, 1.0)
	if vanish_at < 0:
		return up
	if vanish_ticks <= 0:
		return 0.0
	return maxf(0.0, up - float(age - vanish_at) / float(vanish_ticks))


## The share of the wall's height at metre `t` along it: the ends slope down over 5 m (0.2 per metre in from the end).
static func edge_scale(t: float, left: float, right: float) -> float:
	return minf(minf(0.2 * maxf(0.0, t - left), 0.2 * maxf(0.0, right - t)), 1.0)


## 0 to 1 over `ramp_ticks` once `start_ticks` have passed (the Firewall's damage ramp).
static func ramp(age: int, start_ticks: int, ramp_ticks: int) -> float:
	if ramp_ticks <= 0:
		return 1.0 if age >= start_ticks else 0.0
	return clampf(float(age - start_ticks) / float(ramp_ticks), 0.0, 1.0)


## isInWall: a body's box (world) is inside when it is not above the wall nor below the ground at its centre, its footprint overlaps
## the thickness across the axis, and its extent along the axis overlaps [left, right].
static func in_wall(box: AABB, ground_y: float, top: float, center: Vector3, dir: Vector2, left: float, right: float, thickness: float) -> bool:
	if box.end.y < ground_y or box.position.y > ground_y + top:
		return false
	var low_along := INF
	var high_along := -INF
	var low_across := INF
	var high_across := -INF
	for corner in [Vector3(box.position.x, 0.0, box.position.z), Vector3(box.position.x, 0.0, box.end.z), Vector3(box.end.x, 0.0, box.position.z), Vector3(box.end.x, 0.0, box.end.z)]:
		var a := along(corner, center, dir)
		var c := lateral(corner, center, dir)
		low_along = minf(low_along, a)
		high_along = maxf(high_along, a)
		low_across = minf(low_across, c)
		high_across = maxf(high_across, c)
	return not (high_across < -0.5 * thickness or low_across > 0.5 * thickness) and not (high_along < left or low_along > right)
