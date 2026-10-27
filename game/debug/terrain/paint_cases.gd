extends SceneTree

## Checks the picture brushes' arithmetic without a window: a hard brush weighs 1 on every pixel whose centre lies inside
## it and 0 elsewhere, `toward` with flow 1 lands exactly on the target (and halfway with flow 0.5), `add_role` keeps
## R + G + B + A = 255 on every pixel after 200 seeded random dabs and a full dab leaves only its role, a PixelPatch puts a
## rect back byte for byte, and the pictures weigh with the ground's own BrushRules.weight_at. Not: the canvases, files.
## "$GODOT" --headless --path game --script res://debug/terrain/paint_cases.gd

const Bed := preload("res://debug/terrain/brush_bed.gd")
## A flora density: 320 px of 8 m over the map.
const FLORA_SIDE := 320
const FLORA_CELL_M := 8.0
## The ground's roles: 256 px of 10 m.
const ROLES_SIDE := 256
const ROLES_CELL_M := 10.0

var _failed := 0


func _initialize() -> void:
	_hard_weights()
	_toward()
	_add_role()
	_pixel_patch()
	_same_weight()
	print("PAINT CASES %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)


## Falloff 0, 40 m: weight 1 on the pixels whose centre is within 40 m (none sits exactly on the edge here), 0 elsewhere,
## and the rect holds all of them.
func _hard_weights() -> void:
	var center := Vector2(1003.37, 997.81)
	var brush := Bed.brush(40.0, 0.0, TerrainBrush.Shape.CIRCLE)
	var size := Vector2i(FLORA_SIDE, FLORA_SIDE)
	var rect := PaintRules.pixel_rect(center, brush.size_m, FLORA_CELL_M, size)
	var weighted := PaintRules.weights(brush, center, rect, FLORA_CELL_M)
	var exact := true
	var inside := 0
	var i := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var near := _centre(x, y, FLORA_CELL_M).distance_to(center) <= brush.size_m
			exact = exact and weighted[i] == (1.0 if near else 0.0)
			inside += 1 if near else 0
			i += 1
	var everywhere := 0
	for y in FLORA_SIDE:
		for x in FLORA_SIDE:
			everywhere += 1 if _centre(x, y, FLORA_CELL_M).distance_to(center) <= brush.size_m else 0
	_check(exact, "weights: hard brush is 1 inside, 0 outside")
	_check(inside == everywhere and inside > 0, "weights: the rect holds every pixel inside (%d)" % inside)


## Flow 1 ends exactly at the target under the hard core; flow 0.5 goes halfway; outside nothing moves.
func _toward() -> void:
	var center := Vector2(640.0, 640.0)
	var brush := Bed.brush(60.0, 0.5, TerrainBrush.Shape.CIRCLE)
	var rect := PaintRules.pixel_rect(center, brush.size_m, FLORA_CELL_M, Vector2i(FLORA_SIDE, FLORA_SIDE))
	var weighted := PaintRules.weights(brush, center, rect, FLORA_CELL_M)
	var full := _blank(FLORA_SIDE * FLORA_SIDE, 0)
	PaintRules.toward(full, FLORA_SIDE, rect, weighted, 200, 1.0)
	var half := _blank(FLORA_SIDE * FLORA_SIDE, 0)
	PaintRules.toward(half, FLORA_SIDE, rect, weighted, 200, 0.5)
	var exact := true
	var halfway := true
	var still := true
	for y in FLORA_SIDE:
		for x in FLORA_SIDE:
			var at := y * FLORA_SIDE + x
			var weight := BrushRules.weight_at(brush, _centre(x, y, FLORA_CELL_M) - center)
			if weight >= 1.0:
				exact = exact and full[at] == 200
				halfway = halfway and half[at] == 100
			elif weight <= 0.0:
				still = still and full[at] == 0 and half[at] == 0
	_check(exact, "toward: flow 1 ends exactly at the target in the core")
	_check(halfway, "toward: flow 0.5 goes halfway in the core")
	_check(still, "toward: nothing moves outside the brush")


## 200 seeded random dabs of every role, size, falloff and flow: every pixel still sums 255. A full hard dab of rock
## leaves (0, 0, 255, 0) at its centre.
func _add_role() -> void:
	var rgba := PackedByteArray()
	for k in ROLES_SIDE * ROLES_SIDE:
		rgba.append_array(PackedByteArray([255, 0, 0, 0]))
	var random := RandomNumberGenerator.new()
	random.seed = 66
	var size := Vector2i(ROLES_SIDE, ROLES_SIDE)
	for dab in 200:
		var shape: TerrainBrush.Shape = random.randi_range(0, 2) as TerrainBrush.Shape
		var brush := Bed.brush(random.randf_range(10.0, 200.0), random.randf(), shape)
		var center := Vector2(random.randf_range(0.0, 2560.0), random.randf_range(0.0, 2560.0))
		var rect := PaintRules.pixel_rect(center, brush.size_m, ROLES_CELL_M, size)
		var weighted := PaintRules.weights(brush, center, rect, ROLES_CELL_M)
		PaintRules.add_role(rgba, ROLES_SIDE, rect, weighted, random.randi_range(0, 3), random.randf())
	var bad := 0
	for k in ROLES_SIDE * ROLES_SIDE:
		bad += 0 if rgba[k * 4] + rgba[k * 4 + 1] + rgba[k * 4 + 2] + rgba[k * 4 + 3] == 255 else 1
	_check(bad == 0, "add_role: R+G+B+A = 255 after 200 dabs (%d pixels off)" % bad)
	var hard := Bed.brush(50.0, 0.0, TerrainBrush.Shape.CIRCLE)
	var center := Vector2(1275.0, 1275.0)
	var rect := PaintRules.pixel_rect(center, hard.size_m, ROLES_CELL_M, size)
	PaintRules.add_role(rgba, ROLES_SIDE, rect, PaintRules.weights(hard, center, rect, ROLES_CELL_M), 2, 1.0)
	var at := (127 * ROLES_SIDE + 127) * 4
	_check(rgba.slice(at, at + 4) == PackedByteArray([0, 0, 255, 0]), "add_role: a full dab of rock leaves (0,0,255,0)")


## Reading a rect, changing it and writing the patch back gives the old bytes exactly (4 channels).
func _pixel_patch() -> void:
	var data := PackedByteArray()
	for k in 64 * 64 * 4:
		data.append(k % 251)
	var kept := data.duplicate()
	var rect := Rect2i(10, 20, 17, 9)
	var patch := BrushCanvas.PixelPatch.read(data, 64, 4, rect)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			data[(y * 64 + x) * 4 + 1] = 7
	patch.write(data, 64, 4)
	_check(data == kept and patch.bytes.size() == rect.get_area() * 4, "pixel patch: a rect goes back byte for byte")


## The ground's weights and the pictures' are the same function.
func _same_weight() -> void:
	var brush := Bed.brush(45.0, 0.6, TerrainBrush.Shape.CROSS)
	var center := TerrainGrid.point_of(Vector2i(100, 100)) + Vector2(3.0, -2.0)
	var rect := TerrainGrid.vertex_rect(center, brush.size_m)
	var weighted := BrushRules.weights(brush, center, rect)
	var same := true
	var i := 0
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			same = same and weighted[i] == BrushRules.weight_at(brush, TerrainGrid.point_of(Vector2i(x, z)) - center)
			i += 1
	_check(same, "weight_at: BrushRules.weights uses it vertex by vertex")


func _centre(x: int, y: int, cell_m: float) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_m


func _blank(count: int, value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count)
	bytes.fill(value)
	return bytes


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
