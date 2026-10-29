extends "res://addons/prop_kit/tests/prop_test.gd"

## PropZoneGrid: anchored at (0, 0), zones row by row, the zones a rect touches.


func test_the_grid_is_anchored_at_the_origin() -> void:
	var grid := PropZoneGrid.new(Rect2(-10.0, 5.0, 70.0, 30.0), 32.0)
	check(grid.first == Vector2i(-1, 0), "the first cell is floor(position / size)")
	check(grid.count == Vector2i(3, 2), "3 x 2 zones cover x -10..60, y 5..35 (%s)" % grid.count)
	check(grid.zone_count() == 6, "six zones")
	check(grid.zone_rect(0) == Rect2(-32.0, 0.0, 32.0, 32.0), "zone 0 starts on a multiple of 32")
	check(grid.zone_rect(4) == Rect2(0.0, 32.0, 32.0, 32.0), "row by row")
	check(grid.area() == Rect2(-32.0, 0.0, 96.0, 64.0), "the area the zones cover")


func test_points_and_rects_find_their_zones() -> void:
	var grid := PropZoneGrid.new(Rect2(0.0, 0.0, 64.0, 64.0), 16.0)
	check(grid.zone_at(Vector2(17.0, 1.0)) == 1, "a point in the second zone")
	check(grid.zone_at(Vector2(-1.0, 1.0)) == -1, "outside = -1")
	check(grid.zones_touching(Rect2(15.0, 15.0, 2.0, 2.0)) == PackedInt32Array([0, 1, 4, 5]), "a rect on a corner touches four")
	check(grid.zones_touching(Rect2(100.0, 100.0, 5.0, 5.0)).is_empty(), "nothing outside")
	check(grid.zones_touching(Rect2(-50.0, -50.0, 60.0, 60.0)) == PackedInt32Array([0]), "cut to the grid")
	check(grid.all().size() == 16, "all() lists every zone")


func test_an_empty_area_has_no_zones() -> void:
	var grid := PropZoneGrid.new()
	check(grid.zone_count() == 0, "no area, no zones")
	check(grid.zones_touching(Rect2(0, 0, 10, 10)).is_empty(), "nothing touches an empty grid")
