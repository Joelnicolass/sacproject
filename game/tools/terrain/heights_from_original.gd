extends SceneTree

## Requiere el juego original instalado para los mapas que vienen de él (`--original=<carpeta del juego>` o la variable
## SACRIFICE_DIR; también sirve SAC_ROOT). Los mapas de prueba no lo necesitan.
## Writes scenes/map/maps/<tag>/heights.res (TerrainHeights), the one source of a map's ground, once per map:
##  - a map of the original: the exact heights and voids of its .scp (HMAP: u16, bit 15 = void, the rest = height in
##    steps of 0.1 m), the heights under the voids included, all lowered by the lowest land (the base import_map.py
##    subtracts), so its land is the land of today's terrain.res;
##  - any other map (test_flat, and test_flat4, whose definition points at test_flat's terrain.res): the land vertices
##    of the ground its MapDefinition loads today, kept as they are, and the voids filled by diffusion from the land.
## Idempotent: an unchanged heights.res is not written. Deletes nothing (S3b does). One-shot of plan 063D S3.
## "$GODOT" --headless --path game --script res://tools/terrain/heights_from_original.gd -- [--original=<dir>] [--map=<tag>]

const MAPS_DIR := "res://scenes/map/maps"
## The .scp of each map that comes from the original, relative to the game's maps folder.
const ORIGINAL_SCP := {
	"alpine_meadow": "(2) Alpine Meadow.scp",
	"high_noon": "(2) High Noon.scp",
	"peaks": "(2) Peaks.scp",
	"peasantville": "(2) Peasantville.scp",
	"roads": "(2) Roads.scp",
	"tutorial_valley": "Tutorial/(tu02).scp",
	"winter_wonder": "(4) WinterWonder.scp",
}
const VOID_BIT := 0x8000
const HEIGHT_STEP_M := 0.1
const NEEDS_ORIGINAL := "ERROR: los mapas del original necesitan el juego original instalado. Pasá --original=<carpeta del juego, la que tiene maps/> o exportá SACRIFICE_DIR. El juego no viene en el repositorio."
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _initialize() -> void:
	var original := OS.get_environment("SACRIFICE_DIR")
	if original.is_empty():
		original = OS.get_environment("SAC_ROOT")
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--original="):
			original = argument.substr(11)
		elif argument.begins_with("--map="):
			only = argument.substr(6)
	var tags := Array(DirAccess.get_directories_at(MAPS_DIR)).filter(func(tag: String) -> bool: return only.is_empty() or tag == only)
	if tags.is_empty():
		push_error("heights: no map '%s' in %s." % [only, MAPS_DIR])
		quit(1)
		return
	if tags.any(func(tag: String) -> bool: return ORIGINAL_SCP.has(tag)) and not DirAccess.dir_exists_absolute(original):
		printerr(NEEDS_ORIGINAL)
		quit(2)
		return
	var failed := 0
	for tag: String in tags:
		var heights: TerrainHeights = _from_original(original, ORIGINAL_SCP[tag]) if ORIGINAL_SCP.has(tag) else _from_definition(tag)
		if heights == null or not _write(heights, MAPS_DIR.path_join(tag).path_join("heights.res"), tag):
			failed += 1
	quit(1 if failed > 0 else 0)


## The heights of a .scp in the game's maps folder (`root` may be the game folder, its maps/ or its data/).
func _from_original(root: String, relative: String) -> TerrainHeights:
	var hmap := PackedByteArray()
	for candidate: String in [root.path_join("maps").path_join(relative), root.path_join(relative), root.path_join("../maps").path_join(relative)]:
		if FileAccess.file_exists(candidate):
			hmap = _hmap(candidate)
			break
	var side := TerrainGrid.SIDE
	if hmap.size() < 4 + 2 * TerrainHeights.COUNT or hmap.decode_u16(0) != side or hmap.decode_u16(2) != side:
		push_error("heights: %s is missing in %s, or its HMAP is not %d x %d." % [relative, root, side, side])
		return null
	var heights_m := PackedFloat32Array()
	heights_m.resize(TerrainHeights.COUNT)
	var void_mask := PackedByteArray()
	void_mask.resize(TerrainHeights.COUNT)
	var raw_m: Array[float] = []
	raw_m.resize(TerrainHeights.COUNT)
	var base := INF
	for v in TerrainHeights.COUNT:
		var raw := hmap.decode_u16(4 + 2 * v)
		raw_m[v] = float(raw & ~VOID_BIT) * HEIGHT_STEP_M
		void_mask[v] = 1 if (raw & VOID_BIT) != 0 else 0
		if void_mask[v] == 0:
			base = minf(base, raw_m[v])
	if base == INF:
		push_error("heights: %s has no land." % relative)
		return null
	for v in TerrainHeights.COUNT:
		heights_m[v] = raw_m[v] - base  # in double, as import_map.py, then stored as float32 like terrain.res
	return _make(heights_m, void_mask)


## The HMAP payload of a .scp (a WAD: a zlib directory at the offset in bytes 4-7, 4-byte names stored reversed).
## Ref: tools/import/sac_formats/wad.py extract().
static func _hmap(path: String) -> PackedByteArray:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20:
		return PackedByteArray()
	var info := bytes.slice(bytes.decode_u32(4)).decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	var wanted := "PAMH".to_ascii_buffer()
	var offset := 20
	var at := 0
	while info.size() - at >= 28:
		var packed_size := info.decode_u32(at + 8)
		var size := info.decode_u32(at + 12)
		var kind := info.decode_u32(at + 20)
		if kind > 2:
			kind = 1 if info.decode_u32(at + 16) != 0 else (2 if packed_size < size else 0)
		if info.slice(at + 4, at + 8) == wanted:
			var blob := bytes.slice(offset, offset + (size if kind == 0 else packed_size))
			return blob if kind == 0 else blob.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
		offset += size if kind == 0 else (packed_size if kind == 2 else 0)
		at += 28
	return PackedByteArray()


## The heights of the ground a map's definition loads today: every corner of a land triangle, as it is.
func _from_definition(tag: String) -> TerrainHeights:
	var definition := load(MAPS_DIR.path_join(tag).path_join(tag + ".tres")) as MapDefinition
	var soup: MapTerrainData = definition.terrain if definition != null else null
	if soup == null or not soup.is_valid():
		push_error("heights: map '%s' has no ground to convert (no MapDefinition.terrain)." % tag)
		return null
	var side := TerrainGrid.SIDE
	var heights_m := PackedFloat32Array()
	heights_m.resize(TerrainHeights.COUNT)
	var void_mask := PackedByteArray()
	void_mask.resize(TerrainHeights.COUNT)
	void_mask.fill(1)
	var vertices := soup.vertices
	var indices := soup.indices
	for t in range(0, indices.size(), 3):
		var corners: Array[Vector3] = [vertices[indices[t]], vertices[indices[t + 1]], vertices[indices[t + 2]]]
		if TerrainRules.is_wall(corners[0], corners[1], corners[2]):
			continue
		for corner in corners:
			var v := clampi(roundi(corner.z / TerrainGrid.CELL_M), 0, side - 1) * side + clampi(roundi(corner.x / TerrainGrid.CELL_M), 0, side - 1)
			heights_m[v] = corner.y
			void_mask[v] = 0
	return _make(_filled(heights_m, void_mask), void_mask)


## `heights_m` with every void vertex set to the mean of its land (or already filled) neighbours, ring after ring
## outward from the land. All land: nothing changes; no land: all zero.
static func _filled(heights_m: PackedFloat32Array, void_mask: PackedByteArray) -> PackedFloat32Array:
	var side := TerrainGrid.SIDE
	var known := PackedByteArray()
	known.resize(TerrainHeights.COUNT)
	var ring := PackedInt32Array()
	for v in TerrainHeights.COUNT:
		known[v] = 1 - void_mask[v]
		if known[v] == 1:
			ring.append(v)
	while not ring.is_empty():
		var next := PackedInt32Array()
		for v in ring:
			for step in STEPS:
				var x := v % side + step.x
				var z := v / side + step.y
				if x >= 0 and z >= 0 and x < side and z < side and known[z * side + x] == 0:
					known[z * side + x] = 2  # queued in this ring
					next.append(z * side + x)
		for v in next:
			var sum := 0.0
			var count := 0
			for step in STEPS:
				var x := v % side + step.x
				var z := v / side + step.y
				if x >= 0 and z >= 0 and x < side and z < side and known[z * side + x] == 1:
					sum += heights_m[z * side + x]
					count += 1
			heights_m[v] = sum / count
		for v in next:
			known[v] = 1
		ring = next
	return heights_m


static func _make(heights_m: PackedFloat32Array, void_mask: PackedByteArray) -> TerrainHeights:
	var heights := TerrainHeights.new()
	heights.heights_m = heights_m
	heights.void_mask = void_mask
	return heights


static func _write(heights: TerrainHeights, path: String, tag: String) -> bool:
	var old: TerrainHeights = null
	if ResourceLoader.exists(path):
		old = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TerrainHeights
	if old != null and old.checksum() == heights.checksum():
		print("heights %s: unchanged" % tag)
		return true
	var error := ResourceSaver.save(heights, path, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("heights %s: could not write %s (error %d)." % [tag, path, error])
		return false
	print("heights %s: written %s (%d land vertices, checksum %d)" % [tag, path, heights.void_mask.count(0), heights.checksum()])
	return true
