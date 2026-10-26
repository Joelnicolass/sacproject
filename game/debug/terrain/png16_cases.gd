extends SceneTree

## Checks the PNG codec of a map's heights.png (addons/terrain_tools/png16.gd) and the pair of pictures (map_images.gd),
## headless, without a map:
##  - a random 256 x 256 picture of 16 bits goes there and back exactly, in memory and through a file;
##  - a picture written with each row filter (0 to 4, and all of them mixed), at 1, 8 and 16 bits, reads back exactly;
##    at 1 and 8 bits Godot's own PNG loader (libpng) must read the same pixels, so the filters are checked against a
##    decoder that is not ours;
##  - heights and voids go through heights.png and void.png within half a step (0.05 m) and the voids bit for bit;
##  - a bad file fails with its message: not a PNG, cut short, bad checksum, colour, palette, interlace, wrong size.
## Prints PNG16 CASES PASS or FAIL. Not: the importer in the editor (the final pass imports the maps and runs faces_parity).
## "$GODOT" --headless --path game --script res://debug/terrain/png16_cases.gd

const Png16 := preload("res://addons/terrain_tools/png16.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const WORK_DIR := "user://png16_cases"
const SIDE := 256
const FILTER_SIDE := 37  ## an odd width, so a 1-bit row ends inside a byte

var _failed := PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(WORK_DIR)
	_random_round_trip()
	for depth: int in [1, 8, 16]:
		for filter in 6:  # 5 = every row a different filter
			_filter_case(depth, filter)
	_map_images_round_trip()
	_bad_files()
	for name in _failed:
		print("  FAIL ", name)
	print("PNG16 CASES %s" % ("PASS" if _failed.is_empty() else "FAIL (%d)" % _failed.size()))
	quit(0 if _failed.is_empty() else 1)


func _check(name: String, ok: bool) -> void:
	if not ok:
		_failed.append(name)


func _random_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	var samples := PackedInt32Array()
	samples.resize(SIDE * SIDE)
	for v in samples.size():
		samples[v] = rng.randi_range(0, 65535)
	var picture := Png16.decode(Png16.encode(SIDE, SIDE, samples, 16))
	_check("random_16_memory", picture.error.is_empty() and picture.width == SIDE and picture.height == SIDE and picture.bit_depth == 16 and picture.samples == samples)
	var path := WORK_DIR.path_join("random.png")
	var from_file: Png16.Picture = null
	if Png16.write_file(path, SIDE, SIDE, samples, 16) == OK:
		from_file = Png16.read_file(path)
	_check("random_16_file", from_file != null and from_file.error.is_empty() and from_file.samples == samples)
	_check("encode_refuses_out_of_range", Png16.encode(2, 1, PackedInt32Array([0, 256]), 8).is_empty())


## A FILTER_SIDE-square picture whose rows are written with `filter` (5: row y uses filter y % 5).
func _filter_case(depth: int, filter: int) -> void:
	var name := "filter_%d_at_%d_bits" % [filter, depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 * depth + filter
	var samples := PackedInt32Array()
	samples.resize(FILTER_SIDE * FILTER_SIDE)
	for v in samples.size():
		samples[v] = rng.randi_range(0, (1 << depth) - 1)
	var bytes := _filtered_png(samples, depth, filter)
	var picture := Png16.decode(bytes)
	_check(name, picture.error.is_empty() and picture.bit_depth == depth and picture.samples == samples)
	if depth == 16:
		return
	var image := Image.new()
	var loaded := image.load_png_from_buffer(bytes) == OK
	if loaded:
		image.convert(Image.FORMAT_L8)
	var grey := image.get_data() if loaded else PackedByteArray()
	var expected := PackedByteArray()
	for value in samples:
		expected.append(value * (255 if depth == 1 else 1))
	_check(name + "_libpng", loaded and grey == expected)


## The PNG of `samples` (FILTER_SIDE wide and high) with every row through the forward filter.
static func _filtered_png(samples: PackedInt32Array, depth: int, filter: int) -> PackedByteArray:
	var stride := (FILTER_SIDE * depth + 7) / 8
	var bpp := maxi(1, depth / 8)
	var rows: Array[PackedByteArray] = []
	for y in FILTER_SIDE:
		var row := PackedByteArray()
		row.resize(stride)
		for x in FILTER_SIDE:
			var value := samples[y * FILTER_SIDE + x]
			if depth == 16:
				row[2 * x] = value >> 8
				row[2 * x + 1] = value & 0xFF
			elif depth == 8:
				row[x] = value
			else:
				row[x / 8] = row[x / 8] | (value << (7 - x % 8))
		rows.append(row)
	var raw := PackedByteArray()
	for y in FILTER_SIDE:
		var kind := y % 5 if filter == 5 else filter
		raw.append(kind)
		for i in stride:
			var left: int = rows[y][i - bpp] if i >= bpp else 0
			var up: int = rows[y - 1][i] if y > 0 else 0
			var up_left: int = rows[y - 1][i - bpp] if y > 0 and i >= bpp else 0
			raw.append((rows[y][i] - Png16.predict(kind, left, up, up_left)) & 0xFF)
	var header := _be32(FILTER_SIDE) + _be32(FILTER_SIDE) + PackedByteArray([depth, 0, 0, 0, 0])
	return Png16.signature() + Png16.chunk("IHDR", header) + Png16.chunk("IDAT", raw.compress(FileAccess.COMPRESSION_DEFLATE)) + Png16.chunk("IEND", PackedByteArray())


func _map_images_round_trip() -> void:
	var heights := TerrainHeights.new()
	var heights_m := PackedFloat32Array()
	heights_m.resize(TerrainHeights.COUNT)
	var void_mask := PackedByteArray()
	void_mask.resize(TerrainHeights.COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for v in TerrainHeights.COUNT:
		heights_m[v] = rng.randf_range(0.0, 3000.0)
		void_mask[v] = 1 if rng.randf() < 0.3 else 0
	heights.heights_m = heights_m
	heights.void_mask = void_mask
	var written := MapImages.write(heights, WORK_DIR, 0.1)
	var back := MapImages.read(WORK_DIR.path_join(MapImages.HEIGHTS_FILE), 0.1)
	var close := back.error.is_empty() and back.heights != null and back.heights.is_valid()
	if close:
		for v in TerrainHeights.COUNT:
			close = close and absf(back.heights.height(v) - heights.height(v)) <= 0.05 + 1e-3
	_check("map_images_heights_within_half_step", written.error.is_empty() and close)
	_check("map_images_voids_exact", close and back.heights.void_mask == void_mask)
	_check("map_images_unchanged_not_rewritten", MapImages.write(heights, WORK_DIR, 0.1).written.is_empty())
	var in_units := MapImages.read(WORK_DIR.path_join(MapImages.HEIGHTS_FILE), 1.0)
	_check("map_images_scale_option", in_units.heights != null and in_units.heights.height(0) == float(MapImages.units(heights, 0.1)[0]))


func _bad_files() -> void:
	var good := Png16.encode(4, 4, PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]), 16)
	_refused("empty", PackedByteArray(), "not a PNG")
	_refused("not_png", "hello, this is not a picture".to_utf8_buffer(), "not a PNG")
	_refused("cut_short", good.slice(0, good.size() - 20), "cut short")
	var damaged := good.duplicate()
	damaged[good.size() - 20] = damaged[good.size() - 20] ^ 0xFF
	_refused("bad_checksum", damaged, "checksum")
	_refused("colour", _header_only(8, 2, 0), "colour")
	_refused("palette", _header_only(8, 3, 0), "palette")
	_refused("grey_alpha", _header_only(8, 4, 0), "alpha")
	_refused("interlaced", _header_only(16, 0, 1), "interlaced")
	var small := WORK_DIR.path_join("small")
	DirAccess.make_dir_recursive_absolute(small)
	var flat := PackedInt32Array()
	flat.resize(128 * 128)
	Png16.write_file(small.path_join(MapImages.HEIGHTS_FILE), 128, 128, flat, 16)
	var result := MapImages.read(small.path_join(MapImages.HEIGHTS_FILE))
	_check("wrong_size", result.heights == null and result.error.contains("128 x 128") and result.error.contains("256 x 256"))
	_check("missing_file", MapImages.read(WORK_DIR.path_join("nothing/heights.png")).error.contains("does not exist"))


func _refused(name: String, bytes: PackedByteArray, words: String) -> void:
	var picture := Png16.decode(bytes)
	_check("refuses_" + name, picture.samples.is_empty() and picture.error.contains(words))


## A 4 x 4 PNG with a valid IHDR of that kind and an empty IDAT: the header alone must be refused.
static func _header_only(depth: int, colour: int, interlace: int) -> PackedByteArray:
	var header := _be32(4) + _be32(4) + PackedByteArray([depth, colour, 0, 0, interlace])
	return Png16.signature() + Png16.chunk("IHDR", header) + Png16.chunk("IDAT", PackedByteArray()) + Png16.chunk("IEND", PackedByteArray())


static func _be32(value: int) -> PackedByteArray:
	return PackedByteArray([(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF])
