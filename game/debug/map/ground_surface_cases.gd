extends "res://debug/map/ground_dump.gd"

## 063-1 parity: the ground answers EXACTLY as before the rename. Dumps height_at / is_on_ground at 10 000 seeded points on each
## of the 9 maps with the code as it is now and compares them, bit by bit, with the dump taken before the cut
## (debug/map/ground_dump_before.json, made by ground_dump.gd on the old code). It also checks the new answers of the surface
## (bounds, normal_at, the field's version, size and cell) on every map. Always quits, 120 s at most.
## Run: Godot --headless --path game --script res://debug/map/ground_surface_cases.gd   (prints GROUND DUMP PASS / FAIL)


func _default_label() -> String:
	return "after"


func _default_compare() -> String:
	return "res://debug/map/ground_dump_before.json"


## The surface of a grid map: 2560 m on a side, a lattice of 256 x 256 every 10 m, no change yet, normals up.
func _extra_checks(tag: String, surface: Node) -> bool:
	var checks := {}
	var bounds: Rect2 = surface.call("bounds")
	checks["bounds"] = bounds == Rect2(0.0, 0.0, 2560.0, 2560.0)
	var field: Object = surface.call("field")
	checks["field"] = field.get("size") == Vector2i(256, 256) and field.get("cell_m") == 10.0
	checks["fresh"] = int(field.get("version")) == 0
	var off: Vector3 = surface.call("normal_at", -50.0, -50.0)
	checks["off_map_up"] = off == Vector3.UP
	var checked := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in POINTS:
		var x := rng.randf_range(0.0, 2560.0)
		var z := rng.randf_range(0.0, 2560.0)
		if not bool(surface.call("is_on_ground", x, z)):
			continue
		var normal: Vector3 = surface.call("normal_at", x, z)
		if not is_equal_approx(normal.length(), 1.0) or normal.y <= 0.0:
			checks["land_normal"] = false
			break
		checked += 1
		if checked >= 500:
			break
	checks["land_normal"] = checks.get("land_normal", checked > 0)
	var bad := checks.keys().filter(func(key: Variant) -> bool: return not checks[key])
	if not bad.is_empty():
		printerr("ground_surface_cases: %s failed %s" % [tag, bad])
	return bad.is_empty()
