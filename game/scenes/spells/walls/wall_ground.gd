class_name WallGround
extends RefCounted

## What a wall asks of the world around it: the land under a point, whether an end may stand there, and which bodies are inside it now.
## It holds no state of the wall (SpellWall) and hurts nobody (WallTouch). Without a map (a bare debug floor) the land is flat at the
## wall's own height and everywhere.
## Ref: sacengine Firewall.check, wallTargets (state.d:20024-20034, 19976-19997).

const BUILDINGS: StringName = &"structure"


## The land height under (x, z), or the wall's own height when there is no map or the point is a hole.
static func ground_y(wall: Node3D, fallback: float, x: float, z: float) -> float:
	var shape := TerrainShape.of(wall)
	if shape == null:
		return fallback
	var land := shape.height_at(x, z)
	return fallback if is_nan(land) else land


## One tick of growth: each end that has not stopped moves out a step, or stops where it may not stand.
static func grow(wall: SpellWall) -> void:
	if wall.vanish_at >= 0 or (wall.left_stopped and wall.right_stopped):
		return
	var step := wall.reach_m() / float(wall.grow_ticks)
	if not wall.left_stopped:
		wall.left_stopped = not can_stand(wall, wall.left - step)
		wall.left -= 0.0 if wall.left_stopped else step
	if not wall.right_stopped:
		wall.right_stopped = not can_stand(wall, wall.right + step)
		wall.right += 0.0 if wall.right_stopped else step


## An end may stand at metre `t`: within reach, on the land and not inside a building.
static func can_stand(wall: SpellWall, t: float) -> bool:
	if absf(t) > wall.reach_m() + wall.reach_slack_m:
		return false
	var at := wall.point_at(t)
	var shape := TerrainShape.of(wall)
	if shape != null and not shape.is_on_ground(at.x, at.z):
		return false
	for node in wall.get_tree().get_nodes_in_group(BUILDINGS):
		var building := node as Node3D
		if building != null and building.is_inside_tree() and SplashDamage.box_distance(building, at) <= 0.0:
			return false
	return true


## The live creatures and wizards inside the wall now (isInWall).
static func bodies_inside(wall: SpellWall) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var top := wall.top()
	if top <= 0.0 or wall.right <= wall.left:
		return found
	var a := wall.point_at(wall.left)
	var b := wall.point_at(wall.right)
	var margin := 1.5 * wall.thickness_m()
	var low := Vector3(minf(a.x, b.x) - margin, wall.center.y - 500.0, minf(a.z, b.z) - margin)
	var high := Vector3(maxf(a.x, b.x) + margin, wall.center.y + 500.0, maxf(a.z, b.z) + margin)
	for each in BodyNudge.bodies_in(wall.get_tree(), AABB(low, high - low)):
		var box := BodyNudge.box(each)
		var middle := box.get_center()
		if WallRules.in_wall(box, wall.ground_y(middle.x, middle.z), top, wall.center, wall.direction, wall.left, wall.right, wall.thickness_m()):
			found.append(each)
	return found
