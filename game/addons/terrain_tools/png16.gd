@tool
extends RefCounted

## Reads and writes grey PNG files of up to 16 bits per pixel, the format a map's heights.png is kept in: Godot's Image
## loads PNG at 8 bits per channel only. Writing gives one IDAT, filter 0, 8 or 16 bits. Reading takes the five row
## filters and 1, 2, 4, 8 or 16 bits, and fails with a message on anything else: colour, palette, alpha, interlace, a bad
## checksum, a file cut short. Not: what a value means (MapImages), importing (TerrainHeightsImporter).
## The zlib stream comes from PackedByteArray.compress(COMPRESSION_DEFLATE), which writes the zlib header and Adler-32
## (Godot's core/io/compression.cpp opens deflate with window_bits 15, the zlib wrapper; gzip is 15 + 16).

const GREY := 0  ## PNG colour type: grey, no alpha
const DEPTHS: Array[int] = [1, 2, 4, 8, 16]
const COLOUR_TYPES := {2: "colour (RGB)", 3: "palette (indexed colour)", 4: "grey with alpha", 6: "colour with alpha (RGBA)"}

static var _crc_table := PackedInt64Array()


## A decoded picture. `error` is empty when the file was read; otherwise it says why not and the rest is empty.
class Picture:
	var width := 0
	var height := 0
	var bit_depth := 0
	## One value per pixel, row by row, from 0 to 2^bit_depth - 1.
	var samples := PackedInt32Array()
	var error := ""


## The PNG file of a `width` x `height` grey picture (`samples` row by row, each 0 .. 2^bit_depth - 1; 8 or 16 bits).
## Empty, with an error pushed, when the samples do not fit.
static func encode(width: int, height: int, samples: PackedInt32Array, bit_depth: int = 16) -> PackedByteArray:
	if (bit_depth != 8 and bit_depth != 16) or width <= 0 or height <= 0 or samples.size() != width * height:
		push_error("png16: cannot write %d x %d at %d bits from %d samples." % [width, height, bit_depth, samples.size()])
		return PackedByteArray()
	var top := (1 << bit_depth) - 1
	var row_bytes := width * bit_depth / 8
	var raw := PackedByteArray()
	raw.resize(height * (row_bytes + 1))  # new bytes are 0: every row starts with filter 0
	var at := 0
	for y in height:
		at += 1
		for x in width:
			var value := samples[y * width + x]
			if value < 0 or value > top:
				push_error("png16: sample %d at (%d, %d) is outside 0 .. %d." % [value, x, y, top])
				return PackedByteArray()
			if bit_depth == 16:
				raw[at] = value >> 8
				at += 1
			raw[at] = value & 0xFF
			at += 1
	var header := _be32(width) + _be32(height) + PackedByteArray([bit_depth, GREY, 0, 0, 0])
	return signature() + chunk("IHDR", header) + chunk("IDAT", raw.compress(FileAccess.COMPRESSION_DEFLATE)) + chunk("IEND", PackedByteArray())


## The picture in the bytes of a PNG file (see Picture.error).
static func decode(bytes: PackedByteArray) -> Picture:
	var picture := Picture.new()
	if bytes.size() < 8 or bytes.slice(0, 8) != signature():
		return _failed(picture, "not a PNG file (the first 8 bytes are not the PNG signature)")
	var data := PackedByteArray()
	var at := 8
	var ended := false
	while not ended:
		if at + 12 > bytes.size():
			return _failed(picture, "the file is cut short (no IEND chunk)")
		var length := _u32(bytes, at)
		var kind := bytes.slice(at + 4, at + 8)
		var name := kind.get_string_from_ascii()
		if at + 12 + length > bytes.size():
			return _failed(picture, "the file is cut short inside chunk %s" % name)
		var body := bytes.slice(at + 8, at + 8 + length)
		if crc32(kind + body) != _u32(bytes, at + 8 + length):
			return _failed(picture, "bad checksum in chunk %s (the file is damaged)" % name)
		if at == 8 and name != "IHDR":
			return _failed(picture, "the first chunk is %s, not IHDR" % name)
		if name == "IHDR":
			var refused := _header(picture, body)
			if not refused.is_empty():
				return _failed(picture, refused)
		elif name == "IDAT":
			data.append_array(body)
		elif name == "IEND":
			ended = true
		elif (kind[0] & 0x20) == 0:
			return _failed(picture, "chunk %s is not supported (a palette or another critical chunk)" % name)
		at += 12 + length
	var stride := (picture.width * picture.bit_depth + 7) / 8
	var raw := data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE) if not data.is_empty() else PackedByteArray()
	if raw.size() != picture.height * (stride + 1):
		return _failed(picture, "the pixel data is damaged or cut short (%d bytes, expected %d)" % [raw.size(), picture.height * (stride + 1)])
	var refused := _unfilter(raw, stride, maxi(1, picture.bit_depth / 8), picture.height)
	if not refused.is_empty():
		return _failed(picture, refused)
	picture.samples = _samples(raw, stride, picture.width, picture.height, picture.bit_depth)
	return picture


static func read_file(path: String) -> Picture:
	if not FileAccess.file_exists(path):
		return _failed(Picture.new(), "%s does not exist" % path)
	return decode(FileAccess.get_file_as_bytes(path))


## OK, or the error of writing the file. Writes nothing when `samples` do not fit (see encode).
static func write_file(path: String, width: int, height: int, samples: PackedInt32Array, bit_depth: int = 16) -> Error:
	var bytes := encode(width, height, samples, bit_depth)
	if bytes.is_empty():
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	return OK


static func signature() -> PackedByteArray:
	return PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])


## One chunk: length, the 4-letter type, the body and the CRC-32 of type and body.
static func chunk(type: String, body: PackedByteArray) -> PackedByteArray:
	var kind := type.to_ascii_buffer()
	return _be32(body.size()) + kind + body + _be32(crc32(kind + body))


## The CRC-32 PNG and zlib use (polynomial 0xEDB88320), as an unsigned 32-bit number.
static func crc32(bytes: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n in 256:
			var c := n
			for k in 8:
				c = (0xEDB88320 ^ (c >> 1)) if (c & 1) != 0 else (c >> 1)
			_crc_table[n] = c
	var crc := 0xFFFFFFFF
	for b in bytes:
		crc = _crc_table[(crc ^ b) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


## What a row filter adds back to a byte, from the byte on its left, the one above and the one above-left (0 off the
## picture). Filter 0 none, 1 left, 2 up, 3 their mean, 4 Paeth.
static func predict(filter: int, left: int, up: int, up_left: int) -> int:
	if filter == 1:
		return left
	if filter == 2:
		return up
	if filter == 3:
		return (left + up) >> 1
	if filter == 4:
		var p := left + up - up_left
		var to_left := absi(p - left)
		var to_up := absi(p - up)
		var to_up_left := absi(p - up_left)
		if to_left <= to_up and to_left <= to_up_left:
			return left
		return up if to_up <= to_up_left else up_left
	return 0


## Empty when IHDR describes a picture this codec reads; otherwise why not.
static func _header(picture: Picture, body: PackedByteArray) -> String:
	if body.size() != 13:
		return "the IHDR chunk is damaged"
	picture.width = _u32(body, 0)
	picture.height = _u32(body, 4)
	picture.bit_depth = body[8]
	var colour := body[9]
	if COLOUR_TYPES.has(colour):
		return "it is %s; save it as grey (grayscale) without alpha, 16 bits" % COLOUR_TYPES[colour]
	if colour != GREY or not DEPTHS.has(picture.bit_depth) or body[10] != 0 or body[11] != 0:
		return "unknown PNG kind (colour type %d, %d bits, compression %d, filter %d)" % [colour, picture.bit_depth, body[10], body[11]]
	if body[12] != 0:
		return "it is interlaced (Adam7); save it without interlace"
	if picture.width <= 0 or picture.height <= 0:
		return "it has no pixels"
	return ""


## Undoes the row filters in place (`bpp`: bytes per pixel, at least 1). Empty, or why not.
static func _unfilter(raw: PackedByteArray, stride: int, bpp: int, height: int) -> String:
	for y in height:
		var start := y * (stride + 1) + 1
		var filter := raw[start - 1]
		if filter > 4:
			return "row %d has an unknown filter (%d)" % [y, filter]
		if filter == 0:
			continue
		var above := start - stride - 1
		for i in stride:
			var left := raw[start + i - bpp] if i >= bpp else 0
			var up := raw[above + i] if y > 0 else 0
			var up_left := raw[above + i - bpp] if y > 0 and i >= bpp else 0
			raw[start + i] = (raw[start + i] + predict(filter, left, up, up_left)) & 0xFF
	return ""


static func _samples(raw: PackedByteArray, stride: int, width: int, height: int, bit_depth: int) -> PackedInt32Array:
	var samples := PackedInt32Array()
	samples.resize(width * height)
	var per_byte := maxi(1, 8 / bit_depth)
	var mask := (1 << bit_depth) - 1
	for y in height:
		var start := y * (stride + 1) + 1
		for x in width:
			var value := 0
			if bit_depth == 16:
				value = (raw[start + 2 * x] << 8) | raw[start + 2 * x + 1]
			elif bit_depth == 8:
				value = raw[start + x]
			else:
				value = (raw[start + x / per_byte] >> (8 - bit_depth * (x % per_byte + 1))) & mask
			samples[y * width + x] = value
	return samples


static func _failed(picture: Picture, message: String) -> Picture:
	picture.width = 0
	picture.height = 0
	picture.samples = PackedInt32Array()
	picture.error = message
	return picture


static func _u32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]


static func _be32(value: int) -> PackedByteArray:
	return PackedByteArray([(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF])
