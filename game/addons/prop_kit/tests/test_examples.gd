extends "res://addons/prop_kit/tests/prop_test.gd"

## Both examples run: they scatter, draw (3D), bake in zones, answer a path, chop and re-bake
## only the touched zones, and scatter anew.


func _until(condition: Callable, frames := 900) -> bool:
	for i in frames:
		if condition.call():
			return true
		await tree.process_frame
	return condition.call()


func _quiet(zones: Node) -> bool:
	return zones.call(&"is_done") and not zones.call(&"has_result")


func test_forest_3d_runs() -> void:
	PropBatch3D.draw_anywhere = true
	var scene := (load("res://addons/prop_kit/examples/forest_3d/forest_3d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var scatter: PropScatter3D = scene.get(&"scatter")
	var batch: PropBatch3D = scene.get(&"batch")
	var zones: PropNavZones3D = scene.get(&"zones")
	check(scatter.get_child_count() > 300, "a forest is scattered (%d)" % scatter.get_child_count())
	check(batch.batch_count() > 0 and batch.instance_count() > 600, "drawn in batches (%d)" % batch.batch_count())
	check(await _until(func() -> bool: return zones.index != null and _quiet(zones)), "baked: %s" % zones.stats)
	check(zones.stats.zones_baked == 16, "every zone the first time")
	check(zones.index.same_component(Vector3(0, 0, 0), Vector3(-45, 0, 40)), "the camps are reachable from each other")
	var count := scatter.get_child_count()
	var chopped: int = scene.call(&"chop_at", Vector3(30.0, 0.0, 30.0))
	if chopped == 0:
		chopped = scene.call(&"chop_at", (scatter.get_child(0) as Node3D).global_position)
	check(chopped > 0, "C chops props around a point (%d)" % chopped)
	await tree.process_frame
	check(await _until(func() -> bool: return _quiet(zones) and zones.stats.zones_baked < 16), "re-baked")
	check(zones.stats.zones_baked < 16 and zones.stats.parse_ms == 0.0, "only the touched zones, no parse: %s" % zones.stats)
	check(scatter.get_child_count() == count - chopped, "the chopped props are gone")
	var first := (scatter.get_child(0) as Node3D).global_position
	scene.call(&"new_forest")
	check((scatter.get_child(0) as Node3D).global_position != first, "R scatters another forest")
	check(await _until(func() -> bool: return _quiet(zones) and zones.stats.zones_baked == 16), "and bakes it all")
	PropBatch3D.draw_anywhere = false


func test_grove_2d_runs() -> void:
	var scene := (load("res://addons/prop_kit/examples/grove_2d/grove_2d.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var scatter: PropScatter2D = scene.get(&"scatter")
	var zones: PropNavZones2D = scene.get(&"zones")
	check(scatter.get_child_count() > 100, "a grove is scattered (%d)" % scatter.get_child_count())
	var on_wall := 0
	for bush: Node2D in scatter.get_children():
		if Rect2(250, 188, 300, 24).grow(10.0).has_point(bush.global_position):
			on_wall += 1
	check(on_wall == 0, "the example's own ground keeps bushes off the walls")
	check(await _until(func() -> bool: return zones.index != null and _quiet(zones)), "baked: %s" % zones.stats)
	check(zones.index.same_component_2d(Vector2(640, 360), Vector2(110, 110)), "the camps are reachable")
	var bush := scatter.get_child(0) as Node2D
	var cleared: int = scene.call(&"clear_at", bush.global_position)
	check(cleared > 0, "C clears bushes")
	await tree.process_frame
	check(await _until(func() -> bool: return _quiet(zones) and zones.stats.zones_baked < 12), "re-baked only near them: %s" % zones.stats)
