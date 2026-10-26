extends SceneTree

## Checks the ground brushes without a window: raise follows the drag and ends at 0 on the brush's edge, smoothing calms
## a noisy patch, Shift + smooth flattens to the height where the stroke began, void paint matches the brush's shape and
## Shift fills it back with the old height, and a stroke's before and after patches undo and redo it exactly, all on a
## lattice of brush_bed.gd (flat ground). Not: the editor plugin, the mesh refresh, the 300 ms rebuild.
## "$GODOT" --headless --path game --script res://debug/terrain/brush_cases.gd

const Bed := preload("res://debug/terrain/brush_bed.gd")

var _failed := 0


func _initialize() -> void:
	_raise()
	_smooth()
	_flatten()
	_void()
	_patches()
	print("BRUSH CASES %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)


## +100 px at 0.1 m/px with a 50 m brush: the centre rises 10 m, the vertex 50 m away does not move; heights clamp.
func _raise() -> void:
	var heights := Bed.flat()
	var mask := Bed.land()
	var center := TerrainGrid.point_of(Vector2i(128, 128))
	var stroke := _stroke(heights, mask, BrushStroke.Mode.RAISE, Bed.brush(50.0, 0.5, TerrainBrush.Shape.CIRCLE), center)
	stroke.drag(center, 100.0)
	_check(absf(Bed.at(heights, 128, 128) - Bed.BASE_M - 10.0) <= 0.01, "raise: the centre rises 10 m")
	_check(Bed.at(heights, 133, 128) == Bed.BASE_M and Bed.at(heights, 128, 123) == Bed.BASE_M, "raise: 0 at the brush's edge")
	stroke.drag(center, -1e6)
	_check(Bed.at(heights, 128, 128) == 0.0, "raise: never below 0 m")
	stroke.drag(center, 1e9)
	_check(is_equal_approx(Bed.at(heights, 128, 128), BrushRules.MAX_HEIGHT_M), "raise: never above the PNG16 ceiling")


## Ten smoothing drags over a noisy patch cut its variance by at least half.
func _smooth() -> void:
	var heights := Bed.noisy(Bed.flat(), Vector2i(64, 64), 12)
	var center := TerrainGrid.point_of(Vector2i(64, 64))
	var patch := TerrainGrid.vertex_rect(center, 30.0)
	var before := Bed.variance(heights, patch)
	var brush := Bed.brush(70.0, 0.0, TerrainBrush.Shape.SQUARE)
	var stroke := _stroke(heights, Bed.land(), BrushStroke.Mode.SMOOTH, brush, center)
	for _pass in 10:
		stroke.drag(center, 0.0)
	_check(Bed.variance(heights, patch) <= before * 0.5, "smooth: 10 passes halve the variance")


## Shift + smooth along a drag: every vertex in the hard core of any dab ends at the start height.
func _flatten() -> void:
	var heights := Bed.noisy(Bed.flat(), Vector2i(64, 192), 12)
	var start := TerrainGrid.point_of(Vector2i(64, 192))
	var brush := Bed.brush(50.0, 0.4, TerrainBrush.Shape.CIRCLE)
	var stroke := _stroke(heights, Bed.land(), BrushStroke.Mode.FLATTEN, brush, start)
	var target := Bed.at(heights, 64, 192)
	var dabs: Array[Vector2] = [start, start + Vector2(20.0, 0.0), start + Vector2(40.0, 5.0)]
	for dab in dabs:
		stroke.drag(dab, 0.0)
	var core_m := brush.size_m * (1.0 - brush.falloff)
	var worst := 0.0
	for id in BrushRules.ids(stroke.dirty_rect()):
		for dab in dabs:
			if TerrainGrid.point_of(TerrainGrid.vertex_of(id)).distance_to(dab) <= core_m:
				worst = maxf(worst, absf(heights[id] - target))
	_check(worst <= 1e-4, "flatten: the core ends at the start height (worst %.6f m)" % worst)


## Void paint is exactly the brush's shape for every shape, heights untouched; Shift fills it back.
func _void() -> void:
	for shape: TerrainBrush.Shape in [TerrainBrush.Shape.CIRCLE, TerrainBrush.Shape.SQUARE, TerrainBrush.Shape.CROSS]:
		var heights := Bed.noisy(Bed.flat(), Vector2i(190, 60), 10)
		var mask := Bed.land()
		var old_sum := Bed.checksum(heights, mask)
		var center := TerrainGrid.point_of(Vector2i(190, 60))
		var brush := Bed.brush(40.0, 0.0, shape)
		var label: String = TerrainBrush.Shape.keys()[shape]
		_stroke(heights, mask, BrushStroke.Mode.VOID, brush, center).drag(center, 0.0)
		var exact := true
		for id in TerrainGrid.COUNT:
			var inside := Bed.inside(shape, TerrainGrid.point_of(TerrainGrid.vertex_of(id)) - center, brush.size_m)
			exact = exact and (mask[id] == 1) == inside
		_check(exact, "void: the mask is the %s exactly" % label)
		_stroke(heights, mask, BrushStroke.Mode.FILL, brush, center).drag(center, 0.0)
		_check(Bed.checksum(heights, mask) == old_sum, "void: Shift fills the %s back, old height kept" % label)


## A stroke of several dabs (raise, then void): writing `before` gives back the old checksum, `after` the new one.
func _patches() -> void:
	var heights := Bed.noisy(Bed.flat(), Vector2i(100, 100), 15)
	var mask := Bed.land()
	var brush := Bed.brush(45.0, 0.6, TerrainBrush.Shape.CROSS)
	var start := TerrainGrid.point_of(Vector2i(100, 100))
	for mode: BrushStroke.Mode in [BrushStroke.Mode.RAISE, BrushStroke.Mode.VOID]:
		var old_sum := Bed.checksum(heights, mask)
		var stroke := _stroke(heights, mask, mode, brush, start)
		for step in 5:
			stroke.drag(start + Vector2(13.0 * step, 7.0 * step), 30.0)
		var new_sum := Bed.checksum(heights, mask)
		var result := stroke.finish()
		(result["before"] as BrushStroke.Patch).write(heights, mask)
		var undone := Bed.checksum(heights, mask) == old_sum
		(result["after"] as BrushStroke.Patch).write(heights, mask)
		var redone := Bed.checksum(heights, mask) == new_sum and new_sum != old_sum
		_check(undone and redone, "patches: undo and redo %s exactly" % BrushStroke.Mode.keys()[mode])


func _stroke(heights: PackedFloat32Array, mask: PackedByteArray, mode: BrushStroke.Mode, brush: TerrainBrush, at: Vector2) -> BrushStroke:
	var stroke := BrushStroke.new()
	stroke.begin(heights, mask, mode, brush, at)
	return stroke


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
