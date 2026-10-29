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


## Waits until nothing bakes and the navigation map uses the pieces in force (`synced`).
func _settled(zones: PropNavZones2D, frames := 900) -> bool:
	for i in frames:
		await tree.process_frame
		if zones.is_done() and not zones.has_result() and zones.is_synced():
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
	check(not zones.index.same_component_2d(Vector2(100, 100), Vector2(900, 100)), "left and right apart")
	check(zones.index.same_component_2d(Vector2(100, 100), Vector2(100, 480)), "the left side is one")
	var closest := zones.index.closest_point_2d(Vector2(512, 256))
	check(absf(closest.x - 512.0) >= 20.0, "the closest point is beside the wall (%s)" % closest)


func test_removing_a_prop_rebakes_its_zones() -> void:
	var zones := _world([Vector2(128, 128), Vector2(900, 400)])
	await _settled(zones)
	var gone := props.get_child(0) as StaticBody2D
	var area := PropObstructions.area_of(gone, false)
	gone.free()
	zones.rebake([area], false)
	await _settled(zones)
	check(zones.stats.zones_baked < 8, "only the zones it touched (%s)" % zones.stats)
	check(_walkable(Vector2(128, 128)), "walkable where it stood")
	check(not _walkable(Vector2(900, 400)), "the other prop still blocks")
