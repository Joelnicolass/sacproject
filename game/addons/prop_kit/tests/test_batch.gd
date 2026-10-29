extends "res://addons/prop_kit/tests/prop_test.gd"

## PropBatch3D: batches by kind of part and square, hides the parts, follows props that go.

var trunk_mesh := CylinderMesh.new()
var crown_mesh := SphereMesh.new()


func _props(count: int, step: float) -> Node3D:
	var parent := Node3D.new()
	parent.name = "Forest"
	root.add_child(parent)
	for i in count:
		var prop := Node3D.new()
		prop.name = "Tree%d" % i
		prop.position = Vector3(i * step, 0.0, 0.0)
		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		prop.add_child(trunk)
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.position.y = 2.0
		prop.add_child(crown)
		parent.add_child(prop)
	return parent


func _batch(parent: Node3D, build := true) -> PropBatch3D:
	var batch := PropBatch3D.new()
	batch.props = [parent]
	batch.chunk_size = 50.0
	batch.build_on_ready = build
	root.add_child(batch)
	return batch


func test_parts_are_batched_by_kind_and_square() -> void:
	PropBatch3D.draw_anywhere = true
	var parent := _props(10, 10.0)
	var batch := _batch(parent)
	check(batch.batch_count() == 4, "two kinds of part in two squares (%d)" % batch.batch_count())
	check(batch.instance_count() == 20, "every part drawn once (%d)" % batch.instance_count())
	var trunk := parent.get_child(3).get_child(0) as MeshInstance3D
	check(not trunk.visible, "the part itself is hidden")
	batch.clear()
	check(trunk.visible and batch.batch_count() == 0, "clear shows it again")
	PropBatch3D.draw_anywhere = false


func test_a_prop_that_goes_is_drawn_out() -> void:
	PropBatch3D.draw_anywhere = true
	var parent := _props(10, 10.0)
	var batch := _batch(parent)
	parent.get_child(0).queue_free()
	await tree.process_frame
	await tree.process_frame
	check(batch.instance_count() == 18, "two parts fewer (%d)" % batch.instance_count())
	var hidden := parent.get_child(1) as Node3D
	hidden.visible = false
	batch.refresh(hidden)
	await tree.process_frame
	check(batch.instance_count() == 16, "a hidden prop is drawn out after refresh")
	PropBatch3D.draw_anywhere = false


func test_mesh_of_picks_another_look() -> void:
	PropBatch3D.draw_anywhere = true
	var parent := _props(4, 1.0)
	var batch := _batch(parent, false)
	var other := BoxMesh.new()
	batch.mesh_of = func(_prop: Node3D, part: MeshInstance3D) -> Mesh:
		return other if part.mesh == crown_mesh else null
	batch.rebuild_all()
	var meshes := []
	for child in batch.get_children(true):
		if child is MultiMeshInstance3D:
			meshes.append((child as MultiMeshInstance3D).multimesh.mesh)
	check(meshes.has(other) and meshes.has(trunk_mesh), "the crown drawn as the other mesh")
	check(not meshes.has(crown_mesh), "the own crown mesh is not drawn")
	PropBatch3D.draw_anywhere = false


func test_surface_overrides_are_left_alone() -> void:
	PropBatch3D.draw_anywhere = true
	var parent := _props(2, 1.0)
	var trunk := parent.get_child(0).get_child(0) as MeshInstance3D
	trunk.set_surface_override_material(0, StandardMaterial3D.new())
	var batch := _batch(parent)
	check(batch.instance_count() == 3, "three parts batched, the overridden one not")
	check(trunk.visible, "and it still shows itself")
	PropBatch3D.draw_anywhere = false


func test_nothing_without_a_display() -> void:
	PropBatch3D.draw_anywhere = false
	var batch := _batch(_props(4, 1.0))
	check(not PropBatch3D.can_draw(), "headless: no drawing")
	check(batch.batch_count() == 0, "so no batch is made")
