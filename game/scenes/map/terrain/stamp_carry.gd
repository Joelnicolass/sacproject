class_name StampCarry
extends RefCounted

## Lifts the creatures and wizards the ground just came up through back onto it: a body whose feet are under the new surface, but
## not deeper than `reach_m`, is put on the surface. For a stamp that climbs faster than a body can follow (a volcano's mound).
## It moves nothing that flies or that is far under the land, and it does not decide when the ground moves (TerrainStamp).


## Bodies over `rect` (lattice vertices of the stamp) that the land of `shape` buried by at most `reach_m` stand on it again.
static func lift(tree: SceneTree, shape: GroundSurface, rect: Rect2i, reach_m: float) -> void:
	var area := Rect2(Vector2(rect.position) * TerrainRules.CELL, Vector2(rect.size) * TerrainRules.CELL)
	for group in [&"unit", &"wizard"]:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or BodyNudge.airborne(body) or not area.has_point(Vector2(body.global_position.x, body.global_position.z)):
				continue
			var ground := shape.height_at(body.global_position.x, body.global_position.z)
			if not is_nan(ground) and body.global_position.y < ground and body.global_position.y > ground - reach_m:
				body.global_position.y = ground
