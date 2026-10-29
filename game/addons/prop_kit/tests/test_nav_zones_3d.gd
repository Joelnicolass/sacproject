extends "res://addons/prop_kit/tests/prop_test.gd"

## PropNavZones3D: zones that meet, props as obstructions, partial re-bakes, apply, saved bakes,
## and the index.

const PROPS_LAYER := 2

var props: Node3D


## A 64 x 32 m floor (layer 1) with trunks (layer 2, group prop_obstruction) at `trunks`.
func _world(trunks: Array[Vector3], zone_size := 16.0) -> PropNavZones3D:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(64.0, 1.0, 32.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(32.0, -0.5, 16.0)
	root.add_child(floor)
	props = Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for at in trunks:
		_trunk(at)
	var template := NavigationMesh.new()
	template.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	template.geometry_collision_mask = 1
	var zones := PropNavZones3D.new()
	zones.name = "Nav"
	zones.navigation_mesh = template
	zones.zone_size = zone_size
	root.add_child(zones)
	return zones


func _trunk(at: Vector3, radius := 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (PROPS_LAYER - 1)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 4.0
	shape.shape = cylinder
	body.add_child(shape)
	body.position = at + Vector3(0.0, 2.0, 0.0)
	props.add_child(body)
	body.add_to_group(PropObstructions.GROUP)
	return body


## Waits until nothing bakes and the navigation map uses the pieces in force (`synced`).
func _settled(zones: PropNavZones3D, frames := 900) -> bool:
	for i in frames:
		await tree.process_frame
		if zones.is_done() and not zones.has_result() and zones.is_synced():
			return true
	return false


func _map() -> RID:
	return root.get_viewport().find_world_3d().navigation_map


func _walkable(at: Vector3) -> bool:
	var closest := NavigationServer3D.map_get_closest_point(_map(), at)
	return Vector2(closest.x, closest.z).distance_to(Vector2(at.x, at.z)) < 0.05


func test_zones_meet_and_props_block() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(40, 0, 20)])
	check(await _settled(zones), "the first bake ends")
	check(zones.grid().zone_count() == 8, "4 x 2 zones over the floor (%d)" % zones.grid().zone_count())
	check(zones.stats.zones_baked == 8, "all baked: %s" % zones.stats)
	check(zones.region_of(0) != null and zones.region_of(7) != null, "a region per zone")
	var path := NavigationServer3D.map_get_path(_map(), Vector3(2, 0, 2), Vector3(62, 0, 30), true)
	check(path.size() > 1 and path[-1].distance_to(Vector3(62, 0, 30)) < 0.6, "a path crosses every zone line")
	check(not _walkable(Vector3(8, 0, 8)), "a trunk's centre is not walkable")
	check(not _walkable(Vector3(9.3, 0, 8)), "nor its agent-radius ring")
	check(_walkable(Vector3(12, 0, 8)), "but past it is")
	check(zones.stats.obstructions == 2, "two obstructions")


func test_the_index_sees_the_whole_navmesh() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var index := zones.index
	check(index != null, "an index after the bake")
	check(index.component_count == 1, "one connected floor across zones (%d)" % index.component_count)
	check(index.same_component(Vector3(1, 0, 1), Vector3(63, 0, 31)), "corner to corner")
	check(index.polygon_at(Vector3(8, 0, 8)) == -1, "no polygon in a trunk")
	var closest := index.closest_point(Vector3(8, 0, 8))
	check(closest.distance_to(Vector3(8, 0, 8)) > 1.0, "the closest point is out of the trunk")
	check(index.stitched(zones.navigation_mesh).get_polygon_count() == zones.stats.polygons, "stitched holds every polygon")


func test_a_partial_rebake_matches_a_full_one() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(24, 0, 24), Vector3(40, 0, 20)])
	await _settled(zones)
	var gone := props.get_child(0) as StaticBody3D
	var area := PropObstructions.area_of(gone, true)
	gone.free()
	zones.rebake([area], false)
	check(await _settled(zones), "the partial re-bake ends")
	check(zones.stats.parse_ms == 0.0, "no parse when only props changed")
	check(zones.stats.zones_baked < zones.stats.zones_total, "only the touched zones (%s)" % zones.stats)
	check(_walkable(Vector3(8, 0, 8)), "where the trunk was is walkable now")
	var partial: Array[PackedVector3Array] = []
	for zone in zones.grid().zone_count():
		partial.append((zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices())
	zones.rebake_all(true)
	await _settled(zones)
	var same := true
	for zone in zones.grid().zone_count():
		same = same and partial[zone] == (zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices()
	check(same, "every zone equals a full bake of the same scene")


func test_an_added_prop_is_found() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var added := _trunk(Vector3(40, 0, 16))
	zones.rebake([PropObstructions.area_of(added, true)], false)
	await _settled(zones)
	check(not _walkable(Vector3(40, 0, 16)), "a new prop cuts the navmesh")


func test_manual_apply_waits() -> void:
	var zones := _world([])
	zones.apply_mode = PropNavZones3D.Apply.MANUAL
	var ready_zones: Array[PackedInt32Array] = []
	zones.bake_ready.connect(func(baked: PackedInt32Array) -> void: ready_zones.append(baked))
	for i in 600:
		await tree.process_frame
		if zones.has_result():
			break
	check(zones.has_result() and zones.is_done(), "a result waits, nothing runs")
	check(ready_zones.size() == 1 and ready_zones[0].size() == 8, "bake_ready said which zones")
	check(zones.region_of(0) == null, "no region before apply()")
	zones.apply()
	check(not zones.has_result(), "applied")
	check(zones.region_of(0) != null and zones.region_of(0).navigation_mesh != null, "pieces in the regions")


func test_requests_while_busy_are_joined() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(40, 0, 20)])
	await _settled(zones)
	var a := props.get_child(0) as StaticBody3D
	var b := props.get_child(1) as StaticBody3D
	var area_a := PropObstructions.area_of(a, true)
	var area_b := PropObstructions.area_of(b, true)
	a.free()
	zones.rebake([area_a], false)
	b.free()
	zones.rebake([area_b], false)
	await _settled(zones)
	check(_walkable(Vector3(8, 0, 8)) and _walkable(Vector3(40, 0, 20)), "both requests were baked")


func test_a_saved_bake_loads_and_goes_stale() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(40, 0, 20)])
	await _settled(zones)
	var saved := zones.to_saved()
	check(saved.pieces.size() == 8 and saved.fingerprint != 0, "the bake as a resource")
	var fresh := PropNavZones3D.new()
	fresh.navigation_mesh = zones.navigation_mesh
	fresh.zone_size = 16.0
	fresh.saved = saved
	var stale := [false]
	fresh.stale.connect(func() -> void: stale[0] = true)
	zones.queue_free()
	root.add_child(fresh)
	await tree.process_frame
	await tree.process_frame
	check(fresh.region_of(0) != null and fresh.region_of(0).navigation_mesh == saved.pieces[0], "loaded at once")
	check(not stale[0], "the same props: not stale")
	await _settled(fresh)
	check(fresh.index != null, "its index is built on a worker")
	var again := PropNavZones3D.new()
	again.navigation_mesh = fresh.navigation_mesh
	again.zone_size = 16.0
	again.saved = saved
	again.stale.connect(func() -> void: stale[0] = true)
	props.get_child(0).free()
	fresh.queue_free()
	root.add_child(again)
	await _settled(again)
	check(stale[0], "a prop gone: stale")
	check(_walkable(Vector3(8, 0, 8)), "and baked again without it")


func test_the_game_fingerprint_makes_a_bake_stale() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	zones.extra_fingerprint = func() -> int: return 1
	await _settled(zones)
	var saved := zones.to_saved()
	var same := PropNavZones3D.new()
	same.navigation_mesh = zones.navigation_mesh
	same.zone_size = 16.0
	same.saved = saved
	same.rebake_when_stale = false
	same.extra_fingerprint = func() -> int: return 1
	var stale := [0]
	same.stale.connect(func() -> void: stale[0] += 1)
	zones.queue_free()
	root.add_child(same)
	await _settled(same)
	check(stale[0] == 0, "the same terrain: not stale")
	var other := PropNavZones3D.new()
	other.navigation_mesh = same.navigation_mesh
	other.zone_size = 16.0
	other.saved = saved
	other.rebake_when_stale = false
	other.extra_fingerprint = func() -> int: return 2
	other.stale.connect(func() -> void: stale[0] += 1)
	same.queue_free()
	root.add_child(other)
	await _settled(other)
	check(stale[0] == 1, "the terrain changed: stale, with the props as they were")


func test_merging_lowers_the_polygon_count() -> void:
	var grove: Array[Vector3] = []
	for x in range(6):
		for z in range(6):
			grove.append(Vector3(20.0 + x * 2.6, 0.0, 6.0 + z * 2.6))
	var zones := _world(grove)
	await _settled(zones)
	var apart := zones.stats.polygons
	zones.queue_free()
	await tree.process_frame
	for child in root.get_children():
		child.free()
	var merged := _world(grove)
	merged.merge_gap = 1.0
	await _settled(merged)
	check(merged.stats.obstructions < 36, "36 trunks become fewer obstructions (%d)" % merged.stats.obstructions)
	check(merged.stats.polygons < apart, "fewer polygons: %d < %d" % [merged.stats.polygons, apart])
