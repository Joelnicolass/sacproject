extends SceneTree

## Requiere el juego original instalado para los mapas que vienen de él (`--original=<carpeta del juego>` o la variable
## SACRIFICE_DIR; también sirve SAC_ROOT). Los mapas de prueba no lo necesitan.
## Writes scenes/map/maps/<tag>/heights.png (grey, 16 bits, value x 0.1 m) and void.png (white = void), the one source
## of a map's ground (the addon terrain_tools imports the pair as its TerrainHeights), once per map:
##  - a map of the original: the exact heights and voids of its .scp (HMAP: u16, bit 15 = void, the rest = height in
##    steps of 0.1 m), the heights under the voids included, all lowered by the lowest land (the base import_map.py
##    subtracts), so its land is the land of today's terrain.res. A height under a void that lies below the lowest land
##    cannot be stored (heights.png has no sign): it is kept at the lowest land and counted. Only a filled void of the
##    map would show it, and nothing in a match fills one;
##  - any other map (test_flat, and test_flat4, whose definition points at test_flat's terrain.res): the land vertices
##    of the ground its MapDefinition loads today, kept as they are, and the voids filled by diffusion from the land.
## Fails a map whose land (or, from the original, any vertex) is not a whole number of 0.1 m, and checks the written
## pictures read back the same. Idempotent: an unchanged picture is not written. One-shot of plan 063D S3.
## Import again after it (`--import`) so the new pictures become TerrainHeights.
## "$GODOT" --headless --path game --script res://tools/terrain/heights_from_original.gd -- [--original=<dir>] [--map=<tag>]

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
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
const HEIGHT_STEP_M := MapImages.DEFAULT_METRES_PER_UNIT
## How far a height may be from a whole number of HEIGHT_STEP_M and still count as one (float32 rounding).
const EXACT_TOLERANCE_M := 1e-3
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
		if heights == null or not _write(heights, MAPS_DIR.path_join(tag), tag, ORIGINAL_SCP.has(tag)):
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


## Writes the pictures of `heights` into `folder`, after checking the heights are whole steps (land always; every
## vertex when `all_exact`, a map of the original), and reads them back to check they give the same ground.
static func _write(heights: TerrainHeights, folder: String, tag: String, all_exact: bool) -> bool:
	var units := MapImages.units(heights, HEIGHT_STEP_M)
	var inexact := 0
	var below := 0
	for v in TerrainHeights.COUNT:
		if heights.height(v) < -EXACT_TOLERANCE_M:
			below += 1
		elif (all_exact or not heights.is_void(v)) and absf(heights.height(v) - units[v] * HEIGHT_STEP_M) > EXACT_TOLERANCE_M:
			inexact += 1
	if inexact > 0:
		push_error("heights %s: %d heights are not a whole number of %s m; heights.png cannot keep them exact." % [tag, inexact, HEIGHT_STEP_M])
		return false
	var result := MapImages.write(heights, folder, HEIGHT_STEP_M)
	if not result.error.is_empty():
		push_error("heights %s: %s" % [tag, result.error])
		return false
	var back := MapImages.read(folder.path_join(MapImages.HEIGHTS_FILE), HEIGHT_STEP_M)
	if not back.error.is_empty() or back.heights.void_mask != heights.void_mask or _differing_land(heights, back.heights) > 0:
		push_error("heights %s: the written pictures do not read back as the same ground. %s" % [tag, back.error])
		return false
	print("heights %s: %s (%d land vertices, %d heights under voids kept at the lowest land)" % [
			tag, ", ".join(result.written) if not result.written.is_empty() else "unchanged", heights.void_mask.count(0), below])
	return true


## Land vertices whose height differs by more than EXACT_TOLERANCE_M between the two.
static func _differing_land(a: TerrainHeights, b: TerrainHeights) -> int:
	var count := 0
	for v in TerrainHeights.COUNT:
		if not a.is_void(v) and absf(a.height(v) - b.height(v)) > EXACT_TOLERANCE_M:
			count += 1
	return count
