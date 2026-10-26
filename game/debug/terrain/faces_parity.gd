extends SceneTree

## Checks, map by map, that the ground TerrainFaces derives from heights.png (the TerrainHeights the addon terrain_tools
## imports from heights.png and void.png: import first) is the ground the map loads today (the
## terrain.res of its MapDefinition): the same multiset of triangles, positions rounded to 1e-4 and winding kept, land
## and walls counted apart, and the same land height at two points of every cell. A test map (its ground does not
## come from the original) may gain walls on its rim and pick the other diagonal of a flat cell: that is reported, not
## failed, while its heights match and it loses no wall. Not: the mesh or the collision (they read the same triangles).
## Runs before S3b deletes terrain.res and MapDefinition.terrain.
## "$GODOT" --headless --path game --script res://debug/terrain/faces_parity.gd [-- --map=<tag>]

const MAPS_DIR := "res://scenes/map/maps"
const ROUND := 1e4  ## positions are compared in steps of 1e-4 m
const HEIGHT_TOLERANCE_M := 1e-4
## Where in a cell the height is sampled, as a fraction of the cell (off both diagonals).
const SAMPLES: Array[Vector2] = [Vector2(0.25, 0.6), Vector2(0.7, 0.35)]


func _initialize() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			only = argument.substr(6)
	var checked := 0
	var failed := 0
	for tag in DirAccess.get_directories_at(MAPS_DIR):
		if not only.is_empty() and tag != only:
			continue
		checked += 1
		if not _check(tag):
			failed += 1
	print("FACES PARITY %s" % ("PASS" if checked > 0 and failed == 0 else "FAIL"))
	quit(0 if checked > 0 and failed == 0 else 1)


func _check(tag: String) -> bool:
	var folder := MAPS_DIR.path_join(tag)
	var definition := load(folder.path_join(tag + ".tres")) as MapDefinition
	var before: MapTerrainData = definition.terrain if definition != null else null
	var heights: TerrainHeights = null
	if ResourceLoader.exists(folder.path_join("heights.png")):
		heights = load(folder.path_join("heights.png")) as TerrainHeights
	if before == null or heights == null or not heights.is_valid():
		print("FACES PARITY %s missing: terrain.res=%s heights.png imported=%s" % [tag, before != null, heights != null and heights.is_valid()])
		return false
	var after := TerrainFaces.build(heights)
	var old_sets := _triangles(before)
	var new_sets := _triangles(after)
	var floor_diff := _difference(old_sets[0], new_sets[0])
	var wall_diff := _difference(old_sets[1], new_sets[1])
	var walls_lost := _missing(old_sets[1], new_sets[1])
	var height_diff := _height_difference(before, after)
	print("FACES PARITY %s floor=%d walls=%d diff=%d" % [tag, _total(new_sets[0]), _total(new_sets[1]), floor_diff + wall_diff])
	if before.resource_path.begins_with("res://assets/original/"):
		if height_diff > 0:
			print("  %s: %d sampled heights differ" % [tag, height_diff])
		return floor_diff + wall_diff == 0 and height_diff == 0
	print("  %s (test map): floor diff %d (diagonal of flat cells), walls %d -> %d (rim walls accepted), lost walls %d, sampled heights differ %d" % [
			tag, floor_diff, _total(old_sets[1]), _total(new_sets[1]), walls_lost, height_diff])
	return height_diff == 0 and walls_lost == 0


## [land, walls]: each a Dictionary from a triangle's key to how many times it appears.
static func _triangles(data: MapTerrainData) -> Array[Dictionary]:
	var land := {}
	var walls := {}
	var vertices := data.vertices
	var indices := data.indices
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var bucket := walls if TerrainRules.is_wall(a, b, c) else land
		var key := _key(a, b, c)
		bucket[key] = int(bucket.get(key, 0)) + 1
	return [land, walls]


## The rounded corners in winding order, started at the smallest, so the same triangle gives the same key.
static func _key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var corners: Array[Vector3i] = [_rounded(a), _rounded(b), _rounded(c)]
	var first := 0
	for k in 3:
		if corners[k] < corners[first]:
			first = k
	var ordered: Array[Vector3i] = [corners[first], corners[(first + 1) % 3], corners[(first + 2) % 3]]
	return "%s%s%s" % ordered


## Rounded in double precision (a Vector3 product would round in single precision first).
static func _rounded(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * ROUND), roundi(p.y * ROUND), roundi(p.z * ROUND))


static func _total(counts: Dictionary) -> int:
	var sum := 0
	for key in counts:
		sum += int(counts[key])
	return sum


## How many triangles one side has that the other has not, both ways.
static func _difference(before: Dictionary, after: Dictionary) -> int:
	return _missing(before, after) + _missing(after, before)


## How many triangles of `from` are not in `into`.
static func _missing(from: Dictionary, into: Dictionary) -> int:
	var count := 0
	for key in from:
		count += maxi(0, int(from[key]) - int(into.get(key, 0)))
	return count


## Points where the land height (NAN over a void) of the two grounds differs by more than HEIGHT_TOLERANCE_M.
static func _height_difference(before: MapTerrainData, after: MapTerrainData) -> int:
	var old_index := TerrainRules.index(before)
	var new_index := TerrainRules.index(after)
	var count := 0
	for z in TerrainGrid.SIDE - 1:
		for x in TerrainGrid.SIDE - 1:
			for sample in SAMPLES:
				var px := (x + sample.x) * TerrainGrid.CELL_M
				var pz := (z + sample.y) * TerrainGrid.CELL_M
				var old_height := TerrainRules.height_in(px, pz, old_index.ground, old_index.cells)
				var new_height := TerrainRules.height_in(px, pz, new_index.ground, new_index.cells)
				if is_nan(old_height) != is_nan(new_height) or (not is_nan(old_height) and absf(old_height - new_height) > HEIGHT_TOLERANCE_M):
					count += 1
	return count
