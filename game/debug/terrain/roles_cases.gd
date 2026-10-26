extends SceneTree

## Checks the roles brush's canvas without a window, over an all-grass 256² picture like paint_bed's: one hard dab of rock
## (size 50, falloff 0, flow 1) at (1275, 1275) leaves pixel (127, 127) at (0, 0, 255, 0) and changes exactly the pixels
## whose centre lies closer than 50 m (69; plan 066 guessed 78 ± 8 = pi r², but the brush weighs 0 at its very edge and
## 12 centres sit exactly 50 m away) and none outside; a whole stroke run through BrushStroke hands back patches that
## put the picture back byte for byte (undo) and again (redo); every pixel still sums 255; the step names are Spanish.
## Not: the GPU preview, saving (the editor probe and the final pass do those).
## "$GODOT" --headless --path game --script res://debug/terrain/roles_cases.gd

const Bed := preload("res://debug/terrain/brush_bed.gd")
const SIDE := 256
const ROCK := 2

var _failed := 0


func _initialize() -> void:
	_one_dab()
	_stroke_undo()
	print("ROLES CASES %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(0 if _failed == 0 else 1)


func _one_dab() -> void:
	var canvas := RolesCanvas.over(_grass())
	var before := canvas.picture().get_data()
	var brush := _brush(50.0)
	var center := Vector2(1275.0, 1275.0)
	canvas.begin(ROCK, brush, center)
	canvas.dab(center, 0.0)
	var after := canvas.picture().get_data()
	var at := (127 * SIDE + 127) * 4
	_check(after.slice(at, at + 4) == PackedByteArray([0, 0, 255, 0]), "dab: pixel (127,127) is rock (0,0,255,0)")
	var changed := 0
	var stray := 0
	for y in SIDE:
		for x in SIDE:
			var k := (y * SIDE + x) * 4
			var moved := after.slice(k, k + 4) != before.slice(k, k + 4)
			var near := ((Vector2(x, y) + Vector2(0.5, 0.5)) * 10.0).distance_to(center) < brush.size_m
			changed += 1 if moved else 0
			stray += 1 if moved != near else 0
	_check(changed == 69, "dab: %d pixels changed (69: the 12 centres exactly 50 m away weigh 0)" % changed)
	_check(stray == 0, "dab: only the pixels closer than 50 m change (%d off)" % stray)
	_check(canvas.label(ROCK) == "Roles: roca" and canvas.label(0) == "Roles: pasto", "labels: «Roles: roca», «Roles: pasto»")


## A drag of earth with a soft brush, then the before and after patches written back as undo and redo do.
func _stroke_undo() -> void:
	var canvas := RolesCanvas.over(_grass())
	var start := canvas.picture().get_data()
	var stroke := BrushStroke.new()
	var brush := _brush(120.0)
	brush.falloff = 0.6
	brush.flow = 0.4
	stroke.begin(canvas, 1, brush, Vector2(600.0, 900.0))
	for step in 12:
		stroke.drag(Vector2(600.0 + step * 25.0, 900.0 + step * 10.0), 0.0)
	var done := stroke.finish()
	var painted := canvas.picture().get_data()
	canvas.write(done["before"])
	_check(canvas.picture().get_data() == start, "undo: the picture is back byte for byte")
	canvas.write(done["after"])
	_check(canvas.picture().get_data() == painted and painted != start, "redo: the stroke is back byte for byte")
	var bad := 0
	for k in SIDE * SIDE:
		bad += 0 if painted[k * 4] + painted[k * 4 + 1] + painted[k * 4 + 2] + painted[k * 4 + 3] == 255 else 1
	_check(bad == 0, "stroke: every pixel sums 255 (%d off)" % bad)
	_check(not canvas.is_dirty(), "headless: nothing to save")


## A 256² picture all grass, (255, 0, 0, 0), as the template and paint_bed start.
func _grass() -> Image:
	var image := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	image.fill(Color8(255, 0, 0, 0))
	return image


func _brush(size_m: float) -> TerrainBrush:
	var brush := Bed.brush(size_m, 0.0, TerrainBrush.Shape.CIRCLE)
	brush.flow = 1.0
	return brush


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
