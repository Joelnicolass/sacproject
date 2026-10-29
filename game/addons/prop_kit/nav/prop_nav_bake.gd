@tool
class_name PropNavBake
extends Resource

## A navmesh baked in zones, saved («Bake» on PropNavZones3D / PropNavZones2D) so a game loads it
## instead of baking: one piece per zone, the grid it was cut on, and the fingerprint of the
## obstructions it was baked with. A game whose props differ from these (a match without its
## forest) finds it stale and bakes again.

## Side of a zone, and the grid's area (world units).
@export var zone_size := 0.0
@export var area := Rect2()
@export var border := 0.0
## One NavigationMesh (3D) or NavigationPolygon (2D) per zone, row by row.
@export var pieces: Array[Resource] = []
## PropObstructions.fingerprint of the props it was baked with, of the settings that shape them
## (sides, merge gap, carve) and of the game's `extra_fingerprint`.
@export var fingerprint := 0


## A number that changes when any piece's vertices or polygons change: two bakes of the same scene
## give the same one (`tools/bake_scene.gd --check`).
func content_hash() -> int:
	var parts: Array = [zone_size, area, border]
	for piece in pieces:
		if piece is NavigationMesh:
			var mesh := piece as NavigationMesh
			parts.append(mesh.get_vertices())
			for i in mesh.get_polygon_count():
				parts.append(mesh.get_polygon(i))
		elif piece is NavigationPolygon:
			var polygon := piece as NavigationPolygon
			parts.append(polygon.vertices)
			for i in polygon.get_polygon_count():
				parts.append(polygon.get_polygon(i))
		else:
			parts.append(null)
	return hash(parts)
