extends "res://addons/prop_kit/tests/prop_test.gd"

## PropNavZones2D: the whole zone walkable with no outline, walls and props block, components.

const PROPS_LAYER := 2

var props: Node2D


## A 1024 x 512 px field, an optional wall (layer 1) and circle props (layer 2) at `spots`.
func _world(spots: Array[Vector2], wall := false) -> PropNavZones2D:
	if wall:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(40.0, 600.0)
		shape.shape = box
		body.add_child(shape)
		body.position = Vector2(512.0, 256.0)
		root.add_child(body)
	props = Node2D.new()
	root.add_child(props)
	for at in spots:
		_bush(at)
	var template := NavigationPolygon.new()
	template.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	template.parsed_collision_mask = 1
	var zones := PropNavZones2D.new()
	zones.navigation_polygon = template
	zones.zone_size = 256.0
	zones.area = Rect2(0.0, 0.0, 1024.0, 512.0)
	root.add_child(zones)
	return zones


func _bush(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << (PROPS_LAYER - 1)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	body.add_child(shape)
	body.position = at
	props.add_child(body)
	body.add_to_group(PropObstructions.GROUP)
	return body


func _map() -> RID:
	return root.get_viewport().find_world_2d().navigation_map


## Waits until the navmesh is ready and nothing is on its way.
func _settled(zones: PropNavZones2D, frames := 900) -> bool:
	for i in frames:
		await tree.process_frame
		if zones.is_ready() and not zones.is_updating():
			return true
	return false


func _walkable(at: Vector2) -> bool:
	return NavigationServer2D.map_get_closest_point(_map(), at).distance_to(at) < 0.5


func test_an_open_field_with_props() -> void:
	var zones := _world([Vector2(128, 128), Vector2(700, 300)])
	check(await _settled(zones), "the bake ends")
	check(zones.grid().zone_count() == 8, "4 x 2 zones (%d)" % zones.grid().zone_count())
	check(_walkable(Vector2(60, 60)) and _walkable(Vector2(1000, 500)), "no outline: the field is walkable")
	check(not _walkable(Vector2(128, 128)), "a prop blocks")
	var path := NavigationServer2D.map_get_path(_map(), Vector2(20, 20), Vector2(1000, 490), true)
	check(path.size() > 1 and path[-1].distance_to(Vector2(1000, 490)) < 1.0, "a path across the zones")
	check(zones.index.component_count == 1, "one component")


func test_a_wall_splits_the_field() -> void:
	var zones := _world([], true)
	await _settled(zones)
	check(not _walkable(Vector2(512, 256)), "the parsed wall blocks")
	check(zones.index.component_count == 2, "two components (%d)" % zones.index.component_count)
	check(not zones.index.can_reach_2d(Vector2(100, 100), Vector2(900, 100)), "left and right apart")
	check(zones.index.can_reach_2d(Vector2(100, 100), Vector2(100, 480)), "the left side is one")
	var closest := zones.index.closest_point_2d(Vector2(512, 256))
	check(absf(closest.x - 512.0) >= 20.0, "the closest point is beside the wall (%s)" % closest)


func test_removing_a_prop_rebakes_its_zones() -> void:
	var zones := _world([Vector2(128, 128), Vector2(900, 400)])
	await _settled(zones)
	props.get_child(0).queue_free()
	check(await _settled(zones), "the re-bake ends")
	check(zones.stats.zones_baked < 8, "only the zones it touched (%s)" % zones.stats)
	check(_walkable(Vector2(128, 128)), "walkable where it stood")
	check(not _walkable(Vector2(900, 400)), "the other prop still blocks")


func test_closest_point_can_skip_a_small_side() -> void:
	var zones := _world([])
	# A wall near the right edge: the strip beyond it is a small component.
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20.0, 600.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector2(900.0, 256.0)
	root.add_child(body)
	check(await _settled(zones), "the bake ends")
	var index := zones.index
	check(index.component_count == 2, "two components (%d)" % index.component_count)
	var strip := index.component_at_2d(Vector2(980, 256))
	check(strip >= 0 and index.component_area[strip] < 100000.0, "the strip is small (%s)" % index.component_area)
	check(index.closest_point_2d(Vector2(905, 256)).x > 900.0, "any component: the strip beside it")
	check(index.closest_point_2d(Vector2(905, 256), INF, 100000.0).x < 900.0, "at least 100000 px²: the field")


func test_a_weld_drops_what_the_map_cannot_tell_apart() -> void:
	# A zone of 20 x 10 and a sliver: vertex 4 is 0.36 px from vertex 1, in its map cell.
	var piece := NavigationPolygon.new()
	piece.border_size = 2.0
	piece.baking_rect = Rect2(0, 0, 20, 10).grow(2.0)
	piece.vertices = PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10.3, 0.2),
		Vector2(20, 0), Vector2(20, 10),
	])
	piece.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	piece.add_polygon(PackedInt32Array([1, 4, 2]))
	piece.add_polygon(PackedInt32Array([4, 5, 6, 2]))
	PropZoneBaker._weld_2d(piece, 1.0)
	check(piece.vertices.size() == 6, "the two in one cell are one (%d)" % piece.vertices.size())
	check(piece.vertices.has(Vector2(10, 0)) and not piece.vertices.has(Vector2(10.3, 0.2)), "the one on the zone's edge stays")
	check(piece.get_polygon_count() == 2, "the sliver is gone (%d)" % piece.get_polygon_count())
	var right := piece.get_polygon(1)
	check(right.size() == 4 and piece.vertices[right[0]] == Vector2(10, 0), "the next polygon uses the kept vertex")


## A world of its own (a SubViewport with its own World2D) whose navigation map iterates
## synchronously from the start, with synchronous regions: a field, one bush at (128, 128).
func test_ready_with_synchronous_iterations() -> void:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var map := viewport.world_2d.navigation_map
	NavigationServer2D.map_set_use_async_iterations(map, false)
	ProjectSettings.set_setting("navigation/world/region_use_async_iterations", false)
	props = Node2D.new()
	viewport.add_child(props)
	_bush(Vector2(128, 128))
	var template := NavigationPolygon.new()
	template.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	template.parsed_collision_mask = 1
	var zones := PropNavZones2D.new()
	zones.navigation_polygon = template
	zones.zone_size = 256.0
	zones.area = Rect2(0.0, 0.0, 1024.0, 512.0)
	viewport.add_child(zones)
	var walkable := func(at: Vector2) -> bool:
		return NavigationServer2D.map_get_closest_point(map, at).distance_to(at) < 0.5
	check(await _settled(zones, 300), "a synchronous map: ready")
	check(not walkable.call(Vector2(128, 128)) and walkable.call(Vector2(600, 300)), "the paths see the prop at once")
	props.get_child(0).queue_free()
	check(await _settled(zones, 300), "a change in play: updated too")
	check(walkable.call(Vector2(128, 128)), "where it stood is walkable at once")
	ProjectSettings.set_setting("navigation/world/region_use_async_iterations", true)
