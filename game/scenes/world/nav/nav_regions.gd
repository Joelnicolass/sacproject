class_name NavRegions
extends RefCounted

## The connected components of a navmesh (RFC-035 035g): what NavGrid answers with its runs of free nodes. Two polygons that share an
## edge are one component; the ids go up in the order of the polygons, so the same navmesh always gives the same ids (no hash order
## decides anything). `component_at` finds the polygon under a point, or the nearest one within `snap_m` (the grid's SNAP_RADIUS).
## Built once from the NavigationMesh resource; the server is not asked anything.

const CELL_M := 8.0
## Vertices are matched by position (a navmesh may repeat one), 1 cm apart is the same vertex.
const KEY_SCALE := 100.0

var component_count := 0
## Polygons per component, by component id.
var sizes := PackedInt32Array()
var polygon_count := 0

var _vertices := PackedVector3Array()
var _polygons: Array[PackedInt32Array] = []
var _component := PackedInt32Array()
## Vector2i cell -> PackedInt32Array of the polygons whose box touches it.
var _cells := {}


func build(navmesh: NavigationMesh) -> void:
	_vertices = navmesh.get_vertices()
	polygon_count = navmesh.get_polygon_count()
	_polygons = []
	_cells = {}
	var canon := PackedInt32Array()
	canon.resize(_vertices.size())
	var by_position := {}
	for i in _vertices.size():
		var v := _vertices[i]
		var key := Vector3i(roundi(v.x * KEY_SCALE), roundi(v.y * KEY_SCALE), roundi(v.z * KEY_SCALE))
		if not by_position.has(key):
			by_position[key] = i
		canon[i] = by_position[key]
	var parent := PackedInt32Array()
	parent.resize(polygon_count)
	for p in polygon_count:
		parent[p] = p
	var edge_owner := {}
	for p in polygon_count:
		var polygon := navmesh.get_polygon(p)
		_polygons.append(polygon)
		var count := polygon.size()
		for k in count:
			var a := canon[polygon[k]]
			var b := canon[polygon[(k + 1) % count]]
			var edge := (mini(a, b) << 32) | maxi(a, b)
			if edge_owner.has(edge):
				_union(parent, p, int(edge_owner[edge]))
			else:
				edge_owner[edge] = p
		_index(p, polygon)
	_component.resize(polygon_count)
	var ids := {}
	component_count = 0
	for p in polygon_count:
		var root := _find(parent, p)
		if not ids.has(root):
			ids[root] = component_count
			component_count += 1
		_component[p] = ids[root]
	sizes.resize(component_count)
	sizes.fill(0)
	for p in polygon_count:
		sizes[_component[p]] += 1


## Component id of the polygon under `point` (flat), else of the nearest polygon within `snap_m`; -1 when there is none.
func component_at(point: Vector3, snap_m: float) -> int:
	var best := -1
	var best_d := INF
	var reach := maxi(0, ceili(snap_m / CELL_M))
	var cell := _cell_of(point.x, point.z)
	var at := Vector2(point.x, point.z)
	for ring in range(0, reach + 1):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var list: PackedInt32Array = _cells.get(Vector2i(cell.x + dx, cell.y + dz), PackedInt32Array())
				for p in list:
					var d := _distance_to_polygon(at, _polygons[p])
					if d < best_d or (d == best_d and p < best):
						best_d = d
						best = p
		## The next ring is at least `ring` cells away: a hit that close cannot be beaten by it.
		if best >= 0 and best_d <= float(ring) * CELL_M:
			break
	if best < 0 or best_d > snap_m:
		return -1
	return _component[best]


## Polygons of the component under (or nearest to) `point`; 0 when there is none within `snap_m`.
func component_size_at(point: Vector3, snap_m: float) -> int:
	var id := component_at(point, snap_m)
	return sizes[id] if id >= 0 else 0


## The point of the land closest (flat) to `point` within `snap_m`: the polygons of components of at least `min_size` polygons (no islands).
## (NAN, NAN, NAN) when there is none. Of two layers at the same flat distance the one nearer to the height of `point` wins. The height
## of the answer is the polygon's own at that spot. Replaces NavigationServer3D.map_get_closest_point*, which walks every polygon of the
## map (half a millisecond at 10k polygons).
func closest_land(point: Vector3, snap_m: float, min_size: int) -> Vector3:
	var best_p := -1
	var best_d := INF
	var best_q := Vector2.ZERO
	var best_dy := INF
	var reach := maxi(0, ceili(snap_m / CELL_M))
	var cell := _cell_of(point.x, point.z)
	var at := Vector2(point.x, point.z)
	for ring in range(0, reach + 1):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var list: PackedInt32Array = _cells.get(Vector2i(cell.x + dx, cell.y + dz), PackedInt32Array())
				for p in list:
					if sizes[_component[p]] < min_size:
						continue
					var d := _nearest_in(at, _polygons[p])
					if d < best_d - 0.01:
						best_p = p
						best_d = d
						best_q = _q
						best_dy = INF
					elif d < best_d + 0.01:
						if best_dy == INF:
							best_dy = absf(_height_at(best_p, best_q) - point.y)
						var dy := absf(_height_at(p, _q) - point.y)
						if dy < best_dy:
							best_p = p
							best_d = minf(d, best_d)
							best_q = _q
							best_dy = dy
		## The next ring is at least `ring` cells away: a hit that close cannot be beaten by it.
		if best_p >= 0 and best_d <= float(ring) * CELL_M:
			break
	if best_p < 0 or best_d > snap_m:
		return Vector3(NAN, NAN, NAN)
	return Vector3(best_q.x, _height_at(best_p, best_q), best_q.y)


## Height of polygon `p` at the flat spot `at` (barycentric in the fan triangle that holds it; the nearest corner's when none does).
func _height_at(p: int, at: Vector2) -> float:
	var polygon := _polygons[p]
	var v0 := _vertices[polygon[0]]
	var nearest := v0.y
	var nearest_d := INF
	for k in range(1, polygon.size() - 1):
		var v1 := _vertices[polygon[k]]
		var v2 := _vertices[polygon[k + 1]]
		var denom := (v1.z - v2.z) * (v0.x - v2.x) + (v2.x - v1.x) * (v0.z - v2.z)
		if absf(denom) > 0.000001:
			var l0 := ((v1.z - v2.z) * (at.x - v2.x) + (v2.x - v1.x) * (at.y - v2.z)) / denom
			var l1 := ((v2.z - v0.z) * (at.x - v2.x) + (v0.x - v2.x) * (at.y - v2.z)) / denom
			var l2 := 1.0 - l0 - l1
			if l0 >= -0.001 and l1 >= -0.001 and l2 >= -0.001:
				return l0 * v0.y + l1 * v1.y + l2 * v2.y
		for v in [v0, v1, v2]:
			var d := Vector2(v.x - at.x, v.z - at.y).length_squared()
			if d < nearest_d:
				nearest_d = d
				nearest = v.y
	return nearest


func _index(p: int, polygon: PackedInt32Array) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in polygon:
		var v := _vertices[i]
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	var from := _cell_of(lo.x, lo.y)
	var to := _cell_of(hi.x, hi.y)
	for cz in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			var key := Vector2i(cx, cz)
			var list: PackedInt32Array = _cells.get(key, PackedInt32Array())
			list.append(p)
			_cells[key] = list


static func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL_M), floori(z / CELL_M))


var _q := Vector2.ZERO


## Flat distance from `at` to the (convex) polygon, 0 inside; the closest point of the polygon is left in `_q`.
func _nearest_in(at: Vector2, polygon: PackedInt32Array) -> float:
	var positive := false
	var negative := false
	var closest := INF
	var closest_q := at
	var count := polygon.size()
	for k in count:
		var a3 := _vertices[polygon[k]]
		var b3 := _vertices[polygon[(k + 1) % count]]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var side := (b.x - a.x) * (at.y - a.y) - (b.y - a.y) * (at.x - a.x)
		if side > 0.0001:
			positive = true
		elif side < -0.0001:
			negative = true
		var ab := b - a
		var length_sq := ab.length_squared()
		var on := a if length_sq <= 0.000001 else a + ab * clampf((at - a).dot(ab) / length_sq, 0.0, 1.0)
		var d := at.distance_to(on)
		if d < closest:
			closest = d
			closest_q = on
	if not (positive and negative):
		_q = at
		return 0.0
	_q = closest_q
	return closest


## 0 when `at` is inside the (convex) polygon, else the distance to its boundary. Flat.
func _distance_to_polygon(at: Vector2, polygon: PackedInt32Array) -> float:
	var positive := false
	var negative := false
	var closest := INF
	var count := polygon.size()
	for k in count:
		var a3 := _vertices[polygon[k]]
		var b3 := _vertices[polygon[(k + 1) % count]]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var side := (b.x - a.x) * (at.y - a.y) - (b.y - a.y) * (at.x - a.x)
		if side > 0.0001:
			positive = true
		elif side < -0.0001:
			negative = true
		closest = minf(closest, _segment_distance(at, a, b))
	return 0.0 if not (positive and negative) else closest


static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)
