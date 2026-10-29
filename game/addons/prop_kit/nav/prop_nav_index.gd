@tool
class_name PropNavIndex
extends RefCounted

## The walkable surface of a navmesh baked in zones, as one piece of data for the questions the
## navigation server does not answer: can an agent get from here to there at all (which polygons
## connect across the zones: the connected components), the polygon and component at a point, the
## closest walkable point (skipping islands, if asked), and the whole navmesh stitched into
## one. Built from the zone pieces on a worker thread (pure data: no nodes, no server), so it is
## ready the moment its pieces are swapped in. Polygons connect where they share an edge, the way
## the navigation map joins the pieces. Points are Vector3 in 3D; the `_2d` calls take and give the
## Vector2 points of a 2D navmesh.

## Every vertex, welded across zones: (x, y, z) in 3D, (x, 0, y) in 2D.
var vertices := PackedVector3Array()
## Each polygon as indexes into `vertices`.
var polygons: Array[PackedInt32Array] = []
## The connected component of each polygon, numbered 0, 1, 2... by their first polygon.
var component_of := PackedInt32Array()
var component_count := 0
## The ground-plane area of each component (world units squared): a small one is an island, such as
## a walkable roof or a pocket closed off by walls.
var component_area := PackedFloat32Array()

var _is_3d := true
var _cell := 1.0
var _buckets: Dictionary[Vector2i, PackedInt32Array] = {}
var _rects: Array[Rect2] = []
## The lowest and highest bucket keys.
var _low := Vector2i.ZERO
var _high := Vector2i.ZERO


## The index of `pieces` (NavigationMesh in 3D, NavigationPolygon in 2D; null = an empty zone).
## Vertices closer than `weld` are one vertex.
static func build(pieces: Array[Resource], is_3d: bool, weld: float) -> PropNavIndex:
	var index := PropNavIndex.new()
	index._is_3d = is_3d
	var step := maxf(weld, 0.0001)
	var welded: Dictionary[Vector3i, int] = {}
	for piece in pieces:
		var local := _vertices_of(piece, is_3d)
		if local.is_empty():
			continue
		var remap := PackedInt32Array()
		remap.resize(local.size())
		for i in local.size():
			var v := local[i]
			var key := Vector3i(roundi(v.x / step), roundi(v.y / step), roundi(v.z / step))
			var at: int = welded.get(key, -1)
			if at < 0:
				at = index.vertices.size()
				welded[key] = at
				index.vertices.append(v)
			remap[i] = at
		for polygon in _polygons_of(piece, is_3d):
			var mapped := PackedInt32Array()
			for i in polygon:
				mapped.append(remap[i])
			index.polygons.append(mapped)
	index._link()
	index._bucket()
	return index


## The polygon under `point` (-1 = none). Where floors overlap, the one nearest in height.
func polygon_at(point: Vector3) -> int:
	var flat := Vector2(point.x, point.z)
	var best := -1
	var best_dy := INF
	for polygon in _buckets.get(_key(flat), PackedInt32Array()):
		if not _rects[polygon].grow(0.0001).has_point(flat):
			continue
		if not Geometry2D.is_point_in_polygon(flat, _flat(polygon)):
			continue
		var dy := absf(_height_on(polygon, flat) - point.y) if _is_3d else 0.0
		if dy < best_dy:
			best = polygon
			best_dy = dy
	return best


## The component under `point` (-1 = none). With `max_distance`, a point off the navmesh takes the
## component of the closest walkable point that near (on the ground plane). With `min_area`, a
## component smaller than that (an island: a roof, a walled pocket) does not count, and the closest
## land that large within `max_distance` does.
func component_at(point: Vector3, max_distance := 0.0, min_area := 0.0) -> int:
	var polygon := polygon_at(point)
	if polygon >= 0 and component_area[component_of[polygon]] < min_area:
		polygon = -1
	if polygon < 0 and max_distance > 0.0:
		polygon = _closest_polygon(point, max_distance, min_area)[0]
	return component_of[polygon] if polygon >= 0 else -1


## True when an agent could walk from `a` to `b`: both on the navmesh (or within `max_distance` of
## it, on the ground plane, on a component of at least `min_area`) and connected.
func can_reach(a: Vector3, b: Vector3, max_distance := 0.0, min_area := 0.0) -> bool:
	var ca := component_at(a, max_distance, min_area)
	return ca >= 0 and ca == component_at(b, max_distance, min_area)


## The walkable point nearest to `point`, among those within `max_distance` of it on the ground
## plane (Vector3.INF = none), on a component of at least `min_area` (0 = any): the closest land,
## not the roof a body stands on. "Within 5 m on the map" whatever the navmesh's height above the
## ground; of the floors in reach, the nearest in 3D.
func closest_point(point: Vector3, max_distance := INF, min_area := 0.0) -> Vector3:
	return _closest_polygon(point, max_distance, min_area)[1]


func polygon_at_2d(point: Vector2) -> int:
	return polygon_at(Vector3(point.x, 0.0, point.y))


func component_at_2d(point: Vector2, max_distance := 0.0, min_area := 0.0) -> int:
	return component_at(Vector3(point.x, 0.0, point.y), max_distance, min_area)


func can_reach_2d(a: Vector2, b: Vector2, max_distance := 0.0, min_area := 0.0) -> bool:
	return can_reach(Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), max_distance, min_area)


func closest_point_2d(point: Vector2, max_distance := INF, min_area := 0.0) -> Vector2:
	var at := closest_point(Vector3(point.x, 0.0, point.y), max_distance, min_area)
	return Vector2.INF if at == Vector3.INF else Vector2(at.x, at.z)


## The whole 3D navmesh as one NavigationMesh, with `like`'s cell and agent settings.
func stitched(like: NavigationMesh = null) -> NavigationMesh:
	var out := like.duplicate() as NavigationMesh if like != null else NavigationMesh.new()
	out.clear_polygons()
	out.set_vertices(vertices)
	for polygon in polygons:
		out.add_polygon(polygon)
	return out


## The whole 2D navmesh as one NavigationPolygon, with `like`'s cell and agent settings.
func stitched_2d(like: NavigationPolygon = null) -> NavigationPolygon:
	var out := like.duplicate() as NavigationPolygon if like != null else NavigationPolygon.new()
	out.clear()
	var flat := PackedVector2Array()
	for v in vertices:
		flat.append(Vector2(v.x, v.z))
	out.vertices = flat
	for polygon in polygons:
		out.add_polygon(polygon)
	return out


## [polygon, point] nearest to `point` in 3D among the points within `max_flat` on the ground
## plane, on components of at least `min_area` ([-1, Vector3.INF] = none).
func _closest_polygon(point: Vector3, max_flat: float, min_area: float) -> Array:
	var best_polygon := -1
	var best := Vector3.INF
	if polygons.is_empty():
		return [best_polygon, best]
	var flat := Vector2(point.x, point.z)
	var center := _key(flat)
	var best_distance := INF
	var seen: Dictionary[int, bool] = {}
	for ring in _rings_limit(center) + 1:
		# A cell `ring` rings away is at least (ring - 1) cells away on the plane, so no farther in 3D.
		var near := (ring - 1) * _cell
		if near > max_flat or near > best_distance:
			break
		for cell in _ring(center, ring):
			for polygon in _buckets.get(cell, PackedInt32Array()):
				if seen.has(polygon):
					continue
				seen[polygon] = true
				if component_area[component_of[polygon]] < min_area:
					continue
				var candidate := _closest_on(polygon, point)
				if Vector2(candidate.x, candidate.z).distance_to(flat) > max_flat:
					candidate = _closest_on_flat(polygon, flat)
					if Vector2(candidate.x, candidate.z).distance_to(flat) > max_flat:
						continue
				var distance := candidate.distance_to(point)
				if distance < best_distance:
					best_polygon = polygon
					best = candidate
					best_distance = distance
	return [best_polygon, best]


## The point of `polygon` nearest to `flat` on the ground plane, at the polygon's height there.
func _closest_on_flat(polygon: int, flat: Vector2) -> Vector3:
	var outline := _flat(polygon)
	var at := flat
	if not Geometry2D.is_point_in_polygon(flat, outline):
		var best := INF
		for k in outline.size():
			var next := outline[(k + 1) % outline.size()]
			var on := Geometry2D.get_closest_point_to_segment(flat, outline[k], next)
			if on.distance_squared_to(flat) < best:
				best = on.distance_squared_to(flat)
				at = on
	return Vector3(at.x, _height_on(polygon, at), at.y)


static func _vertices_of(piece: Resource, is_3d: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	if is_3d and piece is NavigationMesh:
		out = (piece as NavigationMesh).get_vertices()
	elif not is_3d and piece is NavigationPolygon:
		for v in (piece as NavigationPolygon).vertices:
			out.append(Vector3(v.x, 0.0, v.y))
	return out


static func _polygons_of(piece: Resource, is_3d: bool) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if is_3d and piece is NavigationMesh:
		var mesh := piece as NavigationMesh
		for i in mesh.get_polygon_count():
			out.append(mesh.get_polygon(i))
	elif not is_3d and piece is NavigationPolygon:
		var polygon := piece as NavigationPolygon
		for i in polygon.get_polygon_count():
			out.append(polygon.get_polygon(i))
	return out


## Components: polygons that share an edge are one. Each one's area too.
func _link() -> void:
	var parent := PackedInt32Array()
	parent.resize(polygons.size())
	for i in polygons.size():
		parent[i] = i
	var edges: Dictionary[Vector2i, int] = {}
	for i in polygons.size():
		var polygon := polygons[i]
		for k in polygon.size():
			var a := polygon[k]
			var b := polygon[(k + 1) % polygon.size()]
			var edge := Vector2i(mini(a, b), maxi(a, b))
			var other: int = edges.get(edge, -1)
			if other < 0:
				edges[edge] = i
			else:
				_join(parent, i, other)
	var numbers: Dictionary[int, int] = {}
	component_of.resize(polygons.size())
	for i in polygons.size():
		var top := _root(parent, i)
		if not numbers.has(top):
			numbers[top] = numbers.size()
		component_of[i] = numbers[top]
	component_count = numbers.size()
	component_area.resize(component_count)
	component_area.fill(0.0)
	for i in polygons.size():
		component_area[component_of[i]] += absf(_flat_area(i))


## Buckets of polygons by their bounds, for the point queries.
func _bucket() -> void:
	var total := Rect2()
	_rects.clear()
	for i in polygons.size():
		var rect := _flat_rect(i)
		_rects.append(rect)
		total = rect if i == 0 else total.merge(rect)
	if polygons.is_empty():
		return
	_cell = maxf(sqrt(total.get_area() / polygons.size()) * 2.0, 0.001)
	_low = _key(total.position)
	_high = _key(total.end)
	for i in polygons.size():
		var low := _key(_rects[i].position)
		var high := _key(_rects[i].end)
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				var key := Vector2i(x, y)
				var list: PackedInt32Array = _buckets.get(key, PackedInt32Array())
				list.append(i)
				_buckets[key] = list


func _key(flat: Vector2) -> Vector2i:
	return Vector2i(floori(flat.x / _cell), floori(flat.y / _cell))


func _flat(polygon: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in polygons[polygon]:
		out.append(Vector2(vertices[i].x, vertices[i].z))
	return out


## Signed area of `polygon` on the ground plane (shoelace).
func _flat_area(polygon: int) -> float:
	var ids := polygons[polygon]
	var twice := 0.0
	for k in ids.size():
		var a := vertices[ids[k]]
		var b := vertices[ids[(k + 1) % ids.size()]]
		twice += a.x * b.z - b.x * a.z
	return twice * 0.5


func _flat_rect(polygon: int) -> Rect2:
	var points := _flat(polygon)
	var out := Rect2(points[0], Vector2.ZERO)
	for point in points:
		out = out.expand(point)
	return out


## Height of `polygon`'s plane at `flat`.
func _height_on(polygon: int, flat: Vector2) -> float:
	var ids := polygons[polygon]
	var a := vertices[ids[0]]
	var plane := Plane(a, vertices[ids[1]], vertices[ids[2]]) if ids.size() >= 3 else Plane()
	if is_zero_approx(plane.normal.y):
		return a.y
	return (plane.d - plane.normal.x * flat.x - plane.normal.z * flat.y) / plane.normal.y


func _closest_on(polygon: int, point: Vector3) -> Vector3:
	var ids := polygons[polygon]
	var best := vertices[ids[0]]
	var best_distance := INF
	for k in range(1, ids.size() - 1):
		var candidate := _closest_on_triangle(
			point, vertices[ids[0]], vertices[ids[k]], vertices[ids[k + 1]]
		)
		var distance := candidate.distance_squared_to(point)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## Closest point of triangle abc to p (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denominator := 1.0 / (va + vb + vc)
	return a + ab * (vb * denominator) + ac * (vc * denominator)


## The cells at Chebyshev distance `ring` from `center`.
static func _ring(center: Vector2i, ring: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ring == 0:
		out.append(center)
		return out
	for x in range(-ring, ring + 1):
		out.append(center + Vector2i(x, -ring))
		out.append(center + Vector2i(x, ring))
	for y in range(-ring + 1, ring):
		out.append(center + Vector2i(-ring, y))
		out.append(center + Vector2i(ring, y))
	return out


## How many rings around `center` reach every bucket.
func _rings_limit(center: Vector2i) -> int:
	var far := (center - _low).abs().max((_high - center).abs())
	return maxi(far.x, far.y)


static func _root(parent: PackedInt32Array, index: int) -> int:
	var at := index
	while parent[at] != at:
		parent[at] = parent[parent[at]]
		at = parent[at]
	return at


static func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)
