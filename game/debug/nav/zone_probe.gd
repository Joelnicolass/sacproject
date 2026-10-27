extends Node

## Z0 probe (disposable): navmesh baked by fixed zones (160 m, 8 m border) on a solid flat 2560 m map, joined into one navmesh.
## Prints `ZONE_PROBE ...` lines. Run: godot --headless --path . res://debug/nav/zone_probe.tscn
## Not: productive code. Measures bake cost, concurrency safety, seam exactness, path quality and the hole re-bake.

const SIZE := 2560.0
const ZONE := 160.0
const ZONES := 16
const BORDER := 8.0
const GROUND_Y := 10.0
const GRID := 256
const QUANT := 0.05
const HOLE := Rect2(300.0, 300.0, 40.0, 40.0)
const VOID_ZONE := Rect2(2240.0, 2240.0, 160.0, 160.0)
const NO_RECT := Rect2()
## Tall boxes scattered (seeded) over the map, out of the test lines, so the navmesh has real polygons and the zone lines cut through them.
const PILLARS := 3000
const LINES := [[Vector2(20, 80), Vector2(500, 80)], [Vector2(20, 20), Vector2(500, 420)], [Vector2(20, 40), Vector2(2500, 1900)],
	[Vector2(240, 320), Vector2(400, 320)]]

var _settings: NavBakeSettings
var _params := NavigationPathQueryParameters3D.new()
var _result := NavigationPathQueryResult3D.new()
var _results: Array = []
var _max_dt := 0.0
var _tag := ""
var _pillars := 0
var _geometry_shared: NavigationMeshSourceGeometryData3D


func _ready() -> void:
	_run()


func _process(delta: float) -> void:
	_max_dt = maxf(_max_dt, delta)


func _say(text: String) -> void:
	print("ZONE_PROBE [", _tag, "] ", text)


func _run() -> void:
	_settings = load("res://data/nav/nav_bake.tres") as NavBakeSettings
	if "sync" in OS.get_cmdline_user_args():
		await _sync_study()
		get_tree().quit()
		return
	for scenario in [["flat", 0], ["pillars", PILLARS]]:
		_tag = scenario[0]
		_pillars = scenario[1]
		await _scenario()
	get_tree().quit()


func _scenario() -> void:
	_say("settings cell=%s height=%s radius=%s agent_h=%s climb=%s slope=%s min_region=%s merge_region=%s" % [_settings.cell_size,
		_settings.cell_height, _settings.agent_radius, _settings.agent_height, _settings.agent_max_climb, _settings.agent_max_slope,
		_settings.region_min_size, _settings.region_merge_size])
	## ---- 1. parse + per-zone bakes (solid map)
	var geometry := _parse([NO_RECT])
	_geometry_shared = geometry
	var one := _bake_zone(geometry, 8, 8)
	_say("sanity zone(8,8) polygons=%d vertices=%d" % [one.get_polygon_count(), one.get_vertices().size()])
	if one.get_polygon_count() == 0:
		_say("FATAL: empty bake, check winding")
		return
	var times: Array = []
	var solid: Array = []
	var total_start := Time.get_ticks_usec()
	for zid in ZONES * ZONES:
		var t := Time.get_ticks_usec()
		solid.append(_bake_zone(geometry, zid % ZONES, zid / ZONES))
		times.append(float(Time.get_ticks_usec() - t) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_start) / 1000.0
	times.sort()
	_say("bake_all_serial total_ms=%.0f zones=%d per_zone_ms min=%.1f median=%.1f max=%.1f" % [total_ms, times.size(), times[0],
		times[times.size() / 2], times[times.size() - 1]])
	var t1 := Time.get_ticks_usec()
	_bake_zone(geometry, 0, 0)
	_say("bake_1_zone_ms=%.1f" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	var t4 := Time.get_ticks_usec()
	for zid in [0, 1, ZONES, ZONES + 1]:
		_bake_zone(geometry, zid % ZONES, zid / ZONES)
	_say("bake_4_zones_corner_serial_ms=%.1f" % (float(Time.get_ticks_usec() - t4) / 1000.0))
	## ---- 2. concurrency
	_concurrency(geometry, solid)
	## ---- 3. join + components + seams
	var merged := _report_join("solid", solid)
	await _paths("solid", merged)
	## Control: the same corner of the map (640 m) baked as ONE tile, no zones: the path ratios to compare with.
	var control := NavigationMesh.new()
	_settings.apply_to(control)
	control.border_size = BORDER
	control.filter_baking_aabb = AABB(Vector3(-BORDER, GROUND_Y - 15.0, -BORDER), Vector3(4.0 * ZONE + 2.0 * BORDER, 50.0, 4.0 * ZONE + 2.0 * BORDER))
	var tc := Time.get_ticks_usec()
	NavigationServer3D.bake_from_source_geometry_data(control, geometry)
	_say("control single_bake_640m ms=%.0f polygons=%d" % [float(Time.get_ticks_usec() - tc) / 1000.0, control.get_polygon_count()])
	var control_index := NavRegions.new()
	control_index.build(control)
	_say("control components=%d %s" % [control_index.component_count, _ground_components(control, control_index)])
	await _paths("control", control, true)
	var corner: Array = []
	for zz in 4:
		for zx in 4:
			corner.append(solid[zz * ZONES + zx])
	var corner_mesh := _merge(corner)
	var corner_index := NavRegions.new()
	corner_index.build(corner_mesh)
	_say("zoned_640m_same_area polygons=%d (control %d) components=%d %s" % [corner_mesh.get_polygon_count(), control.get_polygon_count(),
		corner_index.component_count, _ground_components(corner_mesh, corner_index)])
	if _pillars > 0:
		var full := NavigationMesh.new()
		_settings.apply_to(full)
		full.cell_size = 1.0
		var tf := Time.get_ticks_usec()
		NavigationServer3D.bake_from_source_geometry_data(full, geometry)
		_say("control_full single_bake_2560m_cell1 ms=%.0f polygons=%d" % [float(Time.get_ticks_usec() - tf) / 1000.0, full.get_polygon_count()])
		var full_index := NavRegions.new()
		full_index.build(full)
		_say("control_full components=%d %s" % [full_index.component_count, _ground_components(full, full_index)])
		await _paths("control_full", full, false, ["horizontal_3_borders", "diagonal_5_borders", "long_cross_map"])
	## ---- 5. hole: re-bake all vs re-bake only 4 zones
	var hole_geometry := _parse([HOLE])
	var hole_all: Array = []
	var ta := Time.get_ticks_usec()
	for zid in ZONES * ZONES:
		hole_all.append(_bake_zone(hole_geometry, zid % ZONES, zid / ZONES))
	_say("hole bake_all_serial_ms=%.0f" % (float(Time.get_ticks_usec() - ta) / 1000.0))
	var merged_hole_all := _report_join("hole_all", hole_all)
	await _paths("hole_all", merged_hole_all)
	var partial: Array = solid.duplicate()
	var tp := Time.get_ticks_usec()
	for zone in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		partial[zone.y * ZONES + zone.x] = _bake_zone(hole_geometry, zone.x, zone.y)
	var rebake_ms := float(Time.get_ticks_usec() - tp) / 1000.0
	var tm := Time.get_ticks_usec()
	var merged_partial := _merge(partial)
	var merge_ms := float(Time.get_ticks_usec() - tm) / 1000.0
	_say("hole partial rebake4_ms=%.1f merge_ms=%.1f" % [rebake_ms, merge_ms])
	var ha := _hash(merged_hole_all)
	var hp := _hash(merged_partial)
	_say("hole partial_vs_all same_hash=%s all=%s partial=%s polys_all=%d polys_partial=%d verts_all=%d verts_partial=%d" % [ha == hp, ha,
		hp, merged_hole_all.get_polygon_count(), merged_partial.get_polygon_count(), merged_hole_all.get_vertices().size(),
		merged_partial.get_vertices().size()])
	var regions_partial := NavRegions.new()
	regions_partial.build(merged_partial)
	_say("hole partial components=%d" % regions_partial.component_count)
	await _paths("hole_partial", merged_partial)
	## ---- 6. empty zone
	_empty(geometry)


## Builds the map as one StaticBody3D of 256x256 cells (two triangles each) minus the cells whose center is in `skips`, in the
## group nav_source, and parses it once like the game does.
func _parse(skips: Array) -> NavigationMeshSourceGeometryData3D:
	var step := SIZE / GRID
	var faces := PackedVector3Array()
	for j in GRID:
		for i in GRID:
			var center := Vector2((i + 0.5) * step, (j + 0.5) * step)
			var skip := false
			for rect: Rect2 in skips:
				if rect.has_point(center):
					skip = true
			if skip:
				continue
			var x0 := i * step
			var z0 := j * step
			var x1 := x0 + step
			var z1 := z0 + step
			faces.append_array(PackedVector3Array([Vector3(x0, GROUND_Y, z0), Vector3(x1, GROUND_Y, z0), Vector3(x0, GROUND_Y, z1),
				Vector3(x1, GROUND_Y, z0), Vector3(x1, GROUND_Y, z1), Vector3(x0, GROUND_Y, z1)]))
	var body := StaticBody3D.new()
	body.add_to_group(NavFingerprint.GROUP)
	_add_pillars(body, skips)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var node := CollisionShape3D.new()
	node.shape = shape
	body.add_child(node)
	var holder := Node3D.new()
	holder.add_child(body)
	add_child(holder)
	var navmesh := NavigationMesh.new()
	_settings.apply_to(navmesh)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var started := Time.get_ticks_usec()
	NavigationServer3D.parse_source_geometry_data(navmesh, geometry, holder)
	_say("parse faces=%d parse_ms=%.1f has_data=%s" % [faces.size() / 3, float(Time.get_ticks_usec() - started) / 1000.0, geometry.has_data()])
	holder.free()
	return geometry


func _add_pillars(body: StaticBody3D, skips: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in _pillars:
		var at := Vector2(rng.randf_range(4.0, SIZE - 4.0), rng.randf_range(4.0, SIZE - 4.0))
		var size := Vector3(rng.randf_range(2.0, 7.0), 8.0, rng.randf_range(2.0, 7.0))
		var clear := true
		for line: Array in LINES:
			var closest := Geometry2D.get_closest_point_to_segment(at, line[0], line[1])
			if closest.distance_to(at) < 10.0:
				clear = false
		for rect: Rect2 in skips:
			if rect.grow(6.0).has_point(at):
				clear = false
		if not clear:
			continue
		var node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		node.shape = box
		node.position = Vector3(at.x, GROUND_Y + 4.0, at.y)
		body.add_child(node)


func _bake_zone(geometry: NavigationMeshSourceGeometryData3D, zx: int, zz: int) -> NavigationMesh:
	var navmesh := NavigationMesh.new()
	_settings.apply_to(navmesh)
	navmesh.border_size = BORDER
	navmesh.filter_baking_aabb = AABB(Vector3(zx * ZONE - BORDER, GROUND_Y - 15.0, zz * ZONE - BORDER),
		Vector3(ZONE + 2.0 * BORDER, 50.0, ZONE + 2.0 * BORDER))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	return navmesh


func _bake_index(index: int) -> void:
	_results[index] = _bake_zone(_geometry_shared, index % ZONES, index / ZONES)


func _concurrency(geometry: NavigationMeshSourceGeometryData3D, serial: Array) -> void:
	_geometry_shared = geometry
	var serial_hash := _hash(_merge(serial))
	_results = []
	_results.resize(ZONES * ZONES)
	var t := Time.get_ticks_usec()
	var group := WorkerThreadPool.add_group_task(_bake_index, ZONES * ZONES, -1, true, "zone_probe")
	WorkerThreadPool.wait_for_group_task_completion(group)
	var group_ms := float(Time.get_ticks_usec() - t) / 1000.0
	var empty := 0
	for r in _results:
		if r == null or r.get_polygon_count() == 0:
			empty += 1
	_say("concurrent group_task_256 ms=%.0f threads=%d empty=%d same_hash_as_serial=%s" % [group_ms,
		OS.get_processor_count(), empty, _hash(_merge(_results)) == serial_hash])
	_results = []
	_results.resize(ZONES * ZONES)
	t = Time.get_ticks_usec()
	var a := WorkerThreadPool.add_task(_bake_two.bind(0, 128), true, "zone_probe_a")
	var b := WorkerThreadPool.add_task(_bake_two.bind(128, 256), true, "zone_probe_b")
	WorkerThreadPool.wait_for_task_completion(a)
	WorkerThreadPool.wait_for_task_completion(b)
	var two_ms := float(Time.get_ticks_usec() - t) / 1000.0
	_say("concurrent two_tasks_128_each ms=%.0f same_hash_as_serial=%s" % [two_ms, _hash(_merge(_results)) == serial_hash])
	_results = []
	_results.resize(ZONES * ZONES)
	t = Time.get_ticks_usec()
	group = WorkerThreadPool.add_group_task(_bake_index, 4, -1, true, "zone_probe_4")
	WorkerThreadPool.wait_for_group_task_completion(group)
	_say("concurrent group_task_4 ms=%.1f" % (float(Time.get_ticks_usec() - t) / 1000.0))
	_results = []


func _bake_two(from: int, to: int) -> void:
	for index in range(from, to):
		_bake_index(index)


## Joins the zone navmeshes (in zone order) into one: vertices rounded to QUANT and shared by position.
func _merge(meshes: Array) -> NavigationMesh:
	var out := NavigationMesh.new()
	_settings.apply_to(out)
	var vertices := PackedVector3Array()
	var by_key := {}
	var polygons: Array[PackedInt32Array] = []
	for navmesh: NavigationMesh in meshes:
		var source := navmesh.get_vertices()
		var map := PackedInt32Array()
		map.resize(source.size())
		for i in source.size():
			var v := source[i]
			var key := Vector3i(roundi(v.x / QUANT), roundi(v.y / QUANT), roundi(v.z / QUANT))
			if not by_key.has(key):
				by_key[key] = vertices.size()
				vertices.append(Vector3(key) * QUANT)
			map[i] = by_key[key]
		for p in navmesh.get_polygon_count():
			var polygon := PackedInt32Array()
			for index in navmesh.get_polygon(p):
				var mapped := map[index]
				if polygon.is_empty() or polygon[polygon.size() - 1] != mapped:
					polygon.append(mapped)
			if polygon.size() > 1 and polygon[0] == polygon[polygon.size() - 1]:
				polygon.remove_at(polygon.size() - 1)
			if polygon.size() >= 3:
				polygons.append(polygon)
	out.set_vertices(vertices)
	for polygon in polygons:
		out.add_polygon(polygon)
	return out


## Components that hold at least one polygon at ground level (pillar tops are islands on top): 1 means the land is one piece.
func _ground_components(navmesh: NavigationMesh, index: NavRegions) -> String:
	var vertices := navmesh.get_vertices()
	var ids := {}
	for p in navmesh.get_polygon_count():
		var polygon := navmesh.get_polygon(p)
		var sum := Vector3.ZERO
		for i in polygon:
			sum += vertices[i]
		var c := sum / float(polygon.size())
		if c.y > GROUND_Y + 2.0:
			continue
		ids[index.component_at(c, 0.5)] = true
	var sizes: Array = []
	for id in ids:
		sizes.append(index.sizes[id])
	sizes.sort()
	sizes.reverse()
	return "ground_components=%d sizes=%s" % [ids.size(), sizes.slice(0, 6)]


func _hash(navmesh: NavigationMesh) -> String:
	var bytes := navmesh.get_vertices().to_byte_array()
	var flat := PackedInt32Array()
	for p in navmesh.get_polygon_count():
		flat.append_array(navmesh.get_polygon(p))
		flat.append(-1)
	bytes.append_array(flat.to_byte_array())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().substr(0, 16)


func _report_join(label: String, meshes: Array) -> NavigationMesh:
	var t := Time.get_ticks_usec()
	var merged := _merge(meshes)
	var merge_ms := float(Time.get_ticks_usec() - t) / 1000.0
	var index := NavRegions.new()
	t = Time.get_ticks_usec()
	index.build(merged)
	var build_ms := float(Time.get_ticks_usec() - t) / 1000.0
	var sizes: Array = []
	for s in index.sizes:
		sizes.append(s)
	sizes.sort()
	sizes.reverse()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in merged.get_vertices():
		lo = lo.min(v)
		hi = hi.max(v)
	_say("%s %s" % [label, _ground_components(merged, index)])
	_say("%s bounds %s .. %s" % [label, lo, hi])
	_say("%s join merge_ms=%.0f polygons=%d vertices=%d components=%d regions_build_ms=%.0f biggest=%s hash=%s" % [label, merge_ms,
		merged.get_polygon_count(), merged.get_vertices().size(), index.component_count, build_ms, sizes.slice(0, 5), _hash(merged)])
	var seams := _seams(merged, index)
	_say("%s seams ground_unshared_on_zone_lines=%d t_junction_edges=%d shifted_edges=%d orphan_edges=%d (of them in the main component: orphan=%d t=%d shifted=%d) (island/pillar-top edges on zone lines, apart: %d)" % [
		label, seams.unshared, seams.t_junction, seams.shifted, seams.orphan, seams.orphan_in_main, seams.t_in_main, seams.shifted_in_main, seams.island_edges])
	var raw := _raw_boundary(meshes)
	_say("%s raw_ground_boundary_vertices=%d unmatched_at_1cm=%d" % [label, raw.total, raw.unmatched])
	return merged


## Edges of the joined mesh used by one polygon only that lie on an inner zone line, and how the other side covers them.
func _seams(navmesh: NavigationMesh, index: NavRegions) -> Dictionary:
	var vertices := navmesh.get_vertices()
	var uses := {}
	for p in navmesh.get_polygon_count():
		var polygon := navmesh.get_polygon(p)
		for k in polygon.size():
			var a := polygon[k]
			var b := polygon[(k + 1) % polygon.size()]
			var key := (mini(a, b) << 32) | maxi(a, b)
			uses[key] = int(uses.get(key, 0)) + 1
	var lines := {}
	var mids := {}
	var islands := 0
	var main_id := 0
	for c in index.component_count:
		if index.sizes[c] > index.sizes[main_id]:
			main_id = c
	for key in uses:
		if uses[key] != 1:
			continue
		var va := vertices[key >> 32]
		var vb := vertices[key & 0xffffffff]
		## The flat top of a pillar (an island, not land) is not a seam of the ground: counted apart.
		if va.y > GROUND_Y + 2.0 and vb.y > GROUND_Y + 2.0:
			if absf(va.x - vb.x) < 0.001 and absf(va.x / ZONE - roundf(va.x / ZONE)) < 0.0001 or absf(va.z - vb.z) < 0.001 and absf(va.z / ZONE - roundf(va.z / ZONE)) < 0.0001:
				islands += 1
			continue
		for axis in 2:
			var ca := va.x if axis == 0 else va.z
			var cb := vb.x if axis == 0 else vb.z
			var k := roundi(ca / ZONE)
			if absf(ca - cb) < 0.001 and k >= 1 and k < ZONES and absf(ca - k * ZONE) < 0.001:
				var along_a := va.z if axis == 0 else va.x
				var along_b := vb.z if axis == 0 else vb.x
				var id := Vector2i(axis, k)
				if not lines.has(id):
					lines[id] = []
					mids[id] = []
				lines[id].append(Vector2(minf(along_a, along_b), maxf(along_a, along_b)))
				mids[id].append((va + vb) * 0.5)
	var out := {"unshared": 0, "t_junction": 0, "shifted": 0, "orphan": 0, "island_edges": islands, "orphan_in_main": 0, "t_in_main": 0, "shifted_in_main": 0}
	for id in lines:
		var list: Array = lines[id]
		out.unshared += list.size()
		for i in list.size():
			var partners := 0
			var identical := false
			for j in list.size():
				if i == j:
					continue
				var overlap := minf(list[i].y, list[j].y) - maxf(list[i].x, list[j].x)
				if overlap > 0.001:
					partners += 1
					if absf(list[i].x - list[j].x) < 0.001 and absf(list[i].y - list[j].y) < 0.001:
						identical = true
			var in_main := index.component_at(mids[id][i], 0.5) == main_id
			if partners == 0:
				out.orphan += 1
				if in_main:
					out.orphan_in_main += 1
			elif partners >= 2:
				out.t_junction += 1
				if in_main:
					out.t_in_main += 1
			elif not identical:
				out.shifted += 1
				if in_main:
					out.shifted_in_main += 1
	return out


## Vertices a zone has on the line it shares with its +x / +z neighbour, and how many have no vertex of the neighbour within 1 cm.
func _raw_boundary(meshes: Array) -> Dictionary:
	var total := 0
	var unmatched := 0
	for zz in ZONES:
		for zx in ZONES:
			for axis in 2:
				if (axis == 0 and zx == ZONES - 1) or (axis == 1 and zz == ZONES - 1):
					continue
				var line := float((zx + 1) * ZONE) if axis == 0 else float((zz + 1) * ZONE)
				var a := _on_line(meshes[zz * ZONES + zx], axis, line)
				var b := _on_line(meshes[zz * ZONES + zx + (1 if axis == 0 else ZONES)], axis, line)
				total += a.size() + b.size()
				unmatched += _missing(a, b) + _missing(b, a)
	return {"total": total, "unmatched": unmatched}


func _on_line(navmesh: NavigationMesh, axis: int, line: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v in navmesh.get_vertices():
		if v.y <= GROUND_Y + 2.0 and absf((v.x if axis == 0 else v.z) - line) < 0.001:
			out.append(v)
	return out


func _missing(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var count := 0
	for v in a:
		var found := false
		for w in b:
			if v.distance_to(w) <= 0.01:
				found = true
				break
		if not found:
			count += 1
	return count


## Paths across zone borders on one region holding `navmesh`.
func _paths(label: String, navmesh: NavigationMesh, short := false, only: Array = []) -> void:
	var region := NavigationRegion3D.new()
	region.navigation_mesh = navmesh
	add_child(region)
	var map := region.get_viewport().world_3d.navigation_map
	NavigationServer3D.map_set_cell_size(map, navmesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, navmesh.cell_height)
	var frames: Array = []
	for _i in 3:
		var tf := Time.get_ticks_usec()
		await get_tree().physics_frame
		frames.append("%.0f" % (float(Time.get_ticks_usec() - tf) / 1000.0))
	_say("%s region_first_sync_frames_ms=%s merge_cell_scale=%s" % [label, frames, NavigationServer3D.map_get_merge_rasterizer_cell_scale(map)])
	var cases := {
		"horizontal_3_borders": [Vector3(20, GROUND_Y, 80), Vector3(500, GROUND_Y, 80)],
		"diagonal_5_borders": [Vector3(20, GROUND_Y, 20), Vector3(500, GROUND_Y, 420)],
		"long_cross_map": [Vector3(20, GROUND_Y, 40), Vector3(2500, GROUND_Y, 1900)],
		"through_hole": [Vector3(240, GROUND_Y, 320), Vector3(400, GROUND_Y, 320)],
	}
	for case_name in cases:
		if short and case_name in ["long_cross_map", "through_hole"]:
			continue
		if not only.is_empty() and not case_name in only:
			continue
		var from: Vector3 = cases[case_name][0]
		var to: Vector3 = cases[case_name][1]
		var q := Time.get_ticks_usec()
		var path := NavMeshBackend.query_path(map, from, to, _params, _result)
		var query_us := Time.get_ticks_usec() - q
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		var straight := from.distance_to(to)
		_say("%s path %s points=%d length=%.2f straight=%.2f ratio=%.4f query_us=%d" % [label, case_name, path.size(), length,
			straight, length / straight if straight > 0.0 else 0.0, query_us])
	if not short:
		var swap_frames: Array = []
		region.navigation_mesh = navmesh.duplicate()
		for _i in 3:
			var tf := Time.get_ticks_usec()
			await get_tree().physics_frame
			swap_frames.append("%.0f" % (float(Time.get_ticks_usec() - tf) / 1000.0))
		_say("%s region_swap_sync_frames_ms=%s" % [label, swap_frames])
	region.free()
	await get_tree().physics_frame


func _empty(geometry: NavigationMeshSourceGeometryData3D) -> void:
	printerr("ZONE_PROBE empty_begin zone_with_no_triangles")
	var void_geometry := _parse([VOID_ZONE])
	var navmesh := _bake_zone(void_geometry, 14, 14)
	printerr("ZONE_PROBE empty_end zone_with_no_triangles polygons=%d vertices=%d" % [navmesh.get_polygon_count(), navmesh.get_vertices().size()])
	printerr("ZONE_PROBE empty_begin geometry_without_any_data")
	var nothing := NavigationMeshSourceGeometryData3D.new()
	var navmesh2 := _bake_zone(nothing, 3, 3)
	printerr("ZONE_PROBE empty_end geometry_without_any_data polygons=%d" % navmesh2.get_polygon_count())
	printerr("ZONE_PROBE empty_begin zone_outside_geometry_bounds")
	var navmesh3 := _bake_zone(geometry, 40, 40)
	printerr("ZONE_PROBE empty_end zone_outside_geometry_bounds polygons=%d" % navmesh3.get_polygon_count())


## ---- Sync study (run with `-- sync`): what the server's map sync costs on a swap, one region vs one region per zone.

const HOLE_ZONES := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]


func _bake_all(geometry: NavigationMeshSourceGeometryData3D) -> Array:
	_geometry_shared = geometry
	_results = []
	_results.resize(ZONES * ZONES)
	WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(_bake_index, ZONES * ZONES, -1, true, "bake_all"))
	var out := _results
	_results = []
	return out


func _sync_study() -> void:
	_tag = "sync"
	_pillars = PILLARS
	var geometry := _parse([NO_RECT])
	var hole_geometry := _parse([HOLE])
	var solid := _bake_all(geometry)
	var partial := solid.duplicate()
	for zone in HOLE_ZONES:
		partial[zone.y * ZONES + zone.x] = _bake_zone(hole_geometry, zone.x, zone.y)
	var merged := _merge(solid)
	var merged_hole := _merge(partial)
	var map := get_viewport().world_3d.navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.5)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	_say("settings project map_async=%s region_async=%s | server map_async=%s default_iteration=%d" % [
		ProjectSettings.get_setting("navigation/world/map_use_async_iterations", "unset"),
		ProjectSettings.get_setting("navigation/world/region_use_async_iterations", "unset"),
		NavigationServer3D.map_get_use_async_iterations(map), NavigationServer3D.map_get_iteration_id(map)])
	## (a) one region, merged mesh
	var region := NavigationRegion3D.new()
	add_child(region)
	_say("(a) one region, mesh polygons=%d" % merged.get_polygon_count())
	await _experiment("a first assign", map, func() -> void: region.navigation_mesh = merged, 8)
	await _experiment("a swap to hole mesh (sync default)", map, func() -> void: region.navigation_mesh = merged_hole, 8, true)
	ProjectSettings.set_setting("navigation/world/map_use_async_iterations", true)
	await _experiment("a swap, ProjectSettings changed at runtime", map, func() -> void: region.navigation_mesh = merged.duplicate(), 8, true)
	ProjectSettings.set_setting("navigation/world/map_use_async_iterations", false)
	region.free()
	await _settle()
	## (b) one region per zone
	var holder := Node3D.new()
	add_child(holder)
	var regions: Array[NavigationRegion3D] = []
	var t := Time.get_ticks_usec()
	for zid in ZONES * ZONES:
		var r := NavigationRegion3D.new()
		r.navigation_mesh = solid[zid]
		holder.add_child(r)
		regions.append(r)
	_say("(b) 256 regions added in %.0f ms" % (float(Time.get_ticks_usec() - t) / 1000.0))
	await _experiment("b first sync 256 regions", map, func() -> void: pass, 8)
	await _settle()
	_say("(b) union of the 256 zone meshes: %s" % _components_of(merged))
	await _query_cases(map, "b edge_connections=on", ["horizontal_3_borders", "diagonal_5_borders", "long_cross_map", "through_hole"])
	await _experiment("b swap 4 regions to hole meshes", map, func() -> void:
		for zone in HOLE_ZONES:
			regions[zone.y * ZONES + zone.x].navigation_mesh = partial[zone.y * ZONES + zone.x], 8, true)
	await _settle()
	await _query_cases(map, "b edge_connections=on after swap", ["horizontal_3_borders", "diagonal_5_borders", "long_cross_map", "through_hole"])
	for r in regions:
		r.use_edge_connections = false
	await _experiment("b edge_connections turned off on all", map, func() -> void: pass, 6)
	await _settle()
	await _query_cases(map, "b edge_connections=off", ["horizontal_3_borders", "diagonal_5_borders", "long_cross_map", "through_hole"])
	holder.free()
	await _settle()
	## (c) the real High Noon navmesh
	var real := load("res://scenes/map/maps/high_noon/nav.res") as NavigationMesh
	NavigationServer3D.map_set_cell_size(map, real.cell_size)
	NavigationServer3D.map_set_cell_height(map, real.cell_height)
	var one := NavigationRegion3D.new()
	add_child(one)
	_say("(c) high_noon nav.res polygons=%d cell=%s" % [real.get_polygon_count(), real.cell_size])
	await _experiment("c first assign", map, func() -> void: one.navigation_mesh = real, 6)
	await _experiment("c reassign a copy (same content)", map, func() -> void: one.navigation_mesh = real.duplicate(), 6)
	await _experiment("c reassign a copy again", map, func() -> void: one.navigation_mesh = real.duplicate(), 6)
	one.free()
	await _settle()
	## (d) why is the 30 k polygon map slow? edge connections of the region off (a single region needs none).
	var plain := NavigationRegion3D.new()
	plain.use_edge_connections = false
	add_child(plain)
	NavigationServer3D.map_set_cell_size(map, 0.5)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	await _experiment("d pillars mesh, use_edge_connections=false: first assign", map, func() -> void: plain.navigation_mesh = merged, 8)
	await _experiment("d swap to hole mesh, edge_connections=false", map, func() -> void: plain.navigation_mesh = merged_hole.duplicate(), 8, true)
	plain.free()
	await _settle()
	## (a2) async iterations through the server setters, last because it leaves the map in another mode.
	NavigationServer3D.map_set_cell_size(map, 0.5)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	var again := NavigationRegion3D.new()
	again.navigation_mesh = merged
	add_child(again)
	await _settle()
	await _settle()
	NavigationServer3D.map_set_use_async_iterations(map, true)
	NavigationServer3D.region_set_use_async_iterations(again.get_rid(), true)
	_say("(a2) server map_async=%s region_async=%s" % [NavigationServer3D.map_get_use_async_iterations(map),
		NavigationServer3D.region_get_use_async_iterations(again.get_rid())])
	await _experiment("a2 swap to hole mesh, async via setters", map, func() -> void: again.navigation_mesh = merged_hole.duplicate(), 8, true)
	await _experiment("a2 swap back, async via setters", map, func() -> void: again.navigation_mesh = merged.duplicate(), 8)
	var back := NavMeshBackend.query_path(map, Vector3(240, GROUND_Y, 320), Vector3(400, GROUND_Y, 320), _params, _result)
	_say("a2 after swap back and 8 frames: path points=%d (4 = through the middle)" % back.size())


func _settle() -> void:
	for _i in 4:
		await get_tree().physics_frame


## Runs `apply`, then waits physics frames printing the wall ms of each, the map iteration id, the largest process delta and, when
## `watch_hole`, the frame (and ms) at which a path through the hole already goes around it (longer than the 160 m straight line).
func _experiment(label: String, map: RID, apply: Callable, frames: int, watch_hole := false) -> void:
	var id_before := NavigationServer3D.map_get_iteration_id(map)
	var hole_from := Vector3(240, GROUND_Y, 320)
	var hole_to := Vector3(400, GROUND_Y, 320)
	_max_dt = 0.0
	var t0 := Time.get_ticks_usec()
	apply.call()
	var apply_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var times: Array = []
	var ids: Array = []
	var avoided_at := -1
	var avoided_ms := 0.0
	var total := frames
	if watch_hole:
		total = maxi(frames, 240)
	for i in total:
		var tf := Time.get_ticks_usec()
		await get_tree().physics_frame
		if i < frames:
			times.append("%.0f" % (float(Time.get_ticks_usec() - tf) / 1000.0))
			ids.append(NavigationServer3D.map_get_iteration_id(map))
		if watch_hole and avoided_at < 0:
			var path := NavMeshBackend.query_path(map, hole_from, hole_to, _params, _result)
			var length := 0.0
			for k in range(1, path.size()):
				length += path[k - 1].distance_to(path[k])
			if length > 161.0:
				avoided_at = i + 1
				avoided_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		if i + 1 >= frames and (not watch_hole or avoided_at >= 0):
			break
	_say("%s: apply_ms=%.1f frame_ms=%s iteration_id %d -> %s max_process_delta_ms=%.0f%s" % [label, apply_ms, times, id_before, ids,
		_max_dt * 1000.0, (" hole_avoided_at_frame=%d (after %.0f ms)" % [avoided_at, avoided_ms]) if watch_hole else ""])


func _components_of(navmesh: NavigationMesh) -> String:
	var index := NavRegions.new()
	index.build(navmesh)
	return "components=%d polygons=%d" % [index.component_count, navmesh.get_polygon_count()]


func _query_cases(map: RID, label: String, names: Array) -> void:
	var cases := {
		"horizontal_3_borders": [Vector3(20, GROUND_Y, 80), Vector3(500, GROUND_Y, 80)],
		"diagonal_5_borders": [Vector3(20, GROUND_Y, 20), Vector3(500, GROUND_Y, 420)],
		"long_cross_map": [Vector3(20, GROUND_Y, 40), Vector3(2500, GROUND_Y, 1900)],
		"through_hole": [Vector3(240, GROUND_Y, 320), Vector3(400, GROUND_Y, 320)],
	}
	for case_name in names:
		var from: Vector3 = cases[case_name][0]
		var to: Vector3 = cases[case_name][1]
		var path := NavMeshBackend.query_path(map, from, to, _params, _result)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		var gap := -1.0
		if path.size() > 0:
			gap = Vector2(path[path.size() - 1].x - to.x, path[path.size() - 1].z - to.z).length()
		_say("%s path %s points=%d length=%.2f ratio=%.4f end_gap_to_goal=%.1f" % [label, case_name, path.size(), length,
			length / from.distance_to(to), gap])
	await get_tree().physics_frame
