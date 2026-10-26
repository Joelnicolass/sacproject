class_name StampCarry
extends RefCounted

## Keeps the creatures and wizards on top of a ground that comes up through them: before the ground over a rect moves, `standing`
## notes the bodies there that are not under it; after, `lift` puts back on the surface every one the new ground now covers. A
## body under the land before the change (a buried one, one in a pit) is left alone, and so is one that flies. Any stamp, any speed:
## a mound, the ring of Erupt's wave, a volcano. Terrain, the one writer of the ground, calls it once per change (one physics
## tick of every playing stamp together, or a kept stamp); it only moves bodies on the server (or solo): the clients get the
## positions. It does not decide how or when the ground moves.

## A body whose feet are this far under the land still counts as standing on it (a physics step can sink it a little).
const SINK_M := 0.5


## The bodies over `rect` (lattice vertices) of `shape` standing on or above the land right now; none on a client or off the tree.
static func standing(shape: Terrain, rect: Rect2i) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if not rect.has_area() or not shape.is_inside_tree() or not shape.is_authority():
		return found
	var tree := shape.get_tree()
	var area := TerrainGrid.area_of(rect)
	var low := area.position
	var high := area.end
	for group in [&"unit", &"wizard"]:
		for node: Node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			var at := body.global_position if body != null else Vector3(NAN, NAN, NAN)
			# The cheap test first: most bodies of the map are outside the rect (NAN never is inside).
			if not (at.x >= low.x and at.x < high.x and at.z >= low.y and at.z < high.y) or BodyNudge.airborne(body):
				continue
			var ground := shape.height_at(at.x, at.z)
			if not is_nan(ground) and at.y >= ground - SINK_M:
				found.append(body)
	return found


## Every body of `bodies` (from `standing`, before the change) that the land of `shape` now covers stands on it again.
static func lift(bodies: Array[Node3D], shape: Terrain) -> void:
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var ground := shape.height_at(body.global_position.x, body.global_position.z)
		if not is_nan(ground) and body.global_position.y < ground:
			body.global_position.y = ground
