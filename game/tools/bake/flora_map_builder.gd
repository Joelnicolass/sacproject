class_name FloraMapBuilder
extends RefCounted

## RFC-054 054a (F380): a map's FloraMap from its widgets.json, its ntts.json (the clearings) and its terrain. Every row
## that bake_map_layout used to plant as nodes until RFC-054 054d (PlantClears.accepts: on the land, outside the altar's 40 m and the fount's 6 m)
## adds one to its 8 m cell; the rest is left out. Used by tools/bake/bake_flora_map.gd (write and --check) and by
## debug/look/flora_cases.gd.

const TEXEL_M := 8.0
const RESOLUTION := 320

## The maps with original plants (widgets.json); the test maps have none.
const ORIGINAL_MAPS: PackedStringArray = ["peaks", "roads", "winter_wonder", "high_noon", "peasantville"]

## What the last `build` saw: {rows, kept, capped, per_tag: {tag: kept}}.
var report := {}


## scenes/map/maps/<tag>/flora.res: next to the map's scene.
static func path_of(map: MapDefinition) -> String:
	return map.map_scene_path.get_base_dir().path_join("flora.res")


## Null (and a pushed error) when the inputs are missing.
func build(map: MapDefinition) -> FloraMap:
	report = {"rows": 0, "kept": 0, "capped": 0, "per_tag": {}}
	var widgets := PlantClears.read_json(map.widgets_path)
	var ntts := PlantClears.read_json(map.ntts_path)
	if widgets.is_empty() or ntts.is_empty():
		push_error("FloraMapBuilder: missing or empty %s or %s." % [map.widgets_path, map.ntts_path])
		return null
	var land := PlantClears.land_of(map)
	if land == null:
		push_error("FloraMapBuilder: %s is missing or invalid." % map.terrain_path)
		return null
	var clears := PlantClears.from_structures(ntts.get("structures", []))
	var tags := PackedStringArray()
	for tag in widgets.keys():
		tags.append(str(tag))
	tags.sort()
	var flora := FloraMap.new()
	flora.texel_m = TEXEL_M
	flora.resolution = RESOLUTION
	flora.tags = tags
	var grids: Array[PackedByteArray] = []
	for tag in tags:
		var grid := PackedByteArray()
		grid.resize(RESOLUTION * RESOLUTION)
		var kept := 0
		for row in widgets[tag]:
			report["rows"] += 1
			var x := float(row[0])
			var z := float(row[1])
			if not clears.accepts(land, x, z):
				continue
			var cell := Vector2i(floori(x / TEXEL_M), floori(z / TEXEL_M)).clampi(0, RESOLUTION - 1)
			var at := cell.y * RESOLUTION + cell.x
			if grid[at] >= FloraMap.MAX_COUNT:
				report["capped"] += 1
				continue
			grid[at] += 1
			kept += 1
		report["per_tag"][tag] = kept
		report["kept"] += kept
		grids.append(grid)
	flora.counts = grids
	land.free()
	return flora
