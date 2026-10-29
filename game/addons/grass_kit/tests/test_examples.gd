extends "res://addons/grass_kit/tests/grass_test.gd"

## The example runs: it reads its hills' height, draws cells, takes another quality and another
## look, turns the grass off and on, and a crater changes only the grass's ground there.


func _key(scene: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	scene.call(&"_unhandled_input", event)


func test_grass_3d_runs() -> void:
	GrassField3D.draw_anywhere = true
	var scene := (load("res://addons/grass_kit/examples/grass_3d/grass_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var field: GrassField3D = scene.get(&"field")
	var hills: Node3D = scene.get(&"hills")
	for i in 10:
		await tree.process_frame
	check(field.ground.data != null, "it baked its ground from the hills")
	check(near(field.ground.height_at(Vector2(4, 7)), hills.call(&"height_at", 4.0, 7.0), 0.1), "the hills' height")
	check(field.ground.slope_keep(Vector2(33.5, -25)) < 0.05, "no grass on the steep mound's side (%.0f°)" % field.ground.slope_at(Vector2(33.5, -25)))
	check(field.stats.cells > 0 and field.stats.blades > 0, "cells drawn: %s" % field.stats)
	var medium := field.stats.blades
	_key(scene, KEY_1)
	for i in 3:
		await tree.process_frame
	check(field.stats.blades < medium, "1: the low quality draws fewer (%d < %d)" % [field.stats.blades, medium])
	var summer := field.look
	_key(scene, KEY_L)
	check(field.look != summer and field.look == scene.get(&"autumn"), "L: the autumn look")
	_key(scene, KEY_G)
	await tree.process_frame
	check(not field.enabled and field.get_child_count(true) == 0, "G: off, no cells")
	_key(scene, KEY_G)
	for i in 3:
		await tree.process_frame
	check(field.stats.cells > 0, "G again: back")
	var before := field.ground.height_at(Vector2(10, 10))
	var other := field.ground.height_at(Vector2(-40, -40))
	await scene.call(&"dig_at", Vector3(10, before, 10))
	check(field.ground.height_at(Vector2(10, 10)) < before - 2.0, "the crater is lower (%.2f -> %.2f)" % [before, field.ground.height_at(Vector2(10, 10))])
	check(near(field.ground.height_at(Vector2(-40, -40)), other), "the rest as it was")
	GrassField3D.draw_anywhere = false
