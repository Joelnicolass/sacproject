class_name PaintRules
extends RefCounted

## What one dab of a brush does to a picture laid over the map (the ground's roles, a flora layer's density): which pixels
## it reaches, how strongly it touches each one (BrushRules.weight_at at the pixel's centre) and the byte arithmetic of
## moving a grey value toward a target or adding one ground role while the four roles keep summing 255. Pixel (i, j) has
## its centre at ((i + 0.5) * cell_m, (j + 0.5) * cell_m); bytes are row by row, `width` pixels a row. Every edit works IN
## PLACE and only inside `rect`; `weighted` must come from `weights()` for the same rect. Not: files, the editor, undo.
## Pure and static: it runs headless (debug/terrain/paint_cases.gd).


## The pixels whose centre may lie within `reach_m` of `center_m`, cut to a picture of `size` pixels (empty if none).
static func pixel_rect(center_m: Vector2, reach_m: float, cell_m: float, size: Vector2i) -> Rect2i:
	var low := Vector2i(floori((center_m.x - reach_m) / cell_m), floori((center_m.y - reach_m) / cell_m))
	var high := Vector2i(ceili((center_m.x + reach_m) / cell_m), ceili((center_m.y + reach_m) / cell_m))
	var rect := Rect2i(low, high - low).intersection(Rect2i(Vector2i.ZERO, size))
	return rect if rect.has_area() else Rect2i()


## How strongly the brush centred on `center_m` touches each pixel of `rect`, row by row (the weight at its centre).
static func weights(brush: TerrainBrush, center_m: Vector2, rect: Rect2i, cell_m: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	var i := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out[i] = BrushRules.weight_at(brush, (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_m - center_m)
			i += 1
	return out


## One byte a pixel (L8): v += (target - v) * w * flow, rounded; w * flow >= 1 ends exactly at `target`.
static func toward(bytes: PackedByteArray, width: int, rect: Rect2i, weighted: PackedFloat32Array, target: int, flow: float) -> void:
	var goal := clampi(target, 0, 255)
	var i := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var amount := weighted[i] * flow
			i += 1
			if amount <= 0.0:
				continue
			var at := y * width + x
			bytes[at] = goal if amount >= 1.0 else clampi(roundi(bytes[at] + (goal - bytes[at]) * amount), 0, 255)


## RGBA8, one ground role per channel: with a = w * flow, `channel` becomes c(1 - a) + 255a and the other three x(1 - a),
## rounded; the rounding residual goes to `channel`, so R + G + B + A is 255 in every pixel it writes. A pixel whose share
## is too small to move (the residual would go below 0) is left as it was.
static func add_role(rgba: PackedByteArray, width: int, rect: Rect2i, weighted: PackedFloat32Array, channel: int, flow: float) -> void:
	var i := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var amount := clampf(weighted[i] * flow, 0.0, 1.0)
			i += 1
			if amount <= 0.0:
				continue
			var base := (y * width + x) * 4
			var kept := PackedInt32Array([0, 0, 0, 0])
			var others := 0
			for c in 4:
				if c != channel:
					kept[c] = roundi(rgba[base + c] * (1.0 - amount))
					others += kept[c]
			if others > 255:
				continue
			kept[channel] = 255 - others
			for c in 4:
				rgba[base + c] = kept[c]
