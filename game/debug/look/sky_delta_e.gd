class_name SkyDeltaE
extends RefCounted

## CIE76 colour difference between two same-size images (sRGB 8-bit in, Lab D65 out).

const WHITE := Vector3(0.95047, 1.0, 1.08883)

static var _linear: PackedFloat32Array = _build_linear_table()


## {mean, p99, max} of the per-pixel delta E between `a` and `b`.
static func compare(a: Image, b: Image) -> Dictionary:
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var count := mini(da.size(), db.size()) / 3
	var diffs := PackedFloat32Array()
	diffs.resize(count)
	var cache := {}
	for i in count:
		diffs[i] = _lab(da, i * 3, cache).distance_to(_lab(db, i * 3, cache))
	var sorted := diffs.duplicate()
	sorted.sort()
	var total := 0.0
	for value in diffs:
		total += value
	return {"mean": total / maxi(count, 1), "p99": sorted[int(count * 0.99)] if count > 0 else 0.0,
		"max": sorted[count - 1] if count > 0 else 0.0}


static func _lab(bytes: PackedByteArray, offset: int, cache: Dictionary) -> Vector3:
	var key := (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2]
	if cache.has(key):
		return cache[key]
	var r: float = _linear[bytes[offset]]
	var g: float = _linear[bytes[offset + 1]]
	var b: float = _linear[bytes[offset + 2]]
	var xyz := Vector3(
		0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
		0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
		0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / WHITE
	var lab := Vector3(116.0 * _f(xyz.y) - 16.0, 500.0 * (_f(xyz.x) - _f(xyz.y)), 200.0 * (_f(xyz.y) - _f(xyz.z)))
	cache[key] = lab
	return lab


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func _build_linear_table() -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(256)
	for i in 256:
		table[i] = Color(i / 255.0, 0.0, 0.0).srgb_to_linear().r
	return table
