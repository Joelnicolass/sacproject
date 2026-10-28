class_name StampCarry
extends RefCounted

## Keeps the creatures and wizards on a ground that moves under them, up and down: before the ground over a rect moves,
## `standing` notes the bodies there that are not under it, with the land under each one; after, `follow` puts back on the
## surface every one the new ground now covers, and brings down with it every one that stood on the land when it sank (a quake,
## a dent, a crater). A body under the land before the change (a buried one, one in a pit) is left alone, and so are one that
## flies, one thrown through the air when the land sinks, and one on a roof or another body above the land. Any stamp, any speed.
## Terrain, the one writer of the ground, calls it once per change (one physics tick of every playing stamp together, or a kept
## stamp); it only moves bodies on the server (or solo): the clients get the positions. It does not decide how or when the ground
## moves. Deviation (declared): a body that cannot move (frozen, petrified, vined) also goes down with the land.

## A body whose feet are this far under the land still counts as standing on it (a physics step can sink it a little), and one
## this far above it still stands on the land (not on a roof) when the land sinks.
const SINK_M := 0.5


## The bodies of one change, and the land under each one before it (same order).
class Standing:
	var bodies: Array[Node3D] = []
	## The land under each body before the change.
	var ground_y := PackedFloat32Array()


## The bodies over `rect` (lattice vertices) of `shape` standing on or above the land right now, with the land under them; none on
## a client or off the tree.
static func standing(shape: Terrain, rect: Rect2i) -> Standing:
	var found := Standing.new()
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
			if (
				not (at.x >= low.x and at.x < high.x and at.z >= low.y and at.z < high.y)
				or BodyNudge.airborne(body)
			):
				continue
			var ground := shape.height_at(at.x, at.z)
			if not is_nan(ground) and at.y >= ground - SINK_M:
				found.bodies.append(body)
				found.ground_y.append(ground)
	return found


## Every body of `standing` (taken before the change) that the land of `shape` now covers stands on it again; every one that stood
## on the land and is not thrown goes down with it where it sank.
static func follow(standing: Standing, shape: Terrain) -> void:
	for k in standing.bodies.size():
		var body := standing.bodies[k]
		if not is_instance_valid(body):
			continue
		var at := body.global_position
		var ground := shape.height_at(at.x, at.z)
		if is_nan(ground):
			continue
		var before := standing.ground_y[k]
		if (
			at.y < ground
			or (ground < before and absf(at.y - before) <= SINK_M and not _thrown(body))
		):
			body.global_position.y = ground


## In the air because something threw it (Tumbling): it lands on its own.
static func _thrown(body: Node3D) -> bool:
	var tumbling := BodyNudge.tumbling_of(body)
	return tumbling != null and tumbling.is_on()
