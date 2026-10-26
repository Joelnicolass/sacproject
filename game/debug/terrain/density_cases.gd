extends SceneTree

## Checks the flora brush without a window (plan 066d):
##  - DensityCanvas over a blank 320² L8 picture of 8 m: a hard dab (density 1, flow 1, falloff 0, 40 m) leaves 255 on
##    every pixel whose centre is inside it (78 ± 8) and 0 elsewhere; Shift (ERASE) at the same spot leaves all 0; the
##    stroke's before and after patches put the picture back and forth byte for byte;
##  - FloraDensity.with_layer_bytes: a new snapshot with that layer's bytes (6 plants a white pixel), the old one unchanged,
##    the same snapshot back for a layer it does not hold;
##  - MeshPlanter.set_flora + replan: the planter takes the new snapshot (the painted cell now plans plants) and a replan
##    of the painted area queues exactly the 32 m cells that touch it.
## Prints DENSITY CASES PASS or FAIL. Needs the project imported once (test_flat's heights, the fern species).
## Not: the editor (creating the PNG, undo, saving: agent/editor/paint_probe.gd).
## "$GODOT" --headless --path game --script res://debug/terrain/density_cases.gd

const Bed := preload("res://debug/terrain/brush_bed.gd")
const Maps := preload("res://debug/look/flora_test_maps.gd")
const SIDE := 320
const CELL_M := 8.0
const SPOT := Vector2(1301.3, 1298.7)
const SIZE_M := 40.0
const MAX_PER_CELL := 6
const SPECIES := "res://data/vegetation/species/persephone_fern_1.tres"
const CONFIG := "res://data/look/vegetation/original_plants.tres"
const QUALITY := "res://data/look/quality_high.tres"
const HEIGHTS := "res://scenes/map/maps/test_flat/heights.png"

var _failed := PackedStringArray()


func _initialize() -> void:
	var painted := _canvas()
	_snapshot_and_planter(painted)
	for name in _failed:
		print("  FAIL ", name)
	print("DENSITY CASES %s" % ("PASS" if _failed.is_empty() else "FAIL (%d)" % _failed.size()))
	quit(0 if _failed.is_empty() else 1)


func _check(name: String, ok: bool) -> void:
	if not ok:
		_failed.append(name)


## Paints, erases and undoes on a canvas over plain bytes; returns the painted picture.
func _canvas() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(SIDE * SIDE)
	var canvas := DensityCanvas.over(bytes, Vector2i(SIDE, SIDE), CELL_M)
	var brush := Bed.brush(SIZE_M, 0.0, TerrainBrush.Shape.CIRCLE)
	brush.flow = 1.0
	brush.density = 1.0
	var stroke := BrushStroke.new()
	stroke.begin(canvas, DensityCanvas.Mode.PAINT, brush, SPOT)
	stroke.drag(SPOT, 0.0)
	var done := stroke.finish()
	var inside := 0
	var exact := true
	for y in SIDE:
		for x in SIDE:
			var near := ((Vector2(x, y) + Vector2(0.5, 0.5)) * CELL_M).distance_to(SPOT) < SIZE_M
			inside += 1 if near else 0
			exact = exact and canvas.work()[y * SIDE + x] == (255 if near else 0)
	_check("a hard dab leaves 255 inside and 0 outside", exact)
	_check("a dab of 40 m paints 78 ± 8 pixels (%d)" % inside, absi(inside - 78) <= 8)
	var painted := canvas.work().duplicate()
	canvas.write(done["before"])
	_check("undo puts the blank picture back", canvas.work().count(0) == SIDE * SIDE)
	canvas.write(done["after"])
	_check("redo paints it again", canvas.work() == painted)
	var erase := BrushStroke.new()
	erase.begin(canvas, DensityCanvas.Mode.ERASE, brush, SPOT)
	erase.drag(SPOT, 0.0)
	erase.finish()
	_check("Shift erases the same spot to 0", canvas.work().count(0) == SIDE * SIDE)
	return painted


func _snapshot_and_planter(painted: PackedByteArray) -> void:
	var blank := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_L8)
	var layer := FloraLayer.new()
	layer.species = load(SPECIES) as VegetationSpecies
	layer.density = ImageTexture.create_from_image(blank)
	layer.cell_m = CELL_M
	layer.max_per_cell = MAX_PER_CELL
	var before := FloraDensity.from_layers([layer])
	var id := layer.get_instance_id()
	_check("the snapshot knows its layer", before.layer_ids == PackedInt64Array([id]))
	var after := before.with_layer_bytes(id, painted)
	var whites := painted.count(255)
	_check("with_layer_bytes: the new snapshot has the painting", after != before and after.tag_total(0) == whites * MAX_PER_CELL)
	_check("with_layer_bytes: the old snapshot is unchanged", before.tag_total(0) == 0)
	_check("with_layer_bytes: another layer gives the same snapshot", before.with_layer_bytes(id + 1, painted) == before)
	_planter(before, after)
	layer.free()


## A planter on test_flat's ground around SPOT: set_flora swaps the snapshot; replan queues only the cells it touches.
func _planter(before: FloraDensity, after: FloraDensity) -> void:
	var heights := load(HEIGHTS) as TerrainHeights
	var config := load(CONFIG) as VegetationLayerConfig
	var quality := (load(QUALITY) as LookQuality).vegetation_for(config.id)
	if heights == null or config == null or quality == null:
		_check("test_flat heights, the plants config and the high preset load", false)
		return
	var land := Maps.land_from(heights)
	var host := Node3D.new()
	var planter := MeshPlanter.new(config, quality, before, land, host)
	planter.threaded = false
	var key := Vector2i((SPOT / MeshPlanter.CELL_M).floor())
	var groups := MeshPlanter.describe_groups(config, after)
	var plants := func(map: FloraDensity) -> int:
		var sum := 0
		for buffer in MeshPlanter.plan_cell(config, map, groups, 1.0, key, land.height_at, PackedVector4Array()):
			sum += buffer.size() / MeshPlanter.XFORM_STRIDE
		return sum
	_check("the blank snapshot plans no plant", plants.call(before) == 0)
	planter.set_flora(after)
	_check("set_flora: the planter reads the painted snapshot", planter.flora == after and plants.call(planter.flora) > 0)
	var eye := Vector3(SPOT.x, land.height_at(SPOT.x, SPOT.y) + 6.0, SPOT.y)
	for frame in 200:
		planter.update(eye, Time.get_ticks_usec() + 4000)
		if planter.pending_count() == 0:
			break
	var area := Rect2(SPOT - Vector2(SIZE_M, SIZE_M), Vector2(SIZE_M, SIZE_M) * 2.0)
	var expected: Array[Vector2i] = []
	for cell: Vector2i in planter._cells:
		if Rect2(Vector2(cell) * MeshPlanter.CELL_M, Vector2.ONE * MeshPlanter.CELL_M).intersects(area):
			expected.append(cell)
	planter.replan(area)
	var queued: Array[Vector2i] = planter._pending.duplicate()
	queued.sort()
	expected.sort()
	_check("the planter built the ring (%d cells)" % planter.cell_count(), planter.cell_count() > expected.size())
	_check("replan queues only the cells the area touches (%d)" % expected.size(), not expected.is_empty() and queued == expected)
	planter.clear()
	host.free()
	land.free()
