extends RefCounted

## RFC-054 054a (F380) and RFC-055 055d-d3: the density images of the maps (FloraLayer) and FloraPlacement.
## - flora_total: total() of every map = the plants its flora.res held before the PNG migration (flora_test_maps.gd
##   TOTALS; the migration compared every cell).
## - flora_seed: the same seed gives the same floats; another seed, other floats.
## - flora_half: density 0.5 keeps count x 0.5 within 1 in every cell (and density 1 keeps them all).
## - flora_prefix: in every cell with k >= 8 plants the first 8 instances cover the four quadrants, a shorter list is a
##   prefix of a longer one, and every instance is inside its cell.
## - flora_png: every layer's image is L8 and its brightest pixel is 255 (max_per_cell plants), the way the migration wrote it.

const Maps := preload("res://debug/look/flora_test_maps.gd")
const SEED := 54
const OTHER_SEED := 55
const PREFIX_MIN := 8

var _cells_of := {}


func run() -> Dictionary:
	var maps := {}
	for tag in Maps.TOTALS:
		maps[tag] = Maps.density_of(tag)
	var results := {}
	results["flora_total"] = _total(maps)
	results["flora_png"] = _png()
	results["flora_seed"] = _seed(maps)
	results["flora_half"] = _half(maps)
	results["flora_prefix"] = _prefix(maps)
	return results


func _total(maps: Dictionary) -> Dictionary:
	var wrong := {}
	var totals := {}
	for tag in maps:
		totals[tag] = (maps[tag] as FloraDensity).total()
		if totals[tag] != Maps.TOTALS[tag]:
			wrong[tag] = {"total": totals[tag], "expected": Maps.TOTALS[tag]}
	return {"ok": wrong.is_empty(), "totals": totals, "wrong": wrong}


func _png() -> Dictionary:
	var wrong := []
	var layers := 0
	for tag in Maps.TOTALS:
		var root := MapCatalog.shared().find(StringName(tag)).map_scene.instantiate()
		for layer: FloraLayer in Maps.layers_of(root):
			layers += 1
			var image := layer.density.get_image()
			image.convert(Image.FORMAT_L8)
			var brightest := 0
			for value in image.get_data():
				brightest = maxi(brightest, value)
			if brightest != 255 or layer.max_per_cell < 1 or layer.species == null:
				wrong.append({"map": tag, "layer": layer.name, "brightest": brightest})
		root.free()
	return {"ok": wrong.is_empty() and layers > 0, "layers": layers, "wrong": wrong.slice(0, 5)}


## Every (entry index, tx, tz, count) with count > 0 (once per snapshot).
func _cells(flora: FloraDensity) -> Array:
	if _cells_of.has(flora):
		return _cells_of[flora]
	var cells := []
	_cells_of[flora] = cells
	for t in flora.entries():
		for tz in 320:
			for tx in 320:
				var count := flora.count_at(t, tx, tz)
				if count > 0:
					cells.append([t, tx, tz, count])
	return cells


func _seed(maps: Dictionary) -> Dictionary:
	var flora: FloraDensity = maps["peaks"]
	var cells := _cells(flora).slice(0, 400)
	var first := _instances_bytes(flora, cells, SEED)
	var again := _instances_bytes(flora, cells, SEED)
	var other := _instances_bytes(flora, cells, OTHER_SEED)
	return {"ok": first == again and first != other, "cells": cells.size(), "bytes": first.size(),
		"same_seed": first == again, "other_seed_differs": first != other}


func _instances_bytes(flora: FloraDensity, cells: Array, seed: int) -> PackedByteArray:
	var all := PackedFloat32Array()
	for cell in cells:
		var tag := flora.tags[cell[0]]
		var n := FloraPlacement.instance_count(seed, tag, cell[1], cell[2], cell[3], 0.75)
		all.append_array(FloraPlacement.cell_instances(seed, tag, cell[1], cell[2], n, flora.cell_m(cell[0]), Vector2(0.8, 1.2)))
	return all.to_byte_array()


func _half(maps: Dictionary) -> Dictionary:
	var wrong := []
	var sums := {}
	for tag in maps:
		var flora: FloraDensity = maps[tag]
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
	var checked := 0
	var wrong := []
	for tag in maps:
		var flora: FloraDensity = maps[tag]
		for cell in _cells(flora):
			if cell[3] < PREFIX_MIN:
				continue
			checked += 1
			var problem := _prefix_problem(flora.tags[cell[0]], cell[1], cell[2], cell[3], flora.cell_m(cell[0]))
			if not problem.is_empty():
				wrong.append({"map": tag, "cell": cell, "problem": problem})
	# The image caps a cell at 255: the stratification must hold for the largest count too.
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
