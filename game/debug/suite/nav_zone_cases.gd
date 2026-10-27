extends RefCounted

## Plan 071 Z3 cases of rules_suite: the navmesh baked by zones (NavZones) and the list of changes (NavChanges). A solid plane of 256x256
## cells over the 2560 m map (the zone lines at every 160 m) in the nav source group, as the game parses it.
## - zones_seam: baked whole and stitched, the plane without boxes is one region, a path across 3 zone borders is at most 2 % longer than
##   the straight line, and the two sides of a border are the same region.
## - zones_local_equals_full: with a hole at the corner of 4 zones, re-baking only the zones it touches gives the same navmesh (same
##   hash of vertices and polygons) as baking all of them again.
## - zones_local_ms: re-baking and stitching 1 zone and 4 zones each take under a second (real clock).
## - zones_untouched: a change far from a zone does not list it, and the polygons of that zone are the same before and after.
## - nav_changes_idempotent: the same area added twice gives the same cover, nothing taken gives nothing, a new blocker is an area.
## The plane has a few boxes over the zone lines, so the lines cut real polygons. The bakes wait for nothing; the path check waits for
## the navigation map in real seconds (never in frames).

const SIZE := 2560.0
const GRID := 256
const GROUND_Y := 10.0
const HOLE := Rect2(300.0, 300.0, 40.0, 40.0)
const ONE_ZONE_RECT := Rect2(500.0, 500.0, 10.0, 10.0)
const FAR_RECT := Rect2(2300.0, 2300.0, 10.0, 10.0)
## The far zone of the untouched case (the zone of FAR_RECT without its border).
const FAR_ZONE := Rect2(2240.0, 2240.0, 160.0, 160.0)
## Boxes over the zone lines (center x, center z, size x, size z), none in the hole.
const BOXES := [[160.0, 100.0, 6.0, 4.0], [320.0, 600.0, 5.0, 5.0], [700.0, 480.0, 4.0, 6.0], [160.0, 480.0, 5.0, 5.0]]
const MS_LIMIT := 1000.0
const WAIT_S := 10.0

var _settings: NavBakeSettings
var _host: Node
var _notes := {}


func run(host: Node) -> Dictionary:  # a coroutine: it waits for the navigation map in real seconds
	_host = host
	_settings = load("res://data/nav/nav_bake.tres") as NavBakeSettings
	var out := {}
	out["zones_seam"] = await _seam()
	var parts := _local()
	out["zones_local_equals_full"] = parts.equal
	out["zones_local_ms"] = parts.ms
	out["zones_untouched"] = parts.untouched
	out["nav_changes_idempotent"] = _changes()
	print("NAV ZONES %s" % _notes)
	return out


## The solid plane (minus the cells whose center is in `hole`, empty for none) as parsed source geometry.
func _parse(hole: Rect2, boxes: bool) -> NavigationMeshSourceGeometryData3D:
	var step := SIZE / GRID
	var faces := PackedVector3Array()
	for j in GRID:
		for i in GRID:
			if hole.has_point(Vector2((i + 0.5) * step, (j + 0.5) * step)):
				continue
			var x0 := i * step
			var z0 := j * step
			var x1 := x0 + step
			var z1 := z0 + step
			faces.append_array(PackedVector3Array([Vector3(x0, GROUND_Y, z0), Vector3(x1, GROUND_Y, z0), Vector3(x0, GROUND_Y, z1),
				Vector3(x1, GROUND_Y, z0), Vector3(x1, GROUND_Y, z1), Vector3(x0, GROUND_Y, z1)]))
	var body := StaticBody3D.new()
	body.add_to_group(NavFingerprint.GROUP)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var ground := CollisionShape3D.new()
	ground.shape = shape
	body.add_child(ground)
	if boxes:
		for spec: Array in BOXES:
			var box := BoxShape3D.new()
			box.size = Vector3(spec[2], 8.0, spec[3])
			var node := CollisionShape3D.new()
			node.shape = box
			node.position = Vector3(spec[0], GROUND_Y + 4.0, spec[1])
			body.add_child(node)
	var holder := Node3D.new()
	holder.add_child(body)
	_host.add_child(holder)
	var navmesh := NavigationMesh.new()
	_settings.apply_to(navmesh)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, geometry, holder)
	holder.free()
	return geometry


func _seam() -> Dictionary:
	var zones := NavZones.new(_settings).bake_all(_parse(Rect2(), false))
	var mesh := zones.stitched()
	var regions := NavRegions.new()
	regions.build(mesh)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	region.use_edge_connections = false
	_host.add_child(region)
	var map := region.get_viewport().world_3d.navigation_map
	NavigationServer3D.map_set_cell_size(map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	var from := Vector3(20.0, GROUND_Y, 80.0)
	var to := Vector3(500.0, GROUND_Y, 80.0)
	var params := NavigationPathQueryParameters3D.new()
	var result := NavigationPathQueryResult3D.new()
	var path := PackedVector3Array()
	var started := Time.get_ticks_msec()
	while path.size() < 2 and Time.get_ticks_msec() - started < int(WAIT_S * 1000.0):
		await _host.get_tree().physics_frame
		path = NavMeshBackend.query_path(map, from, to, params, result)
	var length := 0.0
	for k in range(1, path.size()):
		length += path[k - 1].distance_to(path[k])
	var left := regions.component_at(Vector3(150.0, GROUND_Y, 80.0), 1.0)
	var right := regions.component_at(Vector3(170.0, GROUND_Y, 80.0), 1.0)
	var corner_a := regions.component_at(Vector3(150.0, GROUND_Y, 150.0), 1.0)
	var corner_b := regions.component_at(Vector3(170.0, GROUND_Y, 170.0), 1.0)
	region.free()
	var ratio := length / from.distance_to(to) if length > 0.0 else 0.0
	_notes["seam ratio / components"] = [snappedf(ratio, 0.0001), regions.component_count]
	return _verdict({
		"one_component": regions.component_count == 1,
		"path_found": path.size() >= 2,
		"path_at_most_1_02": ratio > 0.0 and ratio <= 1.02,
		"same_region_across_border": left >= 0 and left == right,
		"same_region_across_corner": corner_a >= 0 and corner_a == corner_b,
	})


## The three cases that share the baked zones: the base (with boxes), the whole re-bake with the hole and the local one.
func _local() -> Dictionary:
	var base := NavZones.new(_settings).bake_all(_parse(Rect2(), true))
	var hole_geometry := _parse(HOLE, true)
	var full := NavZones.new(_settings).bake_all(hole_geometry)
	var four := base.zones_touching(HOLE)
	var one := base.zones_touching(ONE_ZONE_RECT)
	var t1 := Time.get_ticks_usec()
	base.baked(hole_geometry, one).stitched()
	var one_ms := float(Time.get_ticks_usec() - t1) / 1000.0
	var t4 := Time.get_ticks_usec()
	var local_mesh := base.baked(hole_geometry, four).stitched()
	var four_ms := float(Time.get_ticks_usec() - t4) / 1000.0
	var full_mesh := full.stitched()
	var base_mesh := base.stitched()
	_notes["local ms 1 zone / 4 zones"] = [snappedf(one_ms, 0.1), snappedf(four_ms, 0.1)]
	_notes["zones touched 1 / 4"] = [one.size(), four.size()]
	var far_ids := base.zones_touching(FAR_RECT)
	var overlap := false
	for id in far_ids:
		if four.has(id):
			overlap = true
	var before := _cut_polygons(base_mesh, FAR_ZONE)
	var after := _cut_polygons(local_mesh, FAR_ZONE)
	return {
		"equal": _verdict({
			"touches_4_zones": four.size() == 4,
			"has_polygons": local_mesh.get_polygon_count() > 0,
			"same_hash": NavFingerprint.mesh_hash(local_mesh) == NavFingerprint.mesh_hash(full_mesh),
			"hole_changed_the_mesh": NavFingerprint.mesh_hash(local_mesh) != NavFingerprint.mesh_hash(base_mesh),
		}),
		"ms": _verdict({"one_zone_touches_1": one.size() == 1, "one_zone_under_1s": one_ms < MS_LIMIT, "four_zones_under_1s": four_ms < MS_LIMIT}),
		"untouched": _verdict({
			"far_zone_listed": far_ids.size() >= 1,
			"far_not_in_the_change": not overlap,
			"far_polygons_exist": before.size() > 0,
			"far_polygons_same": before == after,
		}),
	}


func _changes() -> Dictionary:
	var rect := Rect2(100.0, 100.0, 20.0, 20.0)
	var changes := NavChanges.new()
	changes.reset([])
	var nothing := changes.take([])
	changes.add_area(rect)
	changes.add_area(rect)
	var taken := changes.take([])
	## One area or two equal ones are both fine: what counts is that the cover is the rect and nothing more.
	var same_cover := taken.size() >= 1 and taken.size() <= 2
	for area in taken:
		if not area.is_equal_approx(rect):
			same_cover = false
	var again := changes.take([])
	var from_blocker := changes.take([[Vector2(500.0, 500.0), 3.0]])
	var covers_blocker := false
	for area in from_blocker:
		if area.has_point(Vector2(500.0, 500.0)):
			covers_blocker = true
	return _verdict({
		"nothing_without_changes": nothing.is_empty(),
		"area_twice_same_cover": same_cover,
		"take_empties_the_list": again.is_empty(),
		"new_blocker_is_an_area": covers_blocker,
	})


## The polygons of `mesh` whose center lies inside `rect`, as sorted text keys of their rounded corners, to compare two bakes.
static func _cut_polygons(mesh: NavigationMesh, rect: Rect2) -> PackedStringArray:
	var vertices := mesh.get_vertices()
	var keys := PackedStringArray()
	for p in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(p)
		var center := Vector3.ZERO
		var corners := PackedStringArray()
		for i in polygon:
			center += vertices[i]
			corners.append("%.2f,%.2f,%.2f" % [vertices[i].x, vertices[i].y, vertices[i].z])
		center /= float(polygon.size())
		if rect.has_point(Vector2(center.x, center.z)):
			corners.sort()
			keys.append(";".join(corners))
	keys.sort()
	return keys


static func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	return {"ok": ok, "checks": checks}
