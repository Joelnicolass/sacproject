extends RefCounted

## RFC-054 054a (F380): the baked FloraMaps (scenes/map/maps/<tag>/flora.res) and FloraPlacement.
## - flora_total: total() of every map = the widgets.json rows bake_map_layout would plant (on the land, outside the
##   altar's 40 m and the fount's 6 m), counted here row by row; high_noon and peasantville also against the Plant nodes
##   of their layout.tscn (the real _plan_plants output).
## - flora_size: every flora.res at most MAX_BYTES (the sizes are in the result).
## - flora_seed: the same seed gives the same bytes; another seed, other bytes; the builder gives the same counts twice.
## - flora_half: density 0.5 keeps count x 0.5 within 1 in every cell (and density 1 keeps them all).
## - flora_prefix: in every cell with k >= 8 plants the first 8 instances cover the four quadrants, a shorter list is a
##   prefix of a longer one, and every instance is inside its cell.

const MAX_BYTES := 16384
const SEED := 54
const OTHER_SEED := 55
const PREFIX_MIN := 8


func run() -> Dictionary:
	var maps := {}
	var catalog := MapCatalog.shared()
	for tag in FloraMapBuilder.ORIGINAL_MAPS:
		var map := catalog.find(StringName(tag))
		var flora := ResourceLoader.load(FloraMapBuilder.path_of(map), "", ResourceLoader.CACHE_MODE_IGNORE) as FloraMap if map else null
		maps[tag] = {"map": map, "flora": flora}
	var results := {}
	results["flora_total"] = _total(maps)
	results["flora_size"] = _size(maps)
	results["flora_seed"] = _seed(maps)
	results["flora_half"] = _half(maps)
	results["flora_prefix"] = _prefix(maps)
	return results


func _missing(maps: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	for tag in maps:
		if maps[tag]["flora"] == null:
			missing.append(tag)
	return missing


func _total(maps: Dictionary) -> Dictionary:
	var wrong := {}
	var totals := {}
	for tag in maps:
		var map: MapDefinition = maps[tag]["map"]
		var flora: FloraMap = maps[tag]["flora"]
		if flora == null:
			wrong[tag] = "no carga"
			continue
		var expected := _plantable(map)
		totals[tag] = flora.total()
		if flora.total() != expected:
			wrong[tag] = {"total": flora.total(), "expected": expected}
		var plants := _layout_plants(map)
		if plants > 0 and plants != flora.total():
			wrong["%s_layout" % tag] = {"total": flora.total(), "plant_nodes": plants}
	return {"ok": wrong.is_empty(), "totals": totals, "wrong": wrong}


## widgets.json rows that bake_map_layout would plant, whatever their model.
func _plantable(map: MapDefinition) -> int:
	var widgets := PlantClears.read_json(map.widgets_path)
	var ntts := PlantClears.read_json(map.ntts_path)
	var land := PlantClears.land_of(map)
	if land == null:
		return -1
	var clears := PlantClears.from_structures(ntts.get("structures", []))
	var count := 0
	for tag in widgets:
		for row in widgets[tag]:
			if clears.accepts(land, float(row[0]), float(row[1])):
				count += 1
	land.free()
	return count


## Plant nodes under the layout's `Plants` (read from the PackedScene's state, nothing instanced); 0 when it has none.
func _layout_plants(map: MapDefinition) -> int:
	var packed := load(map.layout_scene_path) as PackedScene if not map.layout_scene_path.is_empty() else null
	if packed == null:
		return 0
	var state := packed.get_state()
	var count := 0
	for i in state.get_node_count():
		var parent := str(state.get_node_path(i, true))
		if parent == "Plants" or parent == "./Plants":
			count += 1
	return count


func _size(maps: Dictionary) -> Dictionary:
	var sizes := {}
	var ok := true
	for tag in maps:
		var map: MapDefinition = maps[tag]["map"]
		var file := FileAccess.open(FloraMapBuilder.path_of(map), FileAccess.READ) if map else null
		var bytes := file.get_length() if file else -1
		sizes[tag] = bytes
		ok = ok and bytes > 0 and bytes <= MAX_BYTES
	return {"ok": ok, "bytes": sizes}


## Every (tag index, tx, tz, count) with count > 0.
func _cells(flora: FloraMap) -> Array:
	var cells := []
	for t in flora.tags.size():
		var grid := flora.counts[t]
		for at in grid.size():
			if grid[at] > 0:
				cells.append([t, at % flora.resolution, at / flora.resolution, grid[at]])
	return cells


func _seed(maps: Dictionary) -> Dictionary:
	var missing := _missing(maps)
	if not missing.is_empty():
		return {"ok": false, "missing": missing}
	var flora: FloraMap = maps["peaks"]["flora"]
	var cells := _cells(flora).slice(0, 400)
	var first := _instances_bytes(flora, cells, SEED)
	var again := _instances_bytes(flora, cells, SEED)
	var other := _instances_bytes(flora, cells, OTHER_SEED)
	var builder := FloraMapBuilder.new()
	var built_a := builder.build(maps["peaks"]["map"])
	var built_b := builder.build(maps["peaks"]["map"])
	var same_build := built_a != null and built_b != null and var_to_bytes(built_a.counts) == var_to_bytes(built_b.counts) \
		and var_to_bytes(built_a.counts) == var_to_bytes(flora.counts)
	return {"ok": first == again and first != other and same_build, "cells": cells.size(), "bytes": first.size(),
		"same_seed": first == again, "other_seed_differs": first != other, "same_build": same_build}


func _instances_bytes(flora: FloraMap, cells: Array, seed: int) -> PackedByteArray:
	var all := PackedFloat32Array()
	for cell in cells:
		var tag := flora.tags[cell[0]]
		var n := FloraPlacement.instance_count(seed, tag, cell[1], cell[2], cell[3], 0.75)
		all.append_array(FloraPlacement.cell_instances(seed, tag, cell[1], cell[2], n, flora.texel_m, Vector2(0.8, 1.2)))
	return all.to_byte_array()


func _half(maps: Dictionary) -> Dictionary:
	var missing := _missing(maps)
	if not missing.is_empty():
		return {"ok": false, "missing": missing}
	var wrong := []
	var sums := {}
	for tag in maps:
		var flora: FloraMap = maps[tag]["flora"]
		var half := 0
		for cell in _cells(flora):
			var species := flora.tags[cell[0]]
			var count: int = cell[3]
			var n := FloraPlacement.instance_count(SEED, species, cell[1], cell[2], count, 0.5)
			var full := FloraPlacement.instance_count(SEED, species, cell[1], cell[2], count, 1.0)
			half += n
			if absf(float(n) - float(count) * 0.5) >= 1.0 or full != count:
				wrong.append({"map": tag, "cell": cell, "half": n, "full": full})
		sums[tag] = "%d de %d (%.1f)" % [half, flora.total(), flora.total() * 0.5]
	return {"ok": wrong.is_empty(), "sums": sums, "wrong": wrong.slice(0, 5)}


func _prefix(maps: Dictionary) -> Dictionary:
	var missing := _missing(maps)
	if not missing.is_empty():
		return {"ok": false, "missing": missing}
	var checked := 0
	var wrong := []
	for tag in maps:
		var flora: FloraMap = maps[tag]["flora"]
		for cell in _cells(flora):
			if cell[3] < PREFIX_MIN:
				continue
			checked += 1
			var problem := _prefix_problem(flora.tags[cell[0]], cell[1], cell[2], cell[3], flora.texel_m)
			if not problem.is_empty():
				wrong.append({"map": tag, "cell": cell, "problem": problem})
	# The grid caps at 255: the stratification must hold for the largest count too.
	for k in [PREFIX_MIN, 64, 255]:
		var problem := _prefix_problem("TEST", 7, 9, k, 8.0)
		if not problem.is_empty():
			wrong.append({"synthetic": k, "problem": problem})
	return {"ok": wrong.is_empty() and checked > 0, "cells_k8": checked, "wrong": wrong.slice(0, 5)}


## "" when the cell's instances are an even, nested prefix inside the cell.
func _prefix_problem(tag: String, tx: int, tz: int, count: int, texel_m: float) -> String:
	var all := FloraPlacement.cell_instances(SEED, tag, tx, tz, count, texel_m)
	var short := FloraPlacement.cell_instances(SEED, tag, tx, tz, PREFIX_MIN, texel_m)
	if all.slice(0, short.size()) != short:
		return "no es prefijo"
	var low := Vector2(tx, tz) * texel_m
	var quadrants := {}
	for i in count:
		var at := Vector2(all[i * FloraPlacement.STRIDE], all[i * FloraPlacement.STRIDE + 1]) - low
		if at.x < 0.0 or at.y < 0.0 or at.x > texel_m or at.y > texel_m:  # float32 may round onto the far edge
			return "instancia %d fuera de la celda" % i
		if i < PREFIX_MIN:
			quadrants[Vector2i(int(at.x >= texel_m * 0.5), int(at.y >= texel_m * 0.5))] = true
	if quadrants.size() != 4:
		return "cuadrante vacio en los primeros %d" % PREFIX_MIN
	return ""
