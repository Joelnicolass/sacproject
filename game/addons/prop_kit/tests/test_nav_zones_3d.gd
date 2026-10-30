extends "res://addons/prop_kit/tests/prop_test.gd"

## PropNavZones3D: zones that meet, props as obstructions, following the props, partial re-bakes,
## apply, ready and updated, saved bakes, and the index.

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


## Waits until the navmesh is ready and nothing is on its way.
func _settled(zones: PropNavZones3D, frames := 900) -> bool:
	for i in frames:
		await tree.process_frame
		if zones.is_ready() and not zones.is_updating():
			return true
	return false


## A zones node over the props of the last `_world`, with `saved`.
func _zones_with(saved: PropNavBake, like: PropNavZones3D) -> PropNavZones3D:
	var zones := PropNavZones3D.new()
	zones.navigation_mesh = like.navigation_mesh
	zones.zone_size = like.zone_size
	zones.saved = saved
	return zones


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


func test_ready_and_updated() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	var updates := [0]
	zones.updated.connect(func() -> void: updates[0] += 1)
	check(not zones.is_ready(), "not ready before the first bake")
	check(await _settled(zones), "ready")
	check(updates[0] == 1, "updated once for the first bake (%d)" % updates[0])
	check(zones.index != null, "with its index")
	props.get_child(0).queue_free()
	await tree.process_frame
	check(zones.is_updating() and zones.is_ready(), "a change on its way: updating, still ready")
	await zones.updated
	check(not zones.is_updating() and _walkable(Vector3(8, 0, 8)), "updated: the paths see it")


func test_the_index_sees_the_whole_navmesh() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var index := zones.index
	check(index.component_count == 1, "one connected floor across zones (%d)" % index.component_count)
	check(index.can_reach(Vector3(1, 0, 1), Vector3(63, 0, 31)), "corner to corner")
	check(index.polygon_at(Vector3(8, 0, 8)) == -1, "no polygon in a trunk")
	check(not index.can_reach(Vector3(8, 0, 8), Vector3(63, 0, 31)), "not from inside a trunk")
	check(index.can_reach(Vector3(8, 0, 8), Vector3(63, 0, 31), 2.0), "but from 2 m around it")
	var closest := index.closest_point(Vector3(8, 0, 8))
	check(closest.distance_to(Vector3(8, 0, 8)) > 1.0, "the closest point is out of the trunk")
	check(index.stitched(zones.navigation_mesh).get_polygon_count() == zones.stats.polygons, "stitched holds every polygon")


func test_closest_point_measures_on_the_plane() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var index := zones.index
	# The navmesh sits above the ground; the edge of the trunk's ring is 1.5 m from its centre.
	var near := index.closest_point(Vector3(8, 0, 8), 1.6)
	check(near != Vector3.INF, "within 1.6 m on the plane, whatever the height (%s)" % near)
	check(Vector2(near.x - 8, near.z - 8).length() <= 1.6, "and within it")
	check(index.closest_point(Vector3(8, 0, 8), 1.0) == Vector3.INF, "none within 1 m")
	var above := index.closest_point(Vector3(20, 30, 20), 0.5)
	check(above != Vector3.INF and absf(above.x - 20) < 0.01, "high above the floor: the floor under it")


func test_freed_props_rebake_where_they_stood() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(24, 0, 24), Vector3(40, 0, 20)])
	await _settled(zones)
	props.get_child(0).queue_free()
	check(await _settled(zones), "the re-bake ends")
	check(zones.stats.parse_ms == 0.0, "no parse when only props changed")
	check(zones.stats.zones_baked < zones.stats.zones_total, "only the touched zones (%s)" % zones.stats)
	check(_walkable(Vector3(8, 0, 8)), "where the trunk was is walkable now")
	var partial: Array[PackedVector3Array] = []
	for zone in zones.grid().zone_count():
		partial.append((zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices())
	zones.rebake_all()
	await _settled(zones)
	var same := true
	for zone in zones.grid().zone_count():
		same = same and partial[zone] == (zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices()
	check(same, "every zone equals a full bake of the same scene")


func test_added_props_cut_the_navmesh() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	_trunk(Vector3(40, 0, 16))
	check(await _settled(zones), "the re-bake ends")
	check(not _walkable(Vector3(40, 0, 16)), "a new prop cuts the navmesh")
	check(zones.stats.zones_baked < zones.stats.zones_total, "only its zones (%s)" % zones.stats)


func test_a_moved_prop_rebakes_both_places() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var trunk := props.get_child(0) as StaticBody3D
	trunk.position = Vector3(40, 2, 20)
	zones.rebake_prop(trunk)
	check(await _settled(zones), "the re-bake ends")
	check(_walkable(Vector3(8, 0, 8)), "where it was is walkable")
	check(not _walkable(Vector3(40, 0, 20)), "where it is now is not")


func test_follow_props_off() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	zones.follow_props = false
	await _settled(zones)
	props.get_child(0).queue_free()
	for i in 30:
		await tree.process_frame
	check(not zones.is_updating() and not _walkable(Vector3(8, 0, 8)), "nothing re-bakes on its own")
	zones.rebake(Vector3(8, 0, 8), 2.0)
	check(await _settled(zones), "rebake(at, radius) ends")
	check(_walkable(Vector3(8, 0, 8)), "and sees the prop gone")


func test_manual_apply_waits_for_changes_in_play() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	zones.apply_mode = PropNavZones3D.Apply.MANUAL
	var ready_zones: Array[PackedInt32Array] = []
	zones.bake_ready.connect(func(baked: PackedInt32Array) -> void: ready_zones.append(baked))
	check(await _settled(zones), "the start bake applies on its own, MANUAL or not")
	check(ready_zones.is_empty(), "and asks for no apply()")
	props.get_child(0).queue_free()
	for i in 600:
		await tree.process_frame
		if zones.has_result():
			break
	check(zones.has_result() and ready_zones.size() == 1, "a change in play waits (%s)" % [ready_zones])
	check(not _walkable(Vector3(8, 0, 8)), "the old pieces until then")
	zones.apply()
	check(not zones.has_result(), "applied")
	check(await _settled(zones), "updated")
	check(_walkable(Vector3(8, 0, 8)), "the new pieces in force")


func test_changes_while_busy_are_joined() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(40, 0, 20)])
	await _settled(zones)
	var later := props.get_child(1)
	props.get_child(0).queue_free()
	await tree.process_frame
	await tree.process_frame
	later.queue_free()
	check(await _settled(zones), "both re-bakes end")
	check(_walkable(Vector3(8, 0, 8)) and _walkable(Vector3(40, 0, 20)), "both changes were baked")


func test_a_saved_bake_loads_and_goes_stale() -> void:
	var zones := _world([Vector3(8, 0, 8), Vector3(40, 0, 20)])
	await _settled(zones)
	var saved := zones.to_saved()
	check(saved.pieces.size() == 8 and saved.fingerprint != 0, "the bake as a resource")
	var fresh := _zones_with(saved, zones)
	var stale := [false]
	fresh.stale.connect(func() -> void: stale[0] = true)
	zones.queue_free()
	root.add_child(fresh)
	check(await _settled(fresh), "ready from the saved bake")
	check(fresh.stats.zones_baked == 0, "without baking (%s)" % fresh.stats)
	check(fresh.region_of(0).navigation_mesh == saved.pieces[0], "its pieces")
	check(fresh.index != null, "with its index")
	check(not stale[0], "the same props: not stale")
	var again := _zones_with(saved, fresh)
	again.stale.connect(func() -> void: stale[0] = true)
	var updates := [0]
	again.updated.connect(func() -> void: updates[0] += 1)
	props.get_child(0).free()
	fresh.queue_free()
	root.add_child(again)
	check(await _settled(again), "ready")
	check(stale[0], "a prop gone: stale")
	check(again.stats.zones_baked == 8 and updates[0] == 1, "baked again, and only the new pieces went in")
	check(_walkable(Vector3(8, 0, 8)), "without it")


func test_a_stale_bake_applies_on_its_own_with_manual() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var saved := zones.to_saved()
	var manual := _zones_with(saved, zones)
	manual.apply_mode = PropNavZones3D.Apply.MANUAL
	props.get_child(0).free()
	zones.queue_free()
	root.add_child(manual)
	check(await _settled(manual), "ready without apply()")
	check(not manual.has_result() and _walkable(Vector3(8, 0, 8)), "the fresh bake is in force")


func test_settings_make_a_bake_stale() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	await _settled(zones)
	var saved := zones.to_saved()
	var wider := _zones_with(saved, zones)
	wider.navigation_mesh = zones.navigation_mesh.duplicate() as NavigationMesh
	wider.navigation_mesh.agent_radius = 1.0
	wider.rebake_when_stale = false
	var stale := [false]
	wider.stale.connect(func() -> void: stale[0] = true)
	zones.queue_free()
	root.add_child(wider)
	await _settled(wider)
	check(stale[0], "another agent radius: stale")


func test_the_game_fingerprint_makes_a_bake_stale() -> void:
	var zones := _world([Vector3(8, 0, 8)])
	zones.extra_fingerprint = func() -> int: return 1
	await _settled(zones)
	var saved := zones.to_saved()
	var same := _zones_with(saved, zones)
	same.rebake_when_stale = false
	same.extra_fingerprint = func() -> int: return 1
	var stale := [0]
	same.stale.connect(func() -> void: stale[0] += 1)
	zones.queue_free()
	root.add_child(same)
	await _settled(same)
	check(stale[0] == 0, "the same terrain: not stale")
	same.rebake_when_stale = true
	same.extra_fingerprint = func() -> int: return 2
	check(stale[0] == 1, "set later, another terrain: stale at once")
	check(same.is_updating(), "and every zone bakes again")
	check(await _settled(same), "ready")
	check(same.stats.zones_baked == 8, "with the new number (%s)" % same.stats)


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


## Under the floor from -1.0 down to `bottom`: lower ground for the parse, and no new walkable top.
func _pit(at: Vector2, bottom: float) -> StaticBody3D:
	var pit := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, -1.0 - bottom, 4.0)
	shape.shape = box
	pit.add_child(shape)
	pit.position = Vector3(at.x, (bottom - 1.0) * 0.5, at.y)
	root.add_child(pit)
	return pit


func test_a_lower_ground_keeps_the_seams() -> void:
	var zones := _world([])
	await _settled(zones)
	# The ground goes below its lowest point so far, by a fraction of a cell, in the last zone only.
	_pit(Vector2(56, 24), -3.01)
	zones.rebake(Vector3(56, 0, 24), 2.0)
	check(await _settled(zones), "the re-bake ends")
	check(zones.stats.zones_baked == 1, "one zone (%s)" % zones.stats)
	var index := zones.index
	check(index.component_count == 1, "one floor across the seams (%d)" % index.component_count)
	var path := NavigationServer3D.map_get_path(_map(), Vector3(2, 0, 2), Vector3(62, 0, 30), true)
	check(path.size() > 1 and path[-1].distance_to(Vector3(62, 0, 30)) < 0.6, "a path still reaches the re-baked zone")
	var partial: Array[PackedVector3Array] = []
	for zone in zones.grid().zone_count():
		partial.append((zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices())
	zones.rebake_all()
	await _settled(zones)
	var same := true
	for zone in zones.grid().zone_count():
		same = same and partial[zone] == (zones.region_of(zone).navigation_mesh as NavigationMesh).get_vertices()
	check(same, "every zone equals a full bake of the lower ground")


func test_a_fixed_height_range() -> void:
	var zones := _world([])
	zones.height_range = Vector2(-50.1, 400.0)
	check(await _settled(zones), "the bake ends")
	var box := (zones.region_of(0).navigation_mesh as NavigationMesh).filter_baking_aabb
	check(is_equal_approx(box.position.y, -50.25) and is_equal_approx(box.end.y, 400.0), "the range, out to whole cells (%s)" % box)
	check(zones.index.component_count == 1, "one floor (%d)" % zones.index.component_count)


func test_closest_point_can_skip_islands() -> void:
	var zones := _world([])
	# An 8 m building across a zone line. Its roof is an island, and so is its inside: the bake
	# sees a collider's faces, so the floor within the walls is a pocket closed off by them.
	var building := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 8.0, 8.0)
	shape.shape = box
	building.add_child(shape)
	building.position = Vector3(28, 4, 16)
	root.add_child(building)
	check(await _settled(zones), "the bake ends")
	var index := zones.index
	check(index.component_count == 3, "the floor, the roof and the inside (%d)" % index.component_count)
	var roof := index.component_at(Vector3(28, 8, 16))
	check(roof >= 0 and index.component_area[roof] < 64.0, "the roof is small (%s)" % index.component_area)
	var largest := 0.0
	for area in index.component_area:
		largest = maxf(largest, area)
	check(largest > 1500.0, "the floor is large (%s)" % index.component_area)
	var footprint := Rect2(24, 12, 8, 8)
	var above := Vector3(28, 9, 16)
	check(index.closest_point(above).y > 7.0, "any component: the roof")
	var land := index.closest_point(above, INF, 100.0)
	check(land != Vector3.INF and land.y < 1.0 and not footprint.has_point(Vector2(land.x, land.z)), "at least 100 m²: the floor outside (%s)" % land)
	check(index.closest_point(above, 2.0, 100.0) == Vector3.INF, "none within 2 m but the roof")
	var floor_component := index.component_at(Vector3(40, 0, 16))
	check(index.component_at(above) == roof, "the component under the point: the roof")
	check(index.component_at(above, 0.0, 100.0) == -1, "at least 100 m² and no reach: none")
	check(index.component_at(above, 8.0, 100.0) == floor_component, "within 8 m: the floor")
	check(index.can_reach(above, Vector3(40, 0, 16), 8.0, 100.0), "so a body on the roof counts from the floor")
	var inside := index.closest_point(Vector3(28, 1, 16))
	check(footprint.has_point(Vector2(inside.x, inside.z)), "any component: the pocket inside")
	var out := index.closest_point(Vector3(28, 1, 16), INF, 100.0)
	check(not footprint.has_point(Vector2(out.x, out.z)), "at least 100 m²: out of it (%s)" % out)


## A world of its own (a SubViewport with its own World3D), whose navigation map iterates
## synchronously from the start, as in a game that sets it so for determinism. Regions take
## `regions_async`. The floor and one trunk at (8, 0, 8), and a zones node over them.
func _sync_world(regions_async: bool) -> PropNavZones3D:
	var viewport := SubViewport.new()
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	NavigationServer3D.map_set_use_async_iterations(viewport.world_3d.navigation_map, false)
	ProjectSettings.set_setting("navigation/world/region_use_async_iterations", regions_async)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(64.0, 1.0, 32.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(32.0, -0.5, 16.0)
	viewport.add_child(floor)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (PROPS_LAYER - 1)
	var trunk := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.0
	cylinder.height = 4.0
	trunk.shape = cylinder
	body.add_child(trunk)
	body.position = Vector3(8, 2, 8)
	body.add_to_group(PropObstructions.GROUP)
	viewport.add_child(body)
	var template := NavigationMesh.new()
	template.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	template.geometry_collision_mask = 1
	var zones := PropNavZones3D.new()
	zones.navigation_mesh = template
	zones.zone_size = 16.0
	viewport.add_child(zones)
	return zones


func _walkable_in(map: RID, at: Vector3) -> bool:
	var closest := NavigationServer3D.map_get_closest_point(map, at)
	return Vector2(closest.x, closest.z).distance_to(Vector2(at.x, at.z)) < 0.05


func test_ready_with_synchronous_iterations() -> void:
	for regions_async in [false, true]:
		var zones := _sync_world(regions_async)
		var map := zones.get_world_3d().navigation_map
		var ok := await _settled(zones, 300)
		check(ok, "a synchronous map, regions async %s: ready" % regions_async)
		check(not _walkable_in(map, Vector3(8, 0, 8)) and _walkable_in(map, Vector3(20, 0, 20)), "the paths see it at once")
		var trunk := zones.get_parent().get_child(1)
		trunk.queue_free()
		check(await _settled(zones, 300), "a change in play: updated too")
		check(_walkable_in(map, Vector3(8, 0, 8)), "where the prop stood is walkable at once")
		ProjectSettings.set_setting("navigation/world/region_use_async_iterations", true)
		zones.get_parent().queue_free()
		await tree.process_frame
