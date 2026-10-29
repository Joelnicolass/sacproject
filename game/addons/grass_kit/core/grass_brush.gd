@tool
class_name GrassBrush
extends RefCounted

## A round brush for the ground's painted maps (`GrassGround.paint()`): what the editor's brushes
## paint with, and what a game can paint with in play (a burnt patch, a path the player wears).
## A dab moves the map under it towards `value` (or what erasing goes to: no grass, or the map's
## rest): `strength` is how far one dab goes, `falloff` how much of the radius fades out, `noise`
## how ragged the edge is. The rags are fixed in the world, so going over a place again grows one
## ragged patch instead of blurring it. SMOOTH evens the map out under the brush.

enum Mode { PAINT, ERASE, SMOOTH }

## Radius (m).
var radius := 2.0
## How far one dab moves a texel towards its target (0 to 1).
var strength := 0.5
## The part of the radius that fades out (0 = a hard edge, 1 = soft from the centre).
var falloff := 0.5
## How ragged the edge is (0 = round).
var noise := 0.0
## What PAINT moves texels towards: a map's own value (density 1, size 0.5 = as the look, a colour).
var value := Color.WHITE
var mode := Mode.PAINT


## Paints one dab of `image` (a map stretched over `area`) centred at `at` (x, z). `erased` is what
## ERASE moves towards (no grass, or the map's rest); `pressure` scales the strength (a tablet pen).
## Returns the texels it changed (empty when none).
func dab(image: Image, area: Rect2, at: Vector2, erased: Color, pressure := 1.0) -> Rect2i:
	var size := image.get_size()
	var texel := area.size / Vector2(size)
	var reach := radius * (1.0 + noise * 0.4)
	var low := ((at - Vector2(reach, reach) - area.position) / texel).floor()
	var high := ((at + Vector2(reach, reach) - area.position) / texel).ceil()
	var span := Rect2i(Vector2i(low), Vector2i(high - low)).intersection(Rect2i(Vector2i.ZERO, size))
	if not span.has_area():
		return Rect2i()
	var amount := clampf(strength * pressure, 0.0, 1.0)
	var target := erased if mode == Mode.ERASE else value
	var colour := image.get_format() == Image.FORMAT_RGBA8
	# SMOOTH reads the texels as they were before this dab, one texel around included.
	var before: Image
	var origin := Vector2i.ZERO
	if mode == Mode.SMOOTH:
		var around := span.grow(1).intersection(Rect2i(Vector2i.ZERO, size))
		before = image.get_region(around)
		origin = around.position
	var cell := maxf(radius * 0.35, texel.x * 2.0)
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var point := area.position + (Vector2(tx, ty) + Vector2(0.5, 0.5)) * texel
			var weight := weight_at(point.distance_to(at), point, cell) * amount
			if weight <= 0.0:
				continue
			var old := image.get_pixel(tx, ty)
			var new: Color
			if mode == Mode.SMOOTH:
				new = old.lerp(_average(before, tx - origin.x, ty - origin.y, colour), weight)
			elif colour:
				new = _over(old, target, weight, mode == Mode.ERASE)
			else:
				new = old.lerp(target, weight)
			image.set_pixel(tx, ty, new)
	return span


## How much of a dab reaches `distance` metres from its centre, at `point` (the noise's place in the
## world), before `strength`: 1 inside the hard part, fading to 0 at the edge.
func weight_at(distance: float, point := Vector2.ZERO, cell := 1.0) -> float:
	if noise > 0.0:
		distance += (_noise(point / cell) - 0.5) * noise * radius * 0.8
	var inner := radius * (1.0 - clampf(falloff, 0.0, 1.0))
	if distance >= radius:
		return 0.0
	if distance <= inner:
		return 1.0
	return 1.0 - smoothstep(inner, radius, distance)


## A colour map: painting lays `target` over what is there (alpha = how much it covers the look's
## ground colour); erasing uncovers it, keeping its colour.
static func _over(old: Color, target: Color, weight: float, erase: bool) -> Color:
	if erase:
		return Color(old.r, old.g, old.b, lerpf(old.a, 0.0, weight))
	var a := lerpf(old.a, 1.0, weight)
	if a <= 0.0:
		return Color(target.r, target.g, target.b, 0.0)
	var keep := old.a * (1.0 - weight)
	var rgb := (Vector3(old.r, old.g, old.b) * keep + Vector3(target.r, target.g, target.b) * weight)
	rgb /= keep + weight
	return Color(rgb.x, rgb.y, rgb.z, a)


## The 3 x 3 average around (x, y) of `image` (a colour map's by how much each texel covers).
static func _average(image: Image, x: int, y: int, colour: bool) -> Color:
	var size := image.get_size()
	var sum := Color(0, 0, 0, 0)
	var cover := 0.0
	var count := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var px := clampi(x + dx, 0, size.x - 1)
			var py := clampi(y + dy, 0, size.y - 1)
			var texel := image.get_pixel(px, py)
			if colour:
				sum += Color(texel.r * texel.a, texel.g * texel.a, texel.b * texel.a, texel.a)
				cover += texel.a
			else:
				sum += texel
			count += 1.0
	if not colour:
		return sum / count
	if cover <= 0.0:
		return image.get_pixel(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1))
	return Color(sum.r / cover, sum.g / cover, sum.b / cover, cover / count)


## Smooth value noise in [0, 1]: two octaves, fixed in the world.
static func _noise(p: Vector2) -> float:
	return _value(p) * 0.65 + _value(p * 2.7 + Vector2(17.3, 5.1)) * 0.35


static func _value(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1, 0))
	var c := _hash(i + Vector2(0, 1))
	var d := _hash(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


static func _hash(p: Vector2) -> float:
	var h := int(p.x) * 374761393 + int(p.y) * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0
