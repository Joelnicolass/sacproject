extends RefCounted

## RFC-057 061k-3 cases of terrain_cases: Bore. The spiral and the rules of a hole (a vertex of the rim, one that is gone, one near a
## building), the walls and the falling piece of a hole, Bore end to end on the map of High Noon (the first hole 600 ticks after the
## zone is born, four cells without land, a body over it thrown and gone, a stand-in house never closer than 11 m, the vertices back
## one every 30 ticks in reverse, the ground whole at the end), a cut cast that leaves nothing, and a path that goes around a hole once
## the navmesh is baked again. It borrows the world of TerrainCases (`cases`): its bed, its makers of wizards, bodies and zones.

const CENTER := Vector2(1260.0, 1270.0)
## Ticks between the zone being born and the cutter starting (10 s).
const ARM_TICKS := 600
## The spiral of the cut case reaches this far (the spell's 50 m would take twice as long to run).
const TRY_RANGE_M := 30.0

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"bore_rules": _rules, "bore_walls": _walls, "bore_cut": _cut, "bore_cancel": _cancel, "bore_nav": _nav}


## The spiral, and when a vertex may be taken away.
func _rules() -> Dictionary:
	var checks := {}
	var spiral := BoreSpiral.new(CENTER, 50.0, 0.8)
	var first := spiral.advance()
	checks["spiral_starts_5m_ahead"] = first.distance_to(CENTER + Vector2(0.0, 5.0)) < 1e-4
	var ticks := 1
	var last := first
	var growing := true
	while not spiral.arrived and ticks < 5000:
		var next := spiral.advance()
		growing = growing and next.distance_to(CENTER) >= last.distance_to(CENTER) - 1e-4
		last = next
		ticks += 1
	checks["spiral_grows"] = growing
	checks["spiral_ends_at_50m"] = absf(last.distance_to(CENTER) - 50.0) < 1e-3
	checks["spiral_972_ticks_at_0_8m"] = ticks == 972
	checks["spiral_1080_ticks_at_0_72m"] = _ticks_of(BoreSpiral.new(CENTER, 50.0, 0.72)) == 1080
	var shape: Terrain = _c._shape
	var inside := _full_vertex(shape, 3)
	var spot := TerrainGrid.point_of(inside)
	var height := shape.height_at(spot.x, spot.y)
	checks["a_land_vertex_may_go"] = HoleRules.can_remove(shape, inside, PackedVector3Array())
	checks["rim_never"] = not HoleRules.can_remove(shape, Vector2i(0, 100), PackedVector3Array()) and not HoleRules.can_remove(shape, Vector2i(255, 100), PackedVector3Array()) \
			and not HoleRules.can_remove(shape, Vector2i(100, 0), PackedVector3Array()) and not HoleRules.can_remove(shape, Vector2i(100, 254 + 1), PackedVector3Array())
	checks["no_land_never"] = not HoleRules.can_remove(shape, Vector2i(1, 1), PackedVector3Array())
	var close := PackedVector3Array([Vector3(spot.x + 10.9, height, spot.y)])
	var far := PackedVector3Array([Vector3(spot.x + 11.1, height, spot.y)])
	var high := PackedVector3Array([Vector3(spot.x + 3.0, height + 60.0, spot.y)])
	checks["building_10_9m_blocks"] = not HoleRules.can_remove(shape, inside, close)
	checks["building_11_1m_does_not"] = HoleRules.can_remove(shape, inside, far)
	checks["building_60m_above_does_not"] = HoleRules.can_remove(shape, inside, high)
	var cut := shape.cut_hole(spot)
	checks["cut_hole_takes_the_vertex"] = cut.size() == 1 and Vector2(cut[0].x, cut[0].z) == spot and not is_nan(cut[0].y)
	checks["gone_never_again"] = not HoleRules.can_remove(shape, inside, PackedVector3Array()) and shape.cut_hole(spot).is_empty()
	checks["fill_hole_gives_it_back"] = shape.fill_hole(spot).size() == 1 and shape.fill_hole(spot).is_empty()
	checks["back_it_may_go"] = HoleRules.can_remove(shape, inside, PackedVector3Array())
	checks["vertex_near_rounds"] = TerrainGrid.vertex_near(Vector2(1264.9, 1275.0)) == Vector2i(126, 128) and TerrainGrid.vertex_near(Vector2(1265.1, 1274.9)) == Vector2i(127, 127)
	return _c._verdict("bore_rules", checks)


## The walls round a hole, the piece that falls, and the pit the shader leaves.
func _walls() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var index := shape.index
	var one := _full_vertex(shape, 3)
	var id := TerrainGrid.id_of(one)
	var edges := HoleWallRules.boundary(index, PackedInt32Array([id]))
	checks["one_vertex_six_walls"] = edges.size() == 6
	var built := HoleWallRules.arrays(index, PackedInt32Array([id]))
	checks["wall_arrays"] = built.size() == 5 and (built[0] as PackedVector3Array).size() == 24 and (built[3] as PackedInt32Array).size() == 36
	var drops := true
	var faces_the_hole := true
	var centre := Vector3(one.x * TerrainGrid.CELL_M, 0.0, one.y * TerrainGrid.CELL_M)
	for k in 6:
		var top: Vector3 = (built[0] as PackedVector3Array)[k * 4]
		var bottom: Vector3 = (built[0] as PackedVector3Array)[k * 4 + 3]
		drops = drops and absf(top.y - bottom.y - HoleWallRules.DEPTH_M) < 1e-4 and absf(top.x - bottom.x) < 1e-4
		var normal: Vector3 = (built[1] as PackedVector3Array)[k * 4]
		faces_the_hole = faces_the_hole and normal.dot(Vector3(centre.x - top.x, 0.0, centre.z - top.z)) > 0.0
	checks["walls_drop_50m"] = drops
	checks["walls_face_the_hole"] = faces_the_hole
	var pair := _full_vertex(shape, 3, true)
	var pair_id := TerrainGrid.id_of(pair)
	checks["two_neighbours_eight_walls"] = HoleWallRules.boundary(index, PackedInt32Array([pair_id, pair_id + 1])).size() == 8
	checks["no_hole_no_walls"] = HoleWallRules.arrays(index, PackedInt32Array()).is_empty()
	var chunk := FallingChunkRules.arrays(index, shape.field().texels, id)
	checks["chunk_six_triangles_and_six_skirts"] = chunk.size() == 13 and (chunk[0] as PackedVector3Array).size() == 6 * 3 + 6 * 4
	checks["chunk_off_the_rim_is_nothing"] = FallingChunkRules.arrays(index, shape.field().texels, 5).is_empty()
	return _c._verdict("bore_walls", checks)


## Bore from the click to the last vertex back.
func _cut() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var ground_spot := func(at: Vector2) -> Vector3: return Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	var wizard = _c._wizard(1, _c._far_wizard_spot(), "james", 8)
	var spell := GameData.spell("erob").duplicate() as SpellType
	spell.effect_range_m = TRY_RANGE_M
	var first_vertex := TerrainGrid.vertex_near(CENTER + Vector2(0.0, 5.0))
	var first_at: Vector3 = ground_spot.call(TerrainGrid.point_of(first_vertex))
	var body = _c._tough(first_at + Vector3(0.0, 0.1, 0.0), 3)
	var house_xz := CENTER + Vector2(0.0, -20.0)
	var house := Node3D.new()
	house.name = "StandInHouse"
	house.add_to_group(MapBuilding.GROUP)
	_c._root.add_child(house)
	house.global_position = ground_spot.call(house_xz)
	await _c._frames(10)
	var played := {"scene": 0, "dig": 0, "repair": 0}
	var hear := func(kind: StringName, fx: Resource, _at: Vector3) -> void:
		var fx_name := FxWire.label_of(fx)
		if kind == FxBus.KIND_SCENE and fx_name == "falling_chunk":
			played["scene"] += 1
		elif kind == FxBus.KIND_BURST and fx_name == "bore_hole":
			played["dig"] += 1
		elif kind == FxBus.KIND_BURST and fx_name == "bore_repair":
			played["repair"] += 1
	FxBus.played.connect(hear)
	var clock := [0]
	var zone: GroundZone = _c._zone("Bore", PackedVector3Array([ground_spot.call(CENTER)]), wizard, 0, ARM_TICKS)
	zone.spell = spell
	zone.release()
	var cutter := zone.get_node("Cutter") as HoleCutter
	var drill := zone.get_node("Drill") as BoreDrill
	var took := []
	var gave := []
	cutter.hole_cut.connect(func(at: Vector3) -> void: took.append([clock[0], TerrainGrid.vertex_id(at.x, at.z)]))
	cutter.hole_filled.connect(func(at: Vector3) -> void: gave.append([clock[0], TerrainGrid.vertex_id(at.x, at.z)]))
	var ground := shape.field()
	var near_start := true
	var drill_gone := false
	while ground.holes.count() == 0 and clock[0] < ARM_TICKS + 60:
		await _c._frames(1)
		clock[0] += 1
		if clock[0] == 20:
			near_start = drill.ticks == 20 and drill.place.distance_to(BoreSpiral.new(CENTER, TRY_RANGE_M, 0.9 * spell.speed_m_s / 60.0).skip(20)) < 1e-3 and drill.place.distance_to(CENTER) > 5.5
		if clock[0] == 450:
			drill_gone = not drill.look.visible
	_c._note("first hole at tick", [clock[0]])
	checks["first_hole_600_ticks_after_birth"] = absi(clock[0] - ARM_TICKS) <= 1
	checks["drill_walks_from_the_start"] = near_start
	var holes := ground.removed_ids()
	checks["first_hole_is_the_spiral_start"] = holes.size() == 1 and holes[0] == TerrainGrid.id_of(first_vertex)
	var at := TerrainGrid.point_of(first_vertex)
	var off := true
	for corner in [Vector2(3.0, 3.0), Vector2(-3.0, 3.0), Vector2(3.0, -3.0), Vector2(-3.0, -3.0)]:
		off = off and not shape.is_on_ground(at.x + corner.x, at.y + corner.y) and is_nan(shape.height_at(at.x + corner.x, at.y + corner.y))
	checks["four_cells_without_land"] = off
	await _c._frames(1)
	checks["collision_has_the_hole"] = is_nan(_c._ray(at)) and _c._collision.pending_count() == 0
	var tumbling := BodyNudge.tumbling_of(body)
	checks["body_over_it_is_thrown"] = tumbling != null and tumbling.is_on()
	var all_taken := []
	var walls_ok := true
	while is_instance_valid(zone) and not zone.is_queued_for_deletion() and clock[0] < 4000:
		await _c._frames(1)
		clock[0] += 1
		if clock[0] % 97 == 0 and ground.holes.count() > 0:
			walls_ok = walls_ok and HoleWallRules.arrays(shape.index, ground.removed_ids()).size() == 5
	FxBus.played.disconnect(hear)
	checks["body_fell_and_was_gone"] = not is_instance_valid(body)
	checks["drill_gone_when_its_spiral_ends"] = drill_gone
	checks["walls_for_every_hole"] = walls_ok
	checks["zone_ended"] = not is_instance_valid(zone) or zone.is_queued_for_deletion()
	checks["ground_whole_at_the_end"] = ground.holes.count() == 0
	_c._note("holes taken/given back/ticks", [took.size(), gave.size(), clock[0]])
	checks["many_holes"] = took.size() >= 12 and gave.size() == took.size()
	var reverse := true
	for k in gave.size():
		reverse = reverse and gave[k][1] == took[took.size() - 1 - k][1]
	checks["given_back_last_first"] = reverse
	var spacing := gave.size() > 1
	for k in range(1, gave.size()):
		spacing = spacing and gave[k][0] - gave[k - 1][0] == 30
	checks["one_back_every_30_ticks"] = spacing
	var wait: int = gave[0][0] - took[took.size() - 1][0] if not gave.is_empty() else -1
	_c._note("last taken to first back", [wait])
	checks["wait_3s_and_2_ticks_after_the_end"] = wait >= 182 and wait <= 182 + 30
	var spared := 0
	var ring := BoreSpiral.new(CENTER, TRY_RANGE_M, 0.8)
	var seen := {}
	while not ring.arrived:
		var vertex := TerrainGrid.vertex_near(ring.advance())
		if not seen.has(vertex) and shape.index.land[TerrainGrid.id_of(vertex)] == 1 and Vector2(vertex).distance_to(house_xz / TerrainGrid.CELL_M) * TerrainGrid.CELL_M < HoleRules.BUILDING_CLEARANCE_M:
			spared += 1
		seen[vertex] = true
	var closest := INF
	for pair in took:
		var vertex_at := TerrainGrid.point_of(TerrainGrid.vertex_of(int(pair[1])))
		closest = minf(closest, vertex_at.distance_to(house_xz))
	_c._note("house: vertices spared / closest taken m", [spared, snappedf(closest, 0.1)])
	checks["house_had_vertices_in_the_way"] = spared > 0
	checks["house_never_within_11m"] = closest >= HoleRules.BUILDING_CLEARANCE_M
	checks["a_piece_fell_for_every_hole"] = played["scene"] == took.size() and played["dig"] == took.size() and played["repair"] == gave.size()
	house.queue_free()
	wizard.queue_free()
	await _c._frames(2)
	return _c._verdict("bore_cut", checks)


## A cast that is cut leaves the ground whole and nothing behind.
func _cancel() -> Dictionary:
	var checks := {}
	var wizard = _c._wizard(1, _c._far_wizard_spot(), "james", 8)
	var shape: Terrain = _c._shape
	var zone: GroundZone = _c._zone("Bore", PackedVector3Array([Vector3(CENTER.x, shape.height_at(CENTER.x, CENTER.y), CENTER.y)]), wizard, 30, ARM_TICKS)
	await _c._frames(20)
	zone.cancel()
	await _c._frames(ARM_TICKS + 5)
	checks["no_hole"] = shape.field().holes.count() == 0
	checks["zone_gone"] = not is_instance_valid(zone) or zone.is_queued_for_deletion()
	wizard.queue_free()
	await _c._frames(2)
	return _c._verdict("bore_cancel", checks)


## A path goes round a hole once the navmesh is baked again, and the pathfinder knows the place is not free any more.
func _nav() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var service := NavService.new()
	service.name = "Nav"
	service.terrain = shape
	service.build_on_ready = false
	_c._collision.add_to_group(NavFingerprint.GROUP)
	_c._bed.add_child(service)
	service.build()
	await _c._frames(4)
	var start := Vector3(1504.9, 17.0, 1540.5)
	var goal := Vector3(1037.7, 15.0, 1009.9)
	var before := service.find_path(start, goal)
	var middle := Vector2.ZERO
	var best := 0.0
	var last := Vector2(start.x, start.z)
	for point in before:
		var here := Vector2(point.x, point.z)
		if last.distance_to(here) > best:
			best = last.distance_to(here)
			middle = (last + here) * 0.5
		last = here
	var vertex := TerrainGrid.vertex_near(middle)
	var id := TerrainGrid.id_of(vertex)
	var centre := TerrainGrid.point_of(vertex)
	_c._note("path points / longest leg m / hole at", [before.size(), snappedf(best, 0.1), centre])
	checks["a_path_exists"] = before.size() >= 1 and best > 15.0 and shape.index.land[id] == 1
	checks["old_path_passes_over_the_place"] = not _crosses(start, before, shape) and _near(start, before, centre) < 7.1
	checks["the_hole_is_there"] = shape.cut_hole(centre).size() == 1 and not shape.is_on_ground(centre.x, centre.y)
	checks["old_path_would_cross_it"] = _crosses(start, before, shape)
	var guard := 1800
	while guard > 0 and (service.rebakes == 0 or service.is_rebaking()):
		guard -= 1
		await _c._frames(1)
	_c._note("rebakes / frames left", [service.rebakes, guard])
	checks["navmesh_baked_again"] = service.rebakes >= 1
	var after := service.find_path(start, goal)
	checks["new_path_exists"] = after.size() >= 1
	checks["new_path_never_over_the_hole"] = not _crosses(start, after, shape)
	checks["hole_is_not_free_for_the_pathfinder"] = not service.is_free_at(Vector3(centre.x, shape.height_at(centre.x + 20.0, centre.y), centre.y))
	shape.fill_hole(centre)
	service.queue_free()
	_c._collision.remove_from_group(NavFingerprint.GROUP)
	await _c._frames(2)
	return _c._verdict("bore_nav", checks)


## True when a leg of the path from `start` has a point (every metre) with no land under it.
func _crosses(start: Vector3, path: PackedVector3Array, shape: Terrain) -> bool:
	var last := Vector2(start.x, start.z)
	for point in path:
		var here := Vector2(point.x, point.z)
		for step in int(last.distance_to(here)):
			var spot := last.lerp(here, float(step) / maxf(last.distance_to(here), 1.0))
			if not shape.is_on_ground(spot.x, spot.y):
				return true
		last = here
	return false


## How close the path comes to `spot` (m on the ground plane).
func _near(start: Vector3, path: PackedVector3Array, spot: Vector2) -> float:
	var last := Vector2(start.x, start.z)
	var best := INF
	for point in path:
		var here := Vector2(point.x, point.z)
		best = minf(best, Geometry2D.get_closest_point_to_segment(spot, last, here).distance_to(spot))
		last = here
	return best


func _ticks_of(spiral: BoreSpiral) -> int:
	var ticks := 0
	while not spiral.arrived and ticks < 5000:
		spiral.advance()
		ticks += 1
	return ticks


## Land triangles per 10 m cell from the index `cells` (two ids per cell, -1 for none).
static func _land_counts(cells: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TerrainGrid.COUNT)
	if cells.size() == TerrainGrid.COUNT * 2:
		for cell in out.size():
			out[cell] = int(cells[cell * 2] >= 0) + int(cells[cell * 2 + 1] >= 0)
	return out


## A lattice vertex near the click whose surroundings (`margin` cells each way) are all full land cells; `with_next` also wants
## the vertex to its east to be like that.
func _full_vertex(shape: Terrain, margin: int, with_next := false) -> Vector2i:
	var counts := _land_counts(shape.index.cells)
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			var vertex := Vector2i(int(CENTER.x / TerrainGrid.CELL_M) + dx, int(CENTER.y / TerrainGrid.CELL_M) + dz)
			var full := true
			for cz in range(vertex.y - margin + 1, vertex.y + margin + (1 if with_next else 0) + 1):
				for cx in range(vertex.x - margin + 1, vertex.x + margin + (2 if with_next else 1)):
					full = full and counts[TerrainGrid.id_of(Vector2i(cx, cz))] == 2
			if full:
				return vertex
	return Vector2i(-1, -1)
