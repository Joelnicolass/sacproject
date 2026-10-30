extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsSelection: click, Shift, Ctrl / double click by kind and radius, the box (3D with occlusion, 2D),
## the limit and its push, the groups, and units that stop being selectable.

var selection: RtsSelection


func _setup(flat := false) -> void:
	selection = RtsSelection.new()
	root.add_child(selection)
	if not flat:
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 40, 0))
		camera.current = true


func _unit(at: Vector3, kind := &"soldier", slot := 1, flat := false) -> RtsUnit:
	var body: Node = Node2D.new() if flat else Node3D.new()
	root.add_child(body)
	RtsSpace.place(body, at)
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	unit.kind = kind
	body.add_child(unit)
	return unit


func _screen(unit: RtsUnit) -> Vector2:
	return RtsSpace.screen_of(root.get_viewport(), unit.center_point(), unit.is_2d())


func test_click_shift_and_newest_first() -> void:
	_setup()
	var a := _unit(Vector3(0, 0, 0))
	var b := _unit(Vector3(5, 0, 0))
	var foe := _unit(Vector3(9, 0, 0), &"soldier", 2)
	var changes: Array = []
	selection.changed.connect(func(units: Array[RtsUnit]) -> void: changes.append(units))
	selection.click(a, Vector2(100, 100), false, false)
	check(selection.units() == [a] and a.selected, "a click selects that unit")
	selection.click(b, Vector2(400, 400), true, false)
	check(selection.units() == [b, a], "Shift adds it in front (newest first)")
	selection.click(a, Vector2(700, 100), true, false)
	check(selection.units() == [b] and not a.selected, "Shift on a selected one takes it out")
	selection.click(foe, Vector2(0, 0), false, false)
	check(selection.units() == [b], "another player's unit cannot be selected")
	check(changes.size() == 3 and selection.count == 1, "changed fired each time")


func test_ctrl_and_double_click_pick_the_kind_nearby() -> void:
	_setup()
	selection.same_type_radius = 10.0
	var a := _unit(Vector3(0, 0, 0))
	var near_one := _unit(Vector3(3, 0, 0))
	var far_one := _unit(Vector3(30, 0, 0))
	var archer := _unit(Vector3(1, 0, 0), &"archer")
	var other := _unit(Vector3(2, 0, 0), &"soldier", 2)
	selection.click(a, Vector2(10, 10), false, true)
	check(selection.units() == [a, near_one], "Ctrl: the same kind within the radius, closest first")
	check(not selection.has(far_one) and not selection.has(archer) and not selection.has(other), "not far, not another kind, not another player's")
	selection.clear()
	selection.click(a, Vector2(10, 10), false, false)
	selection.click(a, Vector2(12, 11), false, false)
	check(selection.units() == [a, near_one], "a double click does the same")
	selection.click(archer, Vector2(500, 500), true, true)
	check(selection.units() == [archer, a, near_one], "Ctrl+Shift adds them in front")
	selection.double_click_s = -1.0
	selection.click(a, Vector2(10, 10), false, false)
	selection.click(a, Vector2(10, 10), false, false)
	check(selection.units() == [a], "two clicks further apart than double_click_s are two clicks")
	selection.double_click_s = 10.0
	selection.click(a, Vector2(10, 10), false, false)
	selection.click(near_one, Vector2(300, 300), false, false)
	check(selection.units() == [near_one], "a second click on another unit far away is a plain click")


func test_box_3d_with_occlusion() -> void:
	_setup()
	var inside := _unit(Vector3(0, 0, 0))
	var also := _unit(Vector3(2, 0, 2))
	var outside := _unit(Vector3(30, 0, 30))
	var foe := _unit(Vector3(1, 0, 1), &"soldier", 2)
	var center := _screen(inside)
	selection.select_rect(center - Vector2(80, 80), center + Vector2(80, 80), false)
	check(selection.has(inside) and selection.has(also), "own units inside the box")
	check(not selection.has(outside) and not selection.has(foe), "not outside, not another player's")
	check(selection.units()[0].get_instance_id() > selection.units()[1].get_instance_id(), "newest first")
	selection.select_rect(_screen(outside) - Vector2(5, 5), _screen(outside) + Vector2(5, 5), true)
	check(selection.size() == 3 and selection.units()[0] == outside, "Shift adds the box in front")
	# A roof between the camera and `inside` hides it from the box.
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 0.5, 1)
	shape.shape = box
	roof.add_child(shape)
	roof.collision_layer = 1
	root.add_child(roof)
	roof.global_position = Vector3(0, 20, 0)
	await physics()
	selection.occluder_mask = 1
	selection.select_rect(center - Vector2(80, 80), center + Vector2(80, 80), false)
	check(not selection.has(inside) and selection.has(also), "a body on the occluder mask in front hides a unit")


func test_box_2d() -> void:
	_setup(true)
	var a := _unit(Vector3(100, 0, 100), &"soldier", 1, true)
	var b := _unit(Vector3(150, 0, 120), &"soldier", 1, true)
	var c := _unit(Vector3(600, 0, 400), &"soldier", 1, true)
	check(near(_screen(a), Vector2(100, 100)), "a 2D unit projects through the canvas")
	selection.select_rect(Vector2(50, 50), Vector2(200, 200), false)
	check(selection.has(a) and selection.has(b) and not selection.has(c), "the 2D box")


func test_max_size_pushes_the_oldest_out() -> void:
	_setup()
	selection.max_size = 2
	var a := _unit(Vector3(0, 0, 0))
	var b := _unit(Vector3(1, 0, 0))
	var c := _unit(Vector3(2, 0, 0))
	selection.click(a, Vector2(0, 0), false, false)
	selection.click(b, Vector2(300, 0), true, false)
	selection.click(c, Vector2(600, 0), true, false)
	check(selection.units() == [c, b], "the newest in front pushes the last out")
	selection.select_only([a, b, c])
	check(selection.units() == [a, b], "select_only keeps the first two")


func test_groups() -> void:
	_setup()
	selection.new_units_group = 9
	var a := _unit(Vector3(0, 0, 0))
	var b := _unit(Vector3(1, 0, 0))
	var c := _unit(Vector3(2, 0, 0))
	selection.select_only([a, b])
	selection.define_group(0)
	selection.clear()
	check(selection.select_group(0) and selection.units() == [a, b], "Ctrl+1 then 1")
	check(not selection.select_group(1) and selection.units() == [a, b], "an empty group changes nothing")
	selection.select_only([c])
	selection.extend_group(0)
	check(selection.group(0) == [a, b, c] and selection.units() == [a, b, c], "Shift+1 adds the selection and selects the group")
	selection.add_new(_unit(Vector3(3, 0, 0)))
	var fresh := selection.units()[0]
	check(selection.group(9) == [fresh] and selection.has(fresh), "a new unit joins the new-units group and the selection")
	selection.select_only([fresh])
	selection.define_group(1)
	check(selection.group(9).is_empty(), "defining another group takes it out of the new-units group")
	selection.drop(a)
	check(not selection.group(0).has(a), "drop: out of every group")


func test_a_unit_that_stops_being_selectable_leaves() -> void:
	_setup()
	var a := _unit(Vector3(0, 0, 0))
	var b := _unit(Vector3(1, 0, 0))
	selection.select_only([a, b])
	selection.define_group(2)
	var changes: Array = []
	selection.changed.connect(func(units: Array[RtsUnit]) -> void: changes.append(units))
	a.selectable = false
	await tree.process_frame
	await tree.process_frame
	check(changes.size() == 1 and changes[0] == [b], "changed fired by itself (no one asked)")
	check(selection.units() == [b] and not a.selected, "it left the selection")
	check(selection.group(2) == [b], "and its groups")
	b.get_parent().queue_free()
	await tree.process_frame
	check(selection.is_empty(), "a freed unit leaves too")
