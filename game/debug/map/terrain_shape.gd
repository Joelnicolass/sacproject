extends Node

## Peaks' GroundSurface against the ground index made straight from its data (TerrainRules): 4096 grid points over the
## ground's box (plus a margin, so the rim and the holes are asked) and 64 seeded random points. PASS when every height is the same float (max delta 0), a
## point has a height exactly where `is_on_ground` says so, and the thread-safe sampler answers like `height_at`.
## Prints one line `TERRAIN SHAPE PASS|FAIL ...` and, with `quit_when_done`, quits. Headless: Godot --headless --path game
## res://debug/map/terrain_shape.tscn

@export var shape: GroundSurface
@export_range(1, 128) var grid := 64
@export var random_points := 64
@export var random_seed := 7
## Meters around the box of the ground that are asked too.
@export var margin_m := 40.0
@export var quit_when_done := true


func _ready() -> void:
	var failures := 0
	if shape == null or not shape.is_loaded():
		print("TERRAIN SHAPE FAIL no ground loaded")
		_finish(1)
		return
	var index := TerrainRules.index(shape.data)
	var sampler := shape.sampler()
	var points := _points(_box(shape.data))
	var max_delta := 0.0
	var holes := 0
	for point in points:
		var expected := TerrainRules.height_in(point.x, point.y, index.ground, index.cells)
		var found := shape.height_at(point.x, point.y)
		if is_nan(expected) != is_nan(found) or is_nan(expected) != not shape.is_on_ground(point.x, point.y):
			failures += 1
		elif is_nan(expected):
			holes += 1
		else:
			max_delta = maxf(max_delta, absf(found - expected))
		if not is_same(float(sampler.call(point.x, point.y)), found) and not is_nan(found):
			failures += 1
	if max_delta != 0.0 or shape.lowest() != index.lowest:
		failures += 1
	print("TERRAIN SHAPE %s points=%d holes=%d max_delta=%s lowest=%.2f" % ["PASS" if failures == 0 else "FAIL", points.size(), holes, max_delta, shape.lowest()])
	_finish(0 if failures == 0 else 1)


## The box (x, z) of the ground's vertices, grown by `margin_m`.
func _box(data: MapTerrainData) -> Rect2:
	var box := Rect2(Vector2(data.vertices[0].x, data.vertices[0].z), Vector2.ZERO)
	for vertex in data.vertices:
		box = box.expand(Vector2(vertex.x, vertex.z))
	return box.grow(margin_m)


## The grid (cell centres of a grid x grid lattice over `box`) and the seeded random points, as (x, z).
func _points(box: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for z in grid:
		for x in grid:
			points.append(box.position + box.size * Vector2((x + 0.5) / grid, (z + 0.5) / grid))
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in random_points:
		points.append(box.position + box.size * Vector2(rng.randf(), rng.randf()))
	return points


func _finish(code: int) -> void:
	if quit_when_done:
		get_tree().quit(code)
