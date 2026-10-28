class_name NavEdgeJoins
extends RefCounted

## Which polygons of a navmesh touch along a border even though they do not share the same two vertices. The navmesh baked by zones
## can split a long side of one polygon in two on the other side of a zone border (a T joint), or leave its vertices a few millimetres
## apart. Godot connects those polygons anyway (edge merge plus the edge connection margin), so NavRegions has to count them as one
## region too, or the AI would call a reachable target unreachable.
## Only the loose sides (the ones with no identical twin) are looked at: on a flat map that is the map border, the holes and the zone
## seams, a small part of all the sides. They go in a grid of cells, and each one is compared only with the loose sides near it.
## Two sides join when both ends of the second are within MERGE_MARGIN_M (flat) of the line of the first, they overlap along it by more
## than MERGE_MARGIN_M, and their heights differ by at most VERTICAL_MARGIN_M. The answer comes out in the order of the sides, which
## follow the order of the polygons, so it is the same every time.
## Ref: Godot NavigationServer3D map_get_edge_connection_margin, project setting navigation/3d/default_edge_connection_margin.

## Godot's default edge connection margin (navigation/3d/default_edge_connection_margin, 0.25 m; the project does not change it).
const MERGE_MARGIN_M := 0.25
## How far apart in height two sides may be: the default cell height of the navigation map (navigation/3d/default_cell_height, 0.25 m,
## the same as NavBakeSettings.cell_height).
const VERTICAL_MARGIN_M := 0.25


## Pairs (p0, q0, p1, q1, ...) of polygons joined by a side. `canon` maps each vertex to its first copy by position; `matched` holds the
## edge keys (min << 32 | max, of canonical vertices) that two polygons already share. `cell_m` is the size of the lookup cells.
static func pairs(
	vertices: PackedVector3Array,
	polygons: Array[PackedInt32Array],
	canon: PackedInt32Array,
	matched: Dictionary,
	cell_m: float
) -> PackedInt32Array:
	var owners := PackedInt32Array()
	var from_pts := PackedVector3Array()
	var to_pts := PackedVector3Array()
	for p in polygons.size():
		var polygon := polygons[p]
		var count := polygon.size()
		for k in count:
			var a := canon[polygon[k]]
			var b := canon[polygon[(k + 1) % count]]
			if a != b and not matched.has((mini(a, b) << 32) | maxi(a, b)):
				owners.append(p)
				from_pts.append(vertices[a])
				to_pts.append(vertices[b])
	var cells := {}
	for i in owners.size():
		var lo := _low(from_pts[i], to_pts[i]) - Vector2.ONE * MERGE_MARGIN_M
		var hi := _high(from_pts[i], to_pts[i]) + Vector2.ONE * MERGE_MARGIN_M
		for cz in range(floori(lo.y / cell_m), floori(hi.y / cell_m) + 1):
			for cx in range(floori(lo.x / cell_m), floori(hi.x / cell_m) + 1):
				var key := Vector2i(cx, cz)
				var list: PackedInt32Array = cells.get(key, PackedInt32Array())
				list.append(i)
				cells[key] = list
	var out := PackedInt32Array()
	var seen := PackedInt32Array()
	seen.resize(owners.size())
	seen.fill(-1)
	for i in owners.size():
		var lo := _low(from_pts[i], to_pts[i])
		var hi := _high(from_pts[i], to_pts[i])
		for cz in range(floori(lo.y / cell_m), floori(hi.y / cell_m) + 1):
			for cx in range(floori(lo.x / cell_m), floori(hi.x / cell_m) + 1):
				var list: PackedInt32Array = cells.get(Vector2i(cx, cz), PackedInt32Array())
				for j in list:
					if j <= i or seen[j] == i or owners[j] == owners[i]:
						continue
					seen[j] = i
					if _overlap(from_pts[i], to_pts[i], from_pts[j], to_pts[j]):
						out.append(owners[i])
						out.append(owners[j])
	return out


static func _low(a: Vector3, b: Vector3) -> Vector2:
	return Vector2(minf(a.x, b.x), minf(a.z, b.z))


static func _high(a: Vector3, b: Vector3) -> Vector2:
	return Vector2(maxf(a.x, b.x), maxf(a.z, b.z))


## True when side b lies along side a (within the margins) over more than MERGE_MARGIN_M of its length. Flat distances, then heights.
static func _overlap(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> bool:
	var origin := Vector2(a0.x, a0.z)
	var along := Vector2(a1.x, a1.z) - origin
	var length := along.length()
	if length <= MERGE_MARGIN_M:
		return false
	along /= length
	var across := Vector2(-along.y, along.x)
	var rel0 := Vector2(b0.x, b0.z) - origin
	var rel1 := Vector2(b1.x, b1.z) - origin
	if absf(across.dot(rel0)) > MERGE_MARGIN_M or absf(across.dot(rel1)) > MERGE_MARGIN_M:
		return false
	var t0 := along.dot(rel0)
	var t1 := along.dot(rel1)
	var from_t := maxf(0.0, minf(t0, t1))
	var to_t := minf(length, maxf(t0, t1))
	if to_t - from_t <= MERGE_MARGIN_M:
		return false
	for t in [from_t, to_t]:
		var on_a := lerpf(a0.y, a1.y, t / length)
		var on_b := b0.y if is_equal_approx(t0, t1) else lerpf(b0.y, b1.y, (t - t0) / (t1 - t0))
		if absf(on_a - on_b) > VERTICAL_MARGIN_M:
			return false
	return true
