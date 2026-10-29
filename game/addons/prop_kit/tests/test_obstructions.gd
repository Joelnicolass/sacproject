extends "res://addons/prop_kit/tests/prop_test.gd"

## PropObstructions: outlines from every supported shape, merging, filters and the fingerprint.


func _prop_3d(shape: Shape3D, at := Vector3.ZERO, scale := 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var child := CollisionShape3D.new()
	child.shape = shape
	body.add_child(child)
	body.position = at
	body.scale = Vector3.ONE * scale
	root.add_child(body)
	body.add_to_group(PropObstructions.GROUP)
	return body


func _prop_2d(shape: Shape2D, at := Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	var child := CollisionShape2D.new()
	child.shape = shape
	body.add_child(child)
	body.position = at
	root.add_child(body)
	body.add_to_group(PropObstructions.GROUP)
	return body


func _cylinder(radius := 1.0, height := 4.0) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


func _circle(radius := 10.0) -> CircleShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	return shape


func test_a_cylinder_becomes_a_ring() -> void:
	var body := _prop_3d(_cylinder(1.0, 4.0), Vector3(10.0, 2.0, 5.0), 2.0)
	var list := PropObstructions.of_3d(body, 6)
	check(list.size() == 1, "one obstruction per shape")
	var o := list[0]
	check(o.outline.size() == 6, "six sides (%d)" % o.outline.size())
	var far := 0.0
	for point in o.outline:
		far = maxf(far, point.distance_to(Vector2(10.0, 5.0)))
	check(near(far, 2.0, 0.001), "the radius with the node's scale (%.3f)" % far)
	check(near(o.bottom, -2.0, 0.001) and near(o.top, 6.0, 0.001), "heights with the scale (%.2f..%.2f)" % [o.bottom, o.top])


func test_every_3d_shape_gives_an_outline() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 4.0)
	var body := _prop_3d(box)
	body.rotation.y = PI / 2.0
	var outline := PropObstructions.of_3d(body)[0].outline
	var rect := PropObstruction.new()
	rect.outline = outline
	check(outline.size() == 4, "a box is four corners")
	check(rect.rect().size.is_equal_approx(Vector2(4.0, 2.0)), "turned 90° (%s)" % rect.rect().size)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 3.0
	var c := PropObstructions.of_3d(_prop_3d(capsule), 8)[0]
	check(c.outline.size() == 8 and near(c.top - c.bottom, 3.0, 0.001), "a capsule: a ring, its full height")
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	var s := PropObstructions.of_3d(_prop_3d(sphere), 8)[0]
	check(near(s.top - s.bottom, 4.0, 0.001), "a sphere spans its diameter")
	var convex := ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(0, 0, 2), Vector3(0, 1, 0)])
	check(PropObstructions.of_3d(_prop_3d(convex))[0].outline.size() == 3, "a convex shape's hull")
	var polygon := CollisionPolygon3D.new()
	polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(0, 2)])
	polygon.depth = 1.0
	var holder := StaticBody3D.new()
	holder.add_child(polygon)
	root.add_child(holder)
	check(PropObstructions.of_3d(holder).size() == 1, "a CollisionPolygon3D counts")


func test_disabled_and_unknown_shapes_are_skipped() -> void:
	var body := _prop_3d(_cylinder())
	(body.get_child(0) as CollisionShape3D).disabled = true
	check(PropObstructions.of_3d(body).is_empty(), "a disabled shape cuts nothing")
	var plane := _prop_3d(WorldBoundaryShape3D.new())
	check(PropObstructions.of_3d(plane).is_empty(), "a world boundary is level geometry, not a prop")


func test_2d_shapes_and_polygons() -> void:
	var circle := PropObstructions.of_2d(_prop_2d(_circle(10.0), Vector2(100, 50)), 8)[0]
	check(circle.outline.size() == 8, "a circle is a ring")
	check(near(circle.outline[0].distance_to(Vector2(100, 50)), 10.0, 0.001), "of its radius")
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 10)
	check(PropObstructions.of_2d(_prop_2d(box))[0].rect().size.is_equal_approx(Vector2(20, 10)), "a rectangle")
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 30.0
	var c := PropObstructions.of_2d(_prop_2d(capsule), 8)[0].rect()
	check(near(c.size.y, 30.0, 0.001) and near(c.size.x, 10.0, 0.001), "a capsule is its height tall (%s)" % c.size)
	var body := StaticBody2D.new()
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(30, 10), Vector2(10, 10), Vector2(10, 30), Vector2(0, 30)])
	body.add_child(polygon)
	root.add_child(body)
	check(PropObstructions.of_2d(body)[0].outline.size() == 6, "a concave polygon keeps its outline")


func test_merging_closes_only_narrow_gaps() -> void:
	var list: Array[PropObstruction] = []
	for x in [0.0, 2.5, 5.0]:
		list.append_array(PropObstructions.of_3d(_prop_3d(_cylinder(1.0), Vector3(x, 0, 0)), 8))
	list.append_array(PropObstructions.of_3d(_prop_3d(_cylinder(1.0), Vector3(20.0, 0, 0)), 8))
	var merged := PropObstructions.merged(list, 1.0)
	check(merged.size() == 2, "three trunks 0.5 apart are one; a far one stays apart (%d)" % merged.size())
	var joined := merged[0] if merged[0].rect().size.x > 4.0 else merged[1]
	check(Geometry2D.is_point_in_polygon(Vector2(1.25, 0.0), joined.outline), "the narrow gap is closed")
	check(not Geometry2D.is_point_in_polygon(Vector2(2.5, 1.6), joined.outline), "nothing beyond the trunks is covered")
	check(PropObstructions.merged(list, 0.0).size() == 4, "gap 0 merges nothing")


func test_merging_keeps_wide_passages() -> void:
	# A ring of trunks around a clearing, one trunk missing: the narrow gaps close, the wide
	# opening stays, so the clearing is not covered.
	var open: Array[PropObstruction] = []
	var closed: Array[PropObstruction] = []
	for i in 12:
		var angle := TAU * i / 12.0
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 6.0
		var ring := PropObstructions.of_3d(_prop_3d(_cylinder(1.0), at), 8)
		closed.append_array(ring)
		if i != 0:
			open.append_array(ring)
	check(not _covers(PropObstructions.merged(open, 2.0), Vector2.ZERO), "an open ring keeps its clearing")
	check(_covers(PropObstructions.merged(closed, 2.0), Vector2.ZERO), "a closed ring fills it (nobody can get in)")
	var wide: Array[PropObstruction] = []
	wide.append_array(PropObstructions.of_3d(_prop_3d(_cylinder(1.0), Vector3(0, 0, 0)), 8))
	wide.append_array(PropObstructions.of_3d(_prop_3d(_cylinder(1.0), Vector3(5, 0, 0)), 8))
	check(PropObstructions.merged(wide, 2.0).size() == 2, "a passage of 3 with gap 2 stays open")


func _covers(list: Array[PropObstruction], point: Vector2) -> bool:
	for o in list:
		if Geometry2D.is_point_in_polygon(point, o.outline):
			return true
	return false


func test_within_filters_and_area_of() -> void:
	var a := _prop_3d(_cylinder(), Vector3(5, 0, 5))
	var b := _prop_3d(_cylinder(), Vector3(50, 0, 50))
	var nodes := PropObstructions.nodes_under(root)
	check(nodes.size() == 2, "the group's nodes under a root")
	var within: Array[Rect2] = [Rect2(0, 0, 10, 10)]
	check(PropObstructions.gather(nodes, true, 6, within).size() == 1, "only the one near the rect")
	check(PropObstructions.gather(nodes, true, 6).size() == 2, "all with no rect")
	check(PropObstructions.area_of(b, true).has_point(Vector2(50, 50)), "area_of gives where it stands")
	var bare := Node3D.new()
	check(not PropObstructions.area_of(bare, true).has_area(), "no shape, no area")
	bare.free()
	a.free()


func test_the_fingerprint_follows_the_props() -> void:
	var one := PropObstructions.of_3d(_prop_3d(_cylinder(), Vector3(1, 0, 1)))
	var two := PropObstructions.of_3d(_prop_3d(_cylinder(), Vector3(9, 0, 9)))
	var ab: Array[PropObstruction] = one + two
	var ba: Array[PropObstruction] = two + one
	check(PropObstructions.fingerprint(ab) == PropObstructions.fingerprint(ba), "order does not matter")
	var moved := PropObstructions.of_3d(_prop_3d(_cylinder(), Vector3(9.02, 0, 9)))
	var am: Array[PropObstruction] = one + moved
	check(PropObstructions.fingerprint(ab) != PropObstructions.fingerprint(am), "2 cm moves it")
	check(PropObstructions.fingerprint(one) != PropObstructions.fingerprint(ab), "one prop fewer changes it")
