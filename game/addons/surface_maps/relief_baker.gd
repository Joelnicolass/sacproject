@tool
class_name ReliefBaker
extends RefCounted

## Guesses a relief from a colour picture the way NormalMap-Online (cpetry, MIT) does: brightness is height, optionally
## inverted, smoothed or sharpened, then a 3x3 Sobel (or Scharr) slope gives the normal normalize(slope * 255, (1 + 2^level)
## / strength), written OpenGL (green up) as Godot reads it. A high-pass that takes the broad painted light away first is
## optional (off by default). On request it also makes an ORM (R occlusion from the hollows, G roughness, B metal or height).
## Holes of a cutout take the height of the nearest solid texel, so the edge leaves no halo. With `tile_cells` each tile of a
## sheet wraps on itself; without, the edges clamp. Pure, static and deterministic: the same picture and recipe give the same
## bytes. Not: files (MapWriter).
## Ref: https://github.com/cpetry/NormalMap-Online (javascripts/normalMap.js, shader/NormalMapShader.js).

const AO_GAIN := 8.0
const LUMA_WEIGHTS := Vector3(0.299, 0.587, 0.114)


## {"normal": Image, "orm": Image or null}: both RGBA8 and the size of `albedo`; "orm" is null unless `recipe.orm`.
static func bake(albedo: Image, recipe: ReliefRecipe) -> Dictionary:
	var source := albedo.duplicate() as Image
	if source.is_compressed():
		source.decompress()
	source.clear_mipmaps()
	source.convert(Image.FORMAT_RGBA8)
	var size := source.get_size()
	var normal := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var orm: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8) if recipe.orm else null
	var cells := clampi(recipe.tile_cells, 1, mini(size.x, size.y))
	var cell := size / cells
	for cy in cells:
		for cx in cells:
			var at := Vector2i(cx, cy) * cell
			var end := Vector2i(size.x if cx == cells - 1 else at.x + cell.x, size.y if cy == cells - 1 else at.y + cell.y)
			_bake_cell(source.get_region(Rect2i(at, end - at)), recipe, normal, orm, at)
	return {"normal": normal, "orm": orm}


static func _bake_cell(part: Image, recipe: ReliefRecipe, normal: Image, orm: Image, at: Vector2i) -> void:
	var w := part.get_width()
	var h := part.get_height()
	var wrap := recipe.tile_cells > 0
	var luma := _fill_holes(_luma(part), _solid(part, recipe.alpha_cut), w, h)
	var height := luma.duplicate()
	if recipe.invert_height:
		for i in height.size():
			height[i] = 1.0 - height[i]
	if recipe.flatten_px > 0:
		var broad := _blur(height, w, h, recipe.flatten_px, wrap)
		for i in height.size():
			height[i] = height[i] - broad[i] + 0.5
	if recipe.smoothing > 0:
		height = _blur(height, w, h, recipe.smoothing, wrap)
	elif recipe.smoothing < 0:
		var soft := _blur(height, w, h, -recipe.smoothing, wrap)
		for i in height.size():
			height[i] = 2.0 * height[i] - soft[i]
	var whole := Rect2i(0, 0, w, h)
	normal.blit_rect(_normal_of(height, w, h, recipe, wrap), whole, at)
	if orm != null:
		orm.blit_rect(_orm_of(height, luma, w, h, recipe, wrap), whole, at)


## Brightness of each texel, 0..1, row by row.
static func _luma(part: Image) -> PackedFloat32Array:
	var data := part.get_data()
	var out := PackedFloat32Array()
	out.resize(part.get_width() * part.get_height())
	for i in out.size():
		var rgb := Vector3(data[i * 4], data[i * 4 + 1], data[i * 4 + 2])
		out[i] = rgb.dot(LUMA_WEIGHTS) / 255.0
	return out


## 1 for each solid texel, 0 for a hole; empty when the picture has no alpha (every texel is solid).
static func _solid(part: Image, cut: float) -> PackedByteArray:
	var out := PackedByteArray()
	if part.detect_alpha() == Image.ALPHA_NONE:
		return out
	var data := part.get_data()
	var limit := cut * 255.0
	out.resize(part.get_width() * part.get_height())
	for i in out.size():
		out[i] = 1 if data[i * 4 + 3] >= limit else 0
	return out


## Each hole takes the value of the nearest solid texel (4-neighbour flood from every solid texel at once).
static func _fill_holes(values: PackedFloat32Array, solid: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	if solid.is_empty():
		return values
	var seen := solid.duplicate()
	var queue := PackedInt32Array()
	for i in solid.size():
		if solid[i] == 1:
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var near: Array[int] = []
		if x > 0:
			near.append(i - 1)
		if x < w - 1:
			near.append(i + 1)
		if i >= w:
			near.append(i - w)
		if i < (h - 1) * w:
			near.append(i + w)
		for n in near:
			if seen[n] == 0:
				seen[n] = 1
				values[n] = values[i]
				queue.append(n)
	return values


## Two passes of a box blur of radius `r` along rows and columns (close to a gaussian).
static func _blur(values: PackedFloat32Array, w: int, h: int, r: int, wrap: bool) -> PackedFloat32Array:
	var out := values
	for _pass in 2:
		out = _box(out, h, w, 1, w, r, wrap)
		out = _box(out, w, 1, w, h, r, wrap)
	return out


## A running-sum box blur over `lines` lines of `length` values; `line_step` / `step` are the strides between lines / values.
static func _box(values: PackedFloat32Array, lines: int, line_step: int, step: int, length: int, r: int, wrap: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	var span := float(2 * r + 1)
	for line in lines:
		var base := line * line_step
		var sum := 0.0
		for k in range(-r, r + 1):
			sum += values[base + _at(k, length, wrap) * step]
		for i in length:
			out[base + i * step] = sum / span
			sum += values[base + _at(i + r + 1, length, wrap) * step] - values[base + _at(i - r, length, wrap) * step]
	return out


static func _at(i: int, length: int, wrap: bool) -> int:
	return posmod(i, length) if wrap else clampi(i, 0, length - 1)


## The 3x3 slope of the height at every texel (Sobel 1 2 1 or Scharr 3 10 3), as NormalMap-Online: x grows to the right,
## y up (OpenGL), z = (1 + 2^level) / strength over a slope in 0..255 steps. Edges wrap or clamp.
static func _normal_of(height: PackedFloat32Array, w: int, h: int, recipe: ReliefRecipe, wrap: bool) -> Image:
	var scharr := recipe.filter == ReliefRecipe.Filter.SCHARR
	var side := 3.0 if scharr else 1.0
	var mid := 10.0 if scharr else 2.0
	var gain := 255.0 * recipe.strength / (1.0 + pow(2.0, recipe.level))
	var flip := Vector2(-1.0 if recipe.invert_r else 1.0, -1.0 if recipe.invert_g else 1.0)
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for y in h:
		var up := _at(y - 1, h, wrap) * w
		var row := y * w
		var down := _at(y + 1, h, wrap) * w
		for x in w:
			var left := _at(x - 1, w, wrap)
			var right := _at(x + 1, w, wrap)
			var tl := height[up + left]
			var tr := height[up + right]
			var bl := height[down + left]
			var br := height[down + right]
			var dx := side * (tl + bl - tr - br) + mid * (height[row + left] - height[row + right])
			var dy := side * (bl + br - tl - tr) + mid * (height[down + x] - height[up + x])
			var n := Vector3(dx * gain * flip.x, dy * gain * flip.y, 1.0).normalized()
			var i := (row + x) * 4
			bytes[i] = _byte(n.x * 0.5 + 0.5)
			bytes[i + 1] = _byte(n.y * 0.5 + 0.5)
			bytes[i + 2] = _byte(n.z * 0.5 + 0.5)
			bytes[i + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


## R = 1 minus how far a texel sits below its surroundings, G = roughness, B = metal or the height.
static func _orm_of(height: PackedFloat32Array, luma: PackedFloat32Array, w: int, h: int, recipe: ReliefRecipe, wrap: bool) -> Image:
	var around := _blur(height, w, h, recipe.ao_radius_px, wrap)
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i in height.size():
		var ao := 1.0 - maxf(around[i] - height[i], 0.0) * recipe.ao_strength * AO_GAIN
		var rough := recipe.roughness + (0.5 - luma[i]) * recipe.roughness_from_luma
		var b := recipe.metallic if recipe.pack_b == ReliefRecipe.PackB.METAL else height[i]
		bytes[i * 4] = _byte(ao)
		bytes[i * 4 + 1] = _byte(rough)
		bytes[i * 4 + 2] = _byte(b)
		bytes[i * 4 + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


static func _byte(value: float) -> int:
	return roundi(clampf(value, 0.0, 1.0) * 255.0)
