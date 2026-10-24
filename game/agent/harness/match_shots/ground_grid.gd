extends RefCounted

## The "ground" view of match_shots: where the 10 m cell borders of the map fall in a fixed camera's picture, written next to the PNG
## as JSON so tools/import/measure_seams.py can compare the brightness step across a border with the step across a line inside
## the cells. It reads the land height from TerrainShape and projects with the camera; it draws nothing.
## JSON: {"size": [w, h], "border": [[x, y, nx, ny], ...], "inside": [...]}: pixel and the unit screen normal of the line there.

const CELL_M := 10.0
## Lines inside the cells used as the control: at a quarter, half and three quarters of a cell.
const INSIDE_AT := [2.5, 5.0, 7.5]
const STEP_M := 0.25
const NORMAL_M := 0.2


## Writes `file` (.json) for the camera's current picture: lines within `reach_m` of `center` (world x, z).
static func write(camera: Camera3D, shape: TerrainShape, center: Vector2, reach_m: float, file: String) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	var border: Array = []
	var inside: Array = []
	var first := floorf((center.x - reach_m) / CELL_M) * CELL_M
	var first_z := floorf((center.y - reach_m) / CELL_M) * CELL_M
	var cells := int(ceilf(2.0 * reach_m / CELL_M)) + 1
	for k in cells:
		_line(camera, shape, size, true, first + k * CELL_M, center.y, reach_m, border)
		_line(camera, shape, size, false, first_z + k * CELL_M, center.x, reach_m, border)
		for offset: float in INSIDE_AT:
			_line(camera, shape, size, true, first + k * CELL_M + offset, center.y, reach_m, inside)
			_line(camera, shape, size, false, first_z + k * CELL_M + offset, center.x, reach_m, inside)
	var out := FileAccess.open(file, FileAccess.WRITE)
	if out == null:
		push_error("ground_grid: cannot write %s" % file)
		return
	out.store_string(JSON.stringify({"size": [size.x, size.y], "border": border, "inside": inside}))
	print("ground grid %s: %d border samples, %d inside samples" % [file, border.size(), inside.size()])


## One line of constant x (`along_z`) or constant z, sampled every STEP_M; keeps the samples the camera sees on screen.
static func _line(camera: Camera3D, shape: TerrainShape, size: Vector2, along_z: bool, fixed: float, middle: float, reach_m: float, into: Array) -> void:
	var steps := int(2.0 * reach_m / STEP_M)
	for i in steps + 1:
		var free := middle - reach_m + i * STEP_M
		var point := _ground(shape, Vector2(fixed, free) if along_z else Vector2(free, fixed))
		var across := _ground(shape, Vector2(fixed + NORMAL_M, free) if along_z else Vector2(free, fixed + NORMAL_M))
		if is_nan(point.y) or is_nan(across.y) or camera.is_position_behind(point) or camera.is_position_behind(across):
			continue
		var pixel := camera.unproject_position(point)
		var normal := camera.unproject_position(across) - pixel
		if normal.length() < 0.5 or pixel.x < 4.0 or pixel.y < 4.0 or pixel.x > size.x - 4.0 or pixel.y > size.y - 4.0:
			continue
		normal = normal.normalized()
		into.append([snappedf(pixel.x, 0.01), snappedf(pixel.y, 0.01), snappedf(normal.x, 0.001), snappedf(normal.y, 0.001)])


static func _ground(shape: TerrainShape, xz: Vector2) -> Vector3:
	return Vector3(xz.x, shape.height_at(xz.x, xz.y), xz.y)
