extends RefCounted

## The picture half of roundtrip_cases: heights and voids through heights.png and void.png (MapImages) within half a 0.1 m
## step and the voids bit for bit, an unchanged picture not written again, a stale void.png gone, and the named refusals of
## reading them (missing, not a PNG, wrong size, bad height step). Works in the folder it is given. Not: Blender, the bed.

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")


## The names of the cases that failed, working in `folder` (`missing`: a folder without pictures).
static func check(folder: String, missing: String) -> PackedStringArray:
	var failed := PackedStringArray()
	_round_trip(folder, failed)
	_refusals(folder, missing, failed)
	return failed


static func _check(failed: PackedStringArray, name: String, ok: bool) -> void:
	if not ok:
		failed.append(name)


static func _round_trip(folder: String, failed: PackedStringArray) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 4063
	var made := TerrainEdits.flat(0.0)
	var heights := made.heights_m.duplicate()
	var mask := made.void_mask.duplicate()
	for v in TerrainGrid.COUNT:
		heights[v] = random.randf_range(0.0, BrushRules.MAX_HEIGHT_M)
		mask[v] = 1 if random.randf() < 0.2 else 0
	made.heights_m = heights
	made.void_mask = mask
	_check(failed, "png16_write", MapImages.write(made, folder).error.is_empty())
	var back := MapImages.read(folder.path_join(MapImages.HEIGHTS_FILE)).heights
	var worst := 0.0
	for v in TerrainGrid.COUNT:
		worst = maxf(worst, absf(back.heights_m[v] - heights[v])) if back != null else INF
	_check(failed, "png16_heights_within_0.05_m (worst %.4f)" % worst, worst <= 0.05 + 1e-4)
	_check(failed, "png16_voids_exact", back != null and back.void_mask == mask)
	_check(failed, "png16_unchanged_not_written", MapImages.write(back, folder).written.is_empty())
	_check(failed, "png16_stale_void_goes", MapImages.write(TerrainEdits.flat(10.0), folder).written.has(folder.path_join(MapImages.VOID_FILE))
			and not FileAccess.file_exists(folder.path_join(MapImages.VOID_FILE)))


## Reading the pictures refuses with a reason that names the file.
static func _refusals(folder: String, missing: String, failed: PackedStringArray) -> void:
	var heights := folder.path_join(MapImages.HEIGHTS_FILE)
	_refused(failed, "missing", missing.path_join(MapImages.HEIGHTS_FILE), "does not exist")
	_check(failed, "bad_step", not MapImages.read(heights, 0.0).error.is_empty())
	var small := Image.create_empty(128, 128, false, Image.FORMAT_L8)
	small.save_png(folder.path_join(MapImages.VOID_FILE))
	_refused(failed, "void_wrong_size", heights, "128 x 128")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(MapImages.VOID_FILE)))
	var file := FileAccess.open(heights, FileAccess.WRITE)
	file.store_string("not a picture")
	file.close()
	_refused(failed, "not_a_png", heights, heights)
	small.save_png(heights)
	_refused(failed, "heights_wrong_size", heights, "128 x 128")


static func _refused(failed: PackedStringArray, name: String, path: String, said: String) -> void:
	var error := MapImages.read(path).error
	_check(failed, "refused_%s (%s)" % [name, error], not error.is_empty() and error.contains(said))
