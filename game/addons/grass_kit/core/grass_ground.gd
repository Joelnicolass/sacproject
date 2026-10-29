@tool
class_name GrassGround
extends Resource

## Where grass grows and how high the ground is under it, over `area` (x, z in world metres). The
## height comes from the game's colliders: `bake()` casts a ray down every `texel_size` metres
## (the field's «Bake ground» button does it in the editor) and keeps, in one texture, the exact
## height where it hits, the ground's normal (blades stand along it) and where there is ground. A game with
## its own height data writes it instead with `set_heights(rect, sampler)`. Grass thins and
## shortens on steep ground (`slope_fade`). When the ground changes in play (a crater), bake or write
## only that rect: `area_changed` tells the field which part to redo. Without a bake the ground
## is flat at `flat_height`.
##
## Painted maps, all stretched over `area`: where grass grows (`density_texture`), how tall
## (`size_texture`), the ground's colour (`color_texture`) and where each named kind of blade grows
## (`kind_maps`). The editor's brushes paint them (select the field, pick a brush in the 3D view's
## toolbar); `paint()` does the same from code. A brush makes its map on the first dab, at
## `paint_texel_size`, and the maps are saved inside this resource. Any texture made elsewhere
## works too: the first brush stroke over it paints a copy kept here, the file stays as it was.

## Part of the ground changed (heights or where grass grows): `rect` on the ground plane.
signal area_changed(rect: Rect2)
## `map` was painted: its texture shows it now (once a frame however many dabs it had).
signal map_painted(map: StringName)

## The maps the brushes paint, besides the kinds' own (a kind's `GrassMesh.map_name`).
const DENSITY := &"density"
const SIZE := &"size"
const COLOR := &"color"
## No map is ever bigger than this on a side: a bigger area gets bigger texels.
const MAX_MAP_SIZE := 2048

## The ground the grass covers (x, z), in world metres.
@export var area := Rect2(-50.0, -50.0, 100.0, 100.0)
## Metres between two baked heights. Smaller = closer to the ground's shape, bigger maps.
@export_range(0.1, 8.0, 0.05, "or_greater", "suffix:m") var texel_size := 0.5
## The physics layers `bake()` hits (the terrain's). Keep props and units out of it.
@export_flags_3d_physics var collision_mask := 1
## Grass thins and shortens from the first slope (x, degrees) and is gone past the second (y).
@export var slope_fade := Vector2(35.0, 55.0):
	set(value):
		slope_fade = value
		emit_changed()
## The ground's height where nothing is baked.
@export var flat_height := 0.0

@export_group("Painted maps")
## Where grass grows (red): white = grass, black = none, grey thins it. Null = grass everywhere the
## ground allows. The «Grass» brush paints it.
@export var density_texture: Texture2D:
	set(value):
		density_texture = value
		emit_changed()
## How tall the blades grow (red): 0.5 = as the look says, black = flat, white = twice (short grass
## on paths). Null = as the look says everywhere. The «Height» brush paints it.
@export var size_texture: Texture2D:
	set(value):
		size_texture = value
		emit_changed()
## The ground's colour, mixed into the blades' base and into the far grass: its alpha is how much it
## covers the look's `ground_color` (a painted map is clear where nothing is painted). Any texture
## the game makes works: its albedo map, or its ground shader rendered once from above. The
## «Colour» brush paints it.
@export var color_texture: Texture2D:
	set(value):
		color_texture = value
		emit_changed()
## Where the kinds of blade with a `map_name` grow (red: white = here), by that name. A kind with a
## name but no map here grows everywhere. The «Kind» brush paints them.
@export var kind_maps: Dictionary[StringName, Texture2D] = {}:
	set(value):
		kind_maps = value
		emit_changed()
## Metres a texel of a map the brushes make (a texture made elsewhere keeps its own size).
@export_range(0.05, 4.0, 0.05, "or_greater", "suffix:m") var paint_texel_size := 0.25

## The baked ground, one texel per `texel_size`: height (red), the normal's x and z (green, blue),
## and 1 where a ray found ground (alpha). One texture, so a blade reads it all at once. Null = flat.
@export_storage var data: Image

var _texture: ImageTexture
var _upload_queued := false
## The maps painted this frame (each shown by its texture at the end of it).
var _maps_queued: Dictionary[StringName, bool] = {}
## A map or the baked heights changed since this was last saved (the editor saves the ground with
## the scene).
var _maps_edited := false
var _full_range := Vector2.INF
## The grounds edited since the editor last saved them.
static var _edited: Array[GrassGround] = []


## Texels across `area`.
func texture_size() -> Vector2i:
	return Vector2i(
		maxi(ceili(area.size.x / texel_size), 1), maxi(ceili(area.size.y / texel_size), 1)
	)


## Casts a ray down at every texel of `rect` (empty = all of `area`) in `space` against
## `collision_mask`, from `top` to `bottom`. Returns how many texels found ground.
func bake(
	space: PhysicsDirectSpaceState3D, rect := Rect2(), top := 1000.0, bottom := -1000.0
) -> int:
	_ensure_data()
	var span := _texels_in(rect if rect.has_area() else area)
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = collision_mask
	var found := 0
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var at := _texel_center(tx, ty)
			query.from = Vector3(at.x, top, at.y)
			query.to = Vector3(at.x, bottom, at.y)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				data.set_pixel(tx, ty, Color(flat_height, 0.0, 0.0, 0.0))
				continue
			found += 1
			var normal: Vector3 = hit["normal"]
			var y := (hit["position"] as Vector3).y
			data.set_pixel(tx, ty, Color(y, normal.x, normal.z, 1.0))
	_changed(_rect_of(span))
	return found


## Writes the heights of `rect` from the game's own data: `sampler` is `func(x, z) -> float` in
## world metres (NAN = no ground there). The normals come from the heights themselves.
func set_heights(rect: Rect2, sampler: Callable) -> void:
	_ensure_data()
	var span := _texels_in(rect)
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var at := _texel_center(tx, ty)
			var h: float = sampler.call(at.x, at.y)
			var found := 0.0 if is_nan(h) else 1.0
			data.set_pixel(tx, ty, Color(flat_height if is_nan(h) else h, 0.0, 0.0, found))
	# A normal needs its neighbours, so one texel more around.
	var grown := Rect2i(span.position - Vector2i.ONE, span.size + Vector2i(2, 2))
	grown = grown.intersection(Rect2i(Vector2i.ZERO, texture_size()))
	for ty in range(grown.position.y, grown.end.y):
		for tx in range(grown.position.x, grown.end.x):
			var texel := data.get_pixel(tx, ty)
			var normal := _normal_from_heights(tx, ty)
			data.set_pixel(tx, ty, Color(texel.r, normal.x, normal.z, texel.a))
	_changed(_rect_of(grown))


## Writes the heights of `rect` (empty = all of `area`) from an image whose red channel is the
## height in metres, its pixels spread over `rect` (NAN = no ground there). Much quicker than
## `set_heights()` for a whole map. Heights in a PackedFloat32Array (row by row) make one with
## `Image.create_from_data(width, depth, false, Image.FORMAT_RF, heights.to_byte_array())`.
func set_heights_image(heights: Image, rect := Rect2()) -> void:
	if not rect.has_area():
		rect = area
	_ensure_data()
	var source := heights
	if source.is_compressed() or source.get_format() != Image.FORMAT_RF:
		source = heights.duplicate() as Image
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RF)
	var size := texture_size()
	var span := _texels_in(rect)
	if not span.has_area():
		return
	var whole := Rect2i(Vector2i.ZERO, size)
	# Heights two texels around what is written, the normals of one texel around (they need their
	# neighbours); outside `span` the heights stay as they are.
	var read := span.grow(2).intersection(whole)
	var write := span.grow(1).intersection(whole)
	var old := data.get_region(read).get_data().to_float32_array()
	var src := source.get_data().to_float32_array()
	var src_size := source.get_size()
	var cell := area.size / Vector2(size)
	var scale := Vector2(src_size) / rect.size
	var exact := src_size == span.size and _rect_of(span).is_equal_approx(rect)
	var rw := read.size.x
	var h := PackedFloat32Array()
	h.resize(rw * read.size.y)
	var found := PackedFloat32Array()
	found.resize(h.size())
	for y in read.size.y:
		var ty := read.position.y + y
		for x in rw:
			var tx := read.position.x + x
			var i := y * rw + x
			if tx < span.position.x or ty < span.position.y or tx >= span.end.x or ty >= span.end.y:
				h[i] = old[i * 4]
				found[i] = old[i * 4 + 3]
				continue
			var v: float
			if exact:
				v = src[(ty - span.position.y) * src_size.x + tx - span.position.x]
			else:
				var at := area.position + (Vector2(tx, ty) + Vector2(0.5, 0.5)) * cell
				v = _bilinear(src, src_size, (at - rect.position) * scale - Vector2(0.5, 0.5))
			if is_nan(v):
				h[i] = flat_height
				found[i] = 0.0
			else:
				h[i] = v
				found[i] = 1.0
	var out := PackedFloat32Array()
	out.resize(write.size.x * write.size.y * 4)
	var k := 0
	var last := read.size - Vector2i.ONE
	for ty in range(write.position.y, write.end.y):
		var y := ty - read.position.y
		var up := maxi(y - 1, 0) * rw
		var down := mini(y + 1, last.y) * rw
		for tx in range(write.position.x, write.end.x):
			var x := tx - read.position.x
			var i := y * rw + x
			var dx := (h[y * rw + mini(x + 1, last.x)] - h[y * rw + maxi(x - 1, 0)]) / (2.0 * cell.x)
			var dz := (h[down + x] - h[up + x]) / (2.0 * cell.y)
			var n := Vector3(-dx, 1.0, -dz).normalized()
			out[k] = h[i]
			out[k + 1] = n.x
			out[k + 2] = n.z
			out[k + 3] = found[i]
			k += 4
	var written := Image.create_from_data(
		write.size.x, write.size.y, false, Image.FORMAT_RGBAF, out.to_byte_array()
	)
	data.blit_rect(written, Rect2i(Vector2i.ZERO, write.size), write.position)
	_changed(_rect_of(write))


## The value of `src` (a `size` grid of floats) at pixel coordinates `p`, between its pixels.
static func _bilinear(src: PackedFloat32Array, size: Vector2i, p: Vector2) -> float:
	var x0 := clampi(floori(p.x), 0, size.x - 1)
	var y0 := clampi(floori(p.y), 0, size.y - 1)
	var x1 := mini(x0 + 1, size.x - 1)
	var y1 := mini(y0 + 1, size.y - 1)
	var t := Vector2(clampf(p.x - x0, 0.0, 1.0), clampf(p.y - y0, 0.0, 1.0))
	var top := lerpf(src[y0 * size.x + x0], src[y0 * size.x + x1], t.x)
	var bottom := lerpf(src[y1 * size.x + x0], src[y1 * size.x + x1], t.x)
	return lerpf(top, bottom, t.y)


## The height at `at` (x, z), between the baked texels.
func height_at(at: Vector2) -> float:
	if data == null:
		return flat_height
	return _sample(at).r


## The ground's normal at `at`, between the baked texels (up where nothing is baked).
func normal_at(at: Vector2) -> Vector3:
	if data == null:
		return Vector3.UP
	var texel := _sample(at)
	var xz := Vector2(texel.g, texel.b)
	return Vector3(xz.x, sqrt(maxf(1.0 - xz.length_squared(), 0.0)), xz.y)


## True where the bake found ground at `at` (or it is flat and inside `area`).
func has_ground(at: Vector2) -> bool:
	if not area.has_point(at):
		return false
	return data == null or _sample(at).a > 0.5


## The slope at `at` in degrees.
func slope_at(at: Vector2) -> float:
	return rad_to_deg(acos(clampf(normal_at(at).y, -1.0, 1.0)))


## How much grass the slope at `at` leaves (1 below `slope_fade.x`, 0 past `slope_fade.y`): the
## part the shader keeps there, and how tall.
func slope_keep(at: Vector2) -> float:
	return 1.0 - smoothstep(slope_fade.x, slope_fade.y, slope_at(at))


## The lowest (x) and highest (y) ground in `rect`: what a cell's bounds need.
func height_range_in(rect: Rect2) -> Vector2:
	if data == null:
		return Vector2(flat_height, flat_height)
	var span := _texels_in(rect.grow(texel_size))
	if span.size.x <= 0 or span.size.y <= 0:
		return Vector2(flat_height, flat_height)
	var low := INF
	var high := -INF
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			var h := data.get_pixel(tx, ty).r
			low = minf(low, h)
			high = maxf(high, h)
	return Vector2(low, high)


## The ground as a texture for the shader (updated when the ground changes).
func ground_texture() -> Texture2D:
	if data == null:
		var flat := Image.create(1, 1, false, Image.FORMAT_RGBAF)
		flat.set_pixel(0, 0, Color(flat_height, 0.0, 0.0, 1.0))
		return ImageTexture.create_from_image(flat)
	if _texture == null:
		_texture = ImageTexture.create_from_image(data)
	return _texture


## Where a ray from `from` along `direction` first meets the ground (within `area`), or null. The
## editor's brushes aim with it; a game can too (where the mouse points on the grass).
func ray_hit(from: Vector3, direction: Vector3, max_distance := 5000.0) -> Variant:
	var dir := direction.normalized()
	if dir == Vector3.ZERO:
		return null
	if data == null:
		if absf(dir.y) < 0.000001:
			return null
		var t := (flat_height - from.y) / dir.y
		if t < 0.0 or t > max_distance:
			return null
		var flat := from + dir * t
		return flat if area.has_point(Vector2(flat.x, flat.z)) else null
	# Only the part of the ray inside the ground's box, marched a texel at a time, then halved.
	if _full_range == Vector2.INF:
		_full_range = height_range_in(area)
	var box := AABB(
		Vector3(area.position.x, _full_range.x - 0.01, area.position.y),
		Vector3(area.size.x, _full_range.y - _full_range.x + 0.02, area.size.y)
	)
	var span := _clip(box, from, dir, max_distance)
	if span == Vector2.INF:
		return null
	var step := texel_size * 0.5
	var t := span.x
	var above := _above(from + dir * t)
	while t < span.y:
		var next := minf(t + step, span.y)
		var point := from + dir * next
		if _above(point) <= 0.0:
			if above <= 0.0:
				return from + dir * t
			var low := t
			var high := next
			for i in 10:
				var middle := (low + high) * 0.5
				if _above(from + dir * middle) > 0.0:
					low = middle
				else:
					high = middle
			return from + dir * high
		above = _above(point)
		t = next
	return null


## The size in texels of `map` (zero when it is not painted).
func map_size(map: StringName) -> Vector2i:
	var texture := map_texture(map)
	return Vector2i(texture.get_width(), texture.get_height()) if texture != null else Vector2i.ZERO


## The size a map the brushes make gets: `paint_texel_size`, never more than MAX_MAP_SIZE a side.
func new_map_size() -> Vector2i:
	var texel := maxf(paint_texel_size, 0.01)
	return Vector2i(
		clampi(ceili(area.size.x / texel), 1, MAX_MAP_SIZE),
		clampi(ceili(area.size.y / texel), 1, MAX_MAP_SIZE)
	)


## The texture of `map` (DENSITY, SIZE, COLOR or a kind's map name): null when none is set.
func map_texture(map: StringName) -> Texture2D:
	match map:
		DENSITY:
			return density_texture
		SIZE:
			return size_texture
		COLOR:
			return color_texture
	return kind_maps.get(map)


## Sets the texture of `map` (null = not painted: its rest everywhere).
func set_map_texture(map: StringName, texture: Texture2D) -> void:
	match map:
		DENSITY:
			density_texture = texture
		SIZE:
			size_texture = texture
		COLOR:
			color_texture = texture
		_:
			if texture == null:
				kind_maps.erase(map)
			else:
				kind_maps[map] = texture
			emit_changed()
	_mark_edited()


## The value of `map` where nothing is painted: grass everywhere (density 1), as tall as the look
## says (size 0.5), the look's ground colour (a clear colour), and none of a kind (its map starts
## empty: the kind grows where it is painted).
static func map_rest(map: StringName) -> Color:
	match map:
		DENSITY:
			return Color(1.0, 0.0, 0.0, 1.0)
		SIZE:
			return Color(0.5, 0.0, 0.0, 1.0)
		COLOR:
			return Color(0.0, 0.0, 0.0, 0.0)
	return Color(0.0, 0.0, 0.0, 1.0)


## What erasing `map` goes to: no grass on DENSITY, else its rest (as the look says, not this kind).
static func map_erased(map: StringName) -> Color:
	return Color(0.0, 0.0, 0.0, 1.0) if map == DENSITY else map_rest(map)


## Paints one dab of `brush` on `map` centred at `at` (x, z), making the map on the first dab.
## Returns the texels it changed. The blades show it at the end of the frame.
func paint(map: StringName, at: Vector2, brush: GrassBrush, pressure := 1.0) -> Rect2i:
	var image := _image_of(map, true)
	var changed := brush.dab(image, area, at, map_erased(map), pressure)
	if changed.has_area():
		_queue_map(map)
	return changed


## Every texel of `map` to `value` (Color.BLACK on DENSITY: no grass until painted back).
func fill_map(map: StringName, value: Color) -> void:
	var image := _image_of(map, true)
	image.fill(value)
	_queue_map(map)


## Removes `map`: back to its rest everywhere.
func clear_map(map: StringName) -> void:
	set_map_texture(map, null)


## `image` (any size, stretched over `area`) as `map`, in a texture kept in this ground.
func import_map(map: StringName, image: Image) -> void:
	var copy := image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.clear_mipmaps()
	copy.convert(_format_of(map))
	set_map_texture(map, GrassMap.from(copy))


## A copy of `map` as an image (null when it is not painted): to save as a PNG and edit elsewhere.
func export_map(map: StringName) -> Image:
	var image := _image_of(map, false)
	if image != null:
		return image.duplicate() as Image
	var texture := map_texture(map)
	if texture == null or texture.get_image() == null:
		return null
	image = texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(_format_of(map))
	return image


## The texels of `map` in `rect` (null when it is not painted): what an undo puts back.
func map_region(map: StringName, rect: Rect2i) -> Image:
	var image := _image_of(map, false)
	return image.get_region(rect) if image != null else null


## Puts `region` (from `map_region`) back into `map` at `at`.
func set_map_region(map: StringName, region: Image, at: Vector2i) -> void:
	var image := _image_of(map, false)
	if image == null or region == null:
		return
	image.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), at)
	_queue_map(map)


## Moves the ground's edges to `new_area` keeping everything where it is in the world: the baked
## heights and the painted maps are cut or extended (with no ground and nothing painted in the new
## parts; bake those, as «Fit area» and the area's handles do). A texture made elsewhere becomes a
## copy kept here. `layout()` before it is what puts it back.
func resize_area(new_area: Rect2) -> void:
	if not new_area.has_area() or new_area.is_equal_approx(area):
		return
	var old_area := area
	var maps: Dictionary[StringName, Texture2D] = {}
	for map in _map_names():
		var image := _image_of(map, true)
		var scale := Vector2(image.get_size()) / old_area.size
		var size := Vector2i(
			clampi(roundi(new_area.size.x * scale.x), 1, MAX_MAP_SIZE),
			clampi(roundi(new_area.size.y * scale.y), 1, MAX_MAP_SIZE)
		)
		maps[map] = GrassMap.from(_reframe(image, old_area, new_area, size, map_rest(map)))
	area = new_area
	if data != null:
		var rest := Color(flat_height, 0.0, 0.0, 0.0)
		data = _reframe(data, old_area, new_area, texture_size(), rest)
		_texture = null
	density_texture = maps.get(DENSITY)
	size_texture = maps.get(SIZE)
	color_texture = maps.get(COLOR)
	var kinds: Dictionary[StringName, Texture2D] = {}
	for map in maps:
		if map != DENSITY and map != SIZE and map != COLOR:
			kinds[map] = maps[map]
	kind_maps = kinds
	_mark_edited()
	_changed(old_area.merge(new_area))
	emit_changed()


## The area, the baked heights and every map's texture as they are now: what `set_layout()` puts
## back (an undo of `resize_area()`).
func layout() -> Dictionary:
	var maps: Dictionary[StringName, Texture2D] = {}
	for map in _map_names():
		maps[map] = map_texture(map)
	return {
		"area": area,
		"data": data.duplicate() as Image if data != null else null,
		"maps": maps,
	}


## Puts back a `layout()`.
func set_layout(saved: Dictionary) -> void:
	area = saved["area"]
	var kept: Image = saved["data"]
	data = kept.duplicate() as Image if kept != null else null
	_texture = null
	var maps: Dictionary = saved["maps"]
	density_texture = maps.get(DENSITY)
	size_texture = maps.get(SIZE)
	color_texture = maps.get(COLOR)
	var kinds: Dictionary[StringName, Texture2D] = {}
	for map in maps:
		if map != DENSITY and map != SIZE and map != COLOR:
			kinds[map] = maps[map]
	kind_maps = kinds
	_mark_edited()
	_changed(area)
	emit_changed()


## Sets `map` to `texture` and, when it is kept here, writes `region` into it at `at`: one step of
## an undo or a redo of a brush stroke (the texture a first stroke made, and the texels it changed).
func put_map(map: StringName, texture: Texture2D, region: Image = null, at := Vector2i.ZERO) -> void:
	if map_texture(map) != texture:
		set_map_texture(map, texture)
	if region != null and texture != null and _owns(texture):
		set_map_region(map, region, at)


## The image a brush paints `map` on, making the map when there is none (filled with its rest; a
## texture made elsewhere is copied into one kept here).
func editable_map(map: StringName) -> Image:
	return _image_of(map, true)


## True when `map` has nothing at all in `rect` (no grass, none of a kind): the field skips the
## cells there, so a painted-out area costs nothing. False when `map` is not painted.
func map_empty_in(map: StringName, rect: Rect2) -> bool:
	var image := _image_of(map, false)
	if image == null or image.get_format() != Image.FORMAT_R8:
		return false
	var size := image.get_size()
	var texel := area.size / Vector2(size)
	var low := ((rect.position - area.position) / texel).floor()
	var high := ((rect.end - area.position) / texel).ceil()
	var span := Rect2i(Vector2i(low), Vector2i(high - low)).intersection(Rect2i(Vector2i.ZERO, size))
	if not span.has_area():
		return true
	var texels := image.get_region(span).get_data()
	return texels.count(0) == texels.size()


## The kinds' map names painted here.
func painted_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(kind_maps.keys())
	return out


## What a bake of all of `area` costs: [rays, megabytes kept].
func bake_cost() -> Vector2:
	var size := texture_size()
	var texels := float(size.x) * size.y
	# Four floats a texel: height, normal x and z, ground.
	return Vector2(texels, texels * 16.0 / 1048576.0)


## The ground changed in `rect`: the field hears it now; the texture goes to the GPU once at the
## end of the frame, however many changes it had (a spiral of craters).
func _changed(rect: Rect2) -> void:
	_full_range = Vector2.INF
	if not _upload_queued:
		_upload_queued = true
		_upload.call_deferred()
	area_changed.emit(rect)


func _upload() -> void:
	_upload_queued = false
	if _texture != null:
		_texture.update(data)


func _ensure_data() -> void:
	var size := texture_size()
	if data == null or data.get_size() != size:
		data = Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
		data.fill(Color(flat_height, 0.0, 0.0, 1.0))
		_texture = null


## The image `map` is painted on: its GrassMap's own. `create` makes the map (filled with its rest)
## when there is none, and copies a texture made elsewhere into a GrassMap kept here.
func _image_of(map: StringName, create: bool) -> Image:
	var texture := map_texture(map)
	if texture is GrassMap:
		var own := texture as GrassMap
		if own.source == null or own.source.is_empty():
			return null
		if own.source.get_format() != _format_of(map):
			own.source.convert(_format_of(map))
		return own.source
	if not create:
		return null
	var image: Image
	if texture == null:
		var size := new_map_size()
		image = Image.create(size.x, size.y, false, _format_of(map))
		image.fill(map_rest(map))
	else:
		# Made elsewhere (an imported file): painting goes to a copy kept in this ground.
		image = texture.get_image()
		if image == null:
			return null
		if image.is_compressed():
			image.decompress()
		image.clear_mipmaps()
		image.convert(_format_of(map))
		print("GrassKit: painting a copy of %s, kept in the ground (%s)" % [
			texture.resource_path if not texture.resource_path.is_empty() else "a texture", map
		])
	set_map_texture(map, GrassMap.from(image))
	return image


## True for a map kept in this ground (a GrassMap: made by a brush, or saved inside it).
func _owns(texture: Texture2D) -> bool:
	return texture is GrassMap


## Puts back a whole baked ground (an undo of «Bake ground»): null = flat.
func restore_data(image: Image) -> void:
	data = image.duplicate() as Image if image != null else null
	_texture = null
	_mark_edited()
	_changed(area)
	emit_changed()


## Every map that has a texture now.
func _map_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for map: StringName in [DENSITY, SIZE, COLOR]:
		if map_texture(map) != null:
			out.append(map)
	for map: StringName in kind_maps:
		if kind_maps[map] != null:
			out.append(map)
	return out


## `image` over `old_area` cut or extended to `new_area` at `size` texels, `rest` where it had
## nothing.
static func _reframe(
	image: Image, old_area: Rect2, new_area: Rect2, size: Vector2i, rest: Color
) -> Image:
	var out := Image.create(size.x, size.y, false, image.get_format())
	out.fill(rest)
	var both := old_area.intersection(new_area)
	if not both.has_area():
		return out
	var old_texel := old_area.size / Vector2(image.get_size())
	var new_texel := new_area.size / Vector2(size)
	var from := Rect2i(
		Vector2i(((both.position - old_area.position) / old_texel).round()),
		Vector2i((both.size / old_texel).round())
	).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var to := Rect2i(
		Vector2i(((both.position - new_area.position) / new_texel).round()),
		Vector2i((both.size / new_texel).round())
	).intersection(Rect2i(Vector2i.ZERO, size))
	if not from.has_area() or not to.has_area():
		return out
	var piece := image.get_region(from)
	if piece.get_size() != to.size:
		piece.resize(to.size.x, to.size.y, Image.INTERPOLATE_BILINEAR)
	out.blit_rect(piece, Rect2i(Vector2i.ZERO, to.size), to.position)
	return out


func _mark_edited() -> void:
	_maps_edited = true
	if not _edited.has(self):
		_edited.append(self)


static func _format_of(map: StringName) -> Image.Format:
	return Image.FORMAT_RGBA8 if map == COLOR else Image.FORMAT_R8


func _queue_map(map: StringName) -> void:
	_mark_edited()
	if _maps_queued.is_empty():
		_upload_maps.call_deferred()
	_maps_queued[map] = true


## Writes the painted images to their textures, once a frame however many dabs it had.
func _upload_maps() -> void:
	for map in _maps_queued:
		var texture := map_texture(map) as GrassMap
		if texture != null:
			texture.refresh()
	var painted := _maps_queued.keys()
	_maps_queued.clear()
	for map: StringName in painted:
		map_painted.emit(map)


## Writes every painted map to its texture now (before saving).
func flush_maps() -> void:
	if not _maps_queued.is_empty():
		_upload_maps()


## Metres the point is above the ground (negative below, INF outside `area`).
func _above(point: Vector3) -> float:
	var at := Vector2(point.x, point.z)
	if not area.has_point(at):
		return INF
	return point.y - height_at(at)


## The part [enter, leave] of the ray inside `box`, within `max_distance` (INF when it misses).
static func _clip(box: AABB, from: Vector3, dir: Vector3, max_distance: float) -> Vector2:
	var near := 0.0
	var far := max_distance
	for axis in 3:
		var low := box.position[axis]
		var high := box.end[axis]
		if absf(dir[axis]) < 0.0000001:
			if from[axis] < low or from[axis] > high:
				return Vector2.INF
			continue
		var a := (low - from[axis]) / dir[axis]
		var b := (high - from[axis]) / dir[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
		if near > far:
			return Vector2.INF
	return Vector2(near, far)


## The texels whose centres fall in `rect`.
func _texels_in(rect: Rect2) -> Rect2i:
	var size := texture_size()
	var cell := area.size / Vector2(size)
	var low := ((rect.position - area.position) / cell - Vector2(0.5, 0.5)).ceil()
	var high := ((rect.end - area.position) / cell - Vector2(0.5, 0.5)).floor() + Vector2.ONE
	var span := Rect2i(Vector2i(low), Vector2i(high - low))
	return span.intersection(Rect2i(Vector2i.ZERO, size))


func _rect_of(span: Rect2i) -> Rect2:
	var cell := area.size / Vector2(texture_size())
	return Rect2(area.position + Vector2(span.position) * cell, Vector2(span.size) * cell)


func _texel_center(tx: int, ty: int) -> Vector2:
	var cell := area.size / Vector2(texture_size())
	return area.position + (Vector2(tx, ty) + Vector2(0.5, 0.5)) * cell


func _texel(tx: int, ty: int) -> Color:
	var size := texture_size()
	return data.get_pixel(clampi(tx, 0, size.x - 1), clampi(ty, 0, size.y - 1))


## The baked texel at `at`, between the texels (as the shader's linear filter reads it).
func _sample(at: Vector2) -> Color:
	var size := texture_size()
	var texel := (at - area.position) / area.size * Vector2(size) - Vector2(0.5, 0.5)
	var low := Vector2i(floori(texel.x), floori(texel.y))
	var t := texel - Vector2(low)
	var top := _texel(low.x, low.y).lerp(_texel(low.x + 1, low.y), t.x)
	var bottom := _texel(low.x, low.y + 1).lerp(_texel(low.x + 1, low.y + 1), t.x)
	return top.lerp(bottom, t.y)


## The normal at a texel, from its neighbours' heights.
func _normal_from_heights(tx: int, ty: int) -> Vector3:
	var cell := area.size / Vector2(texture_size())
	var dx := (_texel(tx + 1, ty).r - _texel(tx - 1, ty).r) / (2.0 * cell.x)
	var dz := (_texel(tx, ty + 1).r - _texel(tx, ty - 1).r) / (2.0 * cell.y)
	return Vector3(-dx, 1.0, -dz).normalized()
