@tool
extends RefCounted

## The edits of a map's ground that the Terrain's buttons and tools/terrain/terrain_cli share, with no editor: where a
## Terrain's pictures live, a new flat ground, and the before and after that level every GroundFootprint of a map.
## Not: undo and saving in the editor (TerrainHistory), Blender (BlenderBridge), reimporting, checking a map (MapChecks).

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")


## The folder of the heights.png the Terrain reads; without one, the folder of the scene it is saved in ("" if neither).
static func folder_of(terrain: Terrain) -> String:
	if terrain.heights != null and not terrain.heights.resource_path.is_empty():
		return terrain.heights.resource_path.get_base_dir()
	var scene := terrain.owner if terrain.owner != null else terrain
	return scene.scene_file_path.get_base_dir()


## Land at `height_m` everywhere (kept in 0 .. BrushRules.MAX_HEIGHT_M), without voids.
static func flat(height_m: float) -> TerrainHeights:
	var heights := PackedFloat32Array()
	heights.resize(TerrainGrid.COUNT)
	heights.fill(clampf(height_m, 0.0, BrushRules.MAX_HEIGHT_M))
	var mask := PackedByteArray()
	mask.resize(TerrainGrid.COUNT)
	var made := TerrainHeights.new()
	made.heights_m = heights
	made.void_mask = mask
	return made


## Writes a flat ground into `folder` (heights.png; a void.png there goes). What MapImages.write did.
static func write_flat(folder: String, height_m: float) -> MapImages.Result:
	return MapImages.write(flat(height_m), folder)


## Levels the land under every GroundFootprint inside `root` to the median height under it (FootprintRules.level_target),
## on copies of `heights` and `mask` (TerrainGrid.COUNT values, row by row; not changed). Returns `{before, after}`, two
## Array[BrushStroke.Patch]: writing `after` in order levels every base, writing `before` in order puts the ground back
## exactly (overlapping bases included). Both empty when the map has no base.
static func level_bases(root: Node, terrain: Terrain, heights: PackedFloat32Array, mask: PackedByteArray) -> Dictionary:
	var work := heights.duplicate()
	var work_mask := mask.duplicate()
	var before: Array[BrushStroke.Patch] = []
	var after: Array[BrushStroke.Patch] = []
	# The footprints' areas are in the scene's frame; the lattice is in the Terrain's (the editor shifts the map root).
	var origin := Vector2(terrain.global_position.x, terrain.global_position.z)
	for node in MapGroundChecks.nodes_in_map(root, GroundFootprint.GROUP):
		var area := (node as GroundFootprint).area()
		area.position -= origin
		var rect := FootprintRules.vertices_under(area)
		if not rect.has_area():
			continue
		var full := PackedFloat32Array()
		full.resize(rect.get_area())
		full.fill(1.0)
		before.push_front(BrushStroke.Patch.read(work, work_mask, rect))
		BrushRules.flatten(work, rect, full, FootprintRules.level_target(work, rect))
		after.append(BrushStroke.Patch.read(work, work_mask, rect))
	return {"before": before, "after": after}
