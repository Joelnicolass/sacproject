extends RefCounted

## Plan 071 Z4 case of rules_suite: NavRegions joins two polygons whose sides lie along each other, not only the ones that share the same
## two vertices. Navmeshes made by hand: a square beside two rectangles that split its side in two (T joint) is one region; two squares
## 1 cm apart (flat or in height) are one region; two squares 1 m apart (flat or in height) are two. Also the ids stay the same when the
## navmesh is built twice.

func run(_host: Node) -> Dictionary:
	var left := _square(Vector3.ZERO, 10.0)
	var checks := {
		"t_joint_is_one": _count([left, _rect(Vector3(10.0, 0.0, 0.0), 10.0, 5.0), _rect(Vector3(10.0, 0.0, 5.0), 10.0, 5.0)]) == 1,
		"gap_1cm_flat_is_one": _count([left, _square(Vector3(10.01, 0.0, 0.0), 10.0)]) == 1,
		"gap_1cm_height_is_one": _count([left, _square(Vector3(10.0, 0.01, 0.0), 10.0)]) == 1,
		"gap_1m_flat_is_two": _count([left, _square(Vector3(11.0, 0.0, 0.0), 10.0)]) == 2,
		"gap_1m_height_is_two": _count([left, _square(Vector3(10.0, 1.0, 0.0), 10.0)]) == 2,
		"touching_corner_is_two": _count([left, _square(Vector3(10.0, 0.0, 10.0), 10.0)]) == 2,
		"same_ids_twice": _ids([left, _rect(Vector3(10.0, 0.0, 0.0), 10.0, 5.0), _rect(Vector3(10.0, 0.0, 5.0), 10.0, 5.0)]) == _ids([left, _rect(Vector3(10.0, 0.0, 0.0), 10.0, 5.0), _rect(Vector3(10.0, 0.0, 5.0), 10.0, 5.0)]),
	}
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	print("NAV REGIONS joins ok=%s" % ok)
	return {"nav_regions": {"ok": ok, "checks": checks}}


func _count(rects: Array) -> int:
	return _regions(rects).component_count


func _ids(rects: Array) -> PackedInt32Array:
	var regions := _regions(rects)
	var ids := PackedInt32Array()
	for p in regions.polygon_count:
		ids.append(regions.component_at(_center(rects[p]), 0.1))
	return ids


## A rectangle is [corner, width_x, depth_z].
func _regions(rects: Array) -> NavRegions:
	var navmesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	for rect in rects:
		var at: Vector3 = rect[0]
		var base := vertices.size()
		## Four corners, each polygon with its own copies: NavRegions has to merge the ones in the same place.
		vertices.append(at)
		vertices.append(at + Vector3(0.0, 0.0, rect[2]))
		vertices.append(at + Vector3(rect[1], 0.0, rect[2]))
		vertices.append(at + Vector3(rect[1], 0.0, 0.0))
		navmesh.add_polygon(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	navmesh.set_vertices(vertices)
	var regions := NavRegions.new()
	regions.build(navmesh)
	return regions


static func _center(rect: Array) -> Vector3:
	return rect[0] + Vector3(rect[1] * 0.5, 0.0, rect[2] * 0.5)


static func _rect(corner: Vector3, width: float, depth: float) -> Array:
	return [corner, width, depth]


static func _square(corner: Vector3, side: float) -> Array:
	return [corner, side, side]
