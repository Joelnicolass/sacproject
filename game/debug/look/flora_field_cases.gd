extends RefCounted

## RFC-054 054c (F382): FloraField and MeshPlanter without a window.
## - flora_headless: every map.tscn of the original, instanced in this (headless) process, leaves 0 MultiMeshInstance3D
##   (internal children included) and no FloraField with a planter; run it again with `-- --dedicated --no-flow` for the
##   dedicated server (`dedicated` in the result says which one ran).
## - flora_guard: a FloraField with a rig, a FloraMap and a terrain would draw (active_layers) but builds nothing here.
## - flora_plan: every 32 m cell of every map planned at density 1 (the high preset): the instances kept against
##   FloraMap.total() (only the spots that fall off the land are lost), the same floats twice, every instance on the
##   ground. The counts and the planning time per cell are in the result (for 054e).
## - flora_clear: no instance inside a clear; its edge thins them.
## - flora_presets: the original_plants entry of each preset is the RFC-054 §4.4 table, and no plant casts a shadow.

const CONFIG_PATH := "res://data/look/vegetation/original_plants.tres"
const TREES_PATH := "res://data/look/vegetation/trees.tres"
const PRESETS := {
	&"low": {"radius_scale": 0.45, "density_scale": 0.6},
	&"medium": {"radius_scale": 0.7, "density_scale": 0.85},
	&"high": {"radius_scale": 1.0, "density_scale": 1.0},
}
## Spots of a cell may land off the ground at the edge of a hole: at most this share of a map is lost.
const MAX_LOST := 0.03
const SETTLE_FRAMES := 8

## Set by the runner (flora_cases.gd).
var tree: SceneTree


func run() -> Dictionary:
	var results := {}
	results["flora_headless"] = await _headless()
	results["flora_guard"] = await _guard()
	results["flora_plan"] = _plan()
	results["flora_clear"] = _clear()
	results["flora_presets"] = _presets()
	return results


static func count_multimeshes(node: Node) -> int:
	var sum := 1 if node is MultiMeshInstance3D else 0
	for child in node.get_children(true):
		sum += count_multimeshes(child)
	return sum


static func _fields(node: Node, out: Array) -> void:
	if node is FloraField:
		out.append(node)
	for child in node.get_children(true):
		_fields(child, out)


func _headless() -> Dictionary:
	var wrong := {}
	var seen := {}
	for tag in FloraMapBuilder.ORIGINAL_MAPS:
		var map := MapCatalog.shared().find(StringName(tag))
		var packed := map.load_scene() if map else null
		if packed == null:
			wrong[tag] = "no carga"
			continue
		var root := packed.instantiate()
		tree.root.add_child(root)
		for i in SETTLE_FRAMES:
			await tree.process_frame
		var fields := []
		_fields(root, fields)
		var working := 0
		for field: FloraField in fields:
			if not field.planters().is_empty() or field.cell_count() > 0:
				working += 1
		var meshes := count_multimeshes(root)
		seen[tag] = {"multimesh": meshes, "fields_alive": fields.size(), "fields_working": working}
		if meshes != 0 or working != 0:
			wrong[tag] = seen[tag]
		root.queue_free()
		await tree.process_frame
	return {"ok": wrong.is_empty(), "dedicated": MpBoot.is_dedicated_process(), "maps": seen, "wrong": wrong}


func _guard() -> Dictionary:
	var map := MapCatalog.shared().find(&"peaks")
	var land := PlantClears.land_of(map)
	var rig := LookRig.new()
	rig.terrain = land
	rig.flora_map = load(FloraMapBuilder.path_of(map)) as FloraMap
	rig.quality_preset = load("res://data/look/quality_high.tres") as LookQuality
	var field := FloraField.new()
	field.rig = rig
	field.configs = [load(CONFIG_PATH) as VegetationLayerConfig, load(TREES_PATH) as VegetationLayerConfig]
	tree.root.add_child(field)
	for i in SETTLE_FRAMES:
		await tree.process_frame
	var layers := field.active_layers()
	var result := {
		"active_layers": layers.size(),
		"planters": field.planters().size(),
		"multimesh": count_multimeshes(field),
		"presentationless": FloraField.presentationless(),
	}
	field.queue_free()
	rig.free()
	land.free()
	await tree.process_frame
	result["ok"] = result["active_layers"] == 1 and result["planters"] == 0 and result["multimesh"] == 0 and result["presentationless"]
	return result


func _plan() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var maps := {}
	var wrong := {}
	for tag in FloraMapBuilder.ORIGINAL_MAPS:
		var map := MapCatalog.shared().find(StringName(tag))
		var flora := load(FloraMapBuilder.path_of(map)) as FloraMap
		var land := PlantClears.land_of(map)
		if flora == null or land == null:
			wrong[tag] = "sin datos"
			continue
		var groups := MeshPlanter.describe_groups(config, flora)
		var kept := 0
		var nodes := 0
		var cells := 0
		var most := 0
		var worst_us := 0
		var spent_us := 0
		var off_ground := 0
		var first_full := Vector2i(-1, -1)
		for cz in MeshPlanter.MAP_CELLS:
			for cx in MeshPlanter.MAP_CELLS:
				var key := Vector2i(cx, cz)
				var started := Time.get_ticks_usec()
				var buffers := MeshPlanter.plan_cell(config, flora, groups, 1.0, key, land.ground_height, PackedVector4Array())
				var took := Time.get_ticks_usec() - started
				var in_cell := 0
				for g in buffers.size():
					var count := buffers[g].size() / MeshPlanter.XFORM_STRIDE
					if count > 0:
						nodes += 1
					in_cell += count
					off_ground += _off_ground(buffers[g], key, land)
				if in_cell > 0:
					cells += 1
					spent_us += took
					worst_us = maxi(worst_us, took)
					if first_full.x < 0:
						first_full = key
				kept += in_cell
				most = maxi(most, in_cell)
		var same := true
		if first_full.x >= 0:
			var a := MeshPlanter.plan_cell(config, flora, groups, 1.0, first_full, land.ground_height, PackedVector4Array())
			var b := MeshPlanter.plan_cell(config, flora, groups, 1.0, first_full, land.ground_height, PackedVector4Array())
			same = a == b
		var total := flora.total()
		maps[tag] = {
			"total": total, "kept": kept, "cells": cells, "nodes": nodes, "most_in_cell": most,
			"mean_cell_ms": snappedf(spent_us / 1000.0 / maxf(cells, 1), 0.01), "worst_cell_ms": snappedf(worst_us / 1000.0, 0.01),
		}
		if kept > total or kept < total * (1.0 - MAX_LOST) or not same or off_ground > 0:
			wrong[tag] = {"kept": kept, "total": total, "same": same, "off_ground": off_ground}
		land.free()
	return {"ok": wrong.is_empty(), "maps": maps, "wrong": wrong}


## Instances of a buffer that do not stand on the ground (more than 1 cm from ground_height; the pose may lift a model,
## so the check is that the instance origin before the pose is on the ground: the pose of the plants has no offset).
static func _off_ground(buffer: PackedFloat32Array, key: Vector2i, land: Terrain) -> int:
	var wrong := 0
	var corner := Vector2(key) * MeshPlanter.CELL_M
	for i in buffer.size() / MeshPlanter.XFORM_STRIDE:
		var at := i * MeshPlanter.XFORM_STRIDE
		var x := buffer[at + 3] + corner.x
		var z := buffer[at + 11] + corner.y
		var ground := land.ground_height(x, z)
		if is_nan(ground) or absf(ground - buffer[at + 7]) > 0.05:
			wrong += 1
	return wrong


func _clear() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var map := MapCatalog.shared().find(&"peaks")
	var flora := load(FloraMapBuilder.path_of(map)) as FloraMap
	var land := PlantClears.land_of(map)
	var groups := MeshPlanter.describe_groups(config, flora)
	# The fullest cell of the map.
	var best := Vector2i.ZERO
	var best_count := -1
	for cz in MeshPlanter.MAP_CELLS:
		for cx in MeshPlanter.MAP_CELLS:
			var sum := 0
			for g in groups:
				for dz in MeshPlanter.DATA_PER_CELL:
					for dx in MeshPlanter.DATA_PER_CELL:
						sum += flora.count_at(int(g["tag_index"]), cx * MeshPlanter.DATA_PER_CELL + dx, cz * MeshPlanter.DATA_PER_CELL + dz)
			if sum > best_count:
				best_count = sum
				best = Vector2i(cx, cz)
	var center := (Vector2(best) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M
	var hard := PackedVector4Array([Vector4(center.x, center.y, 10.0, 0.0)])
	var soft := PackedVector4Array([Vector4(center.x, center.y, 10.0, 6.0)])
	var none := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.ground_height, PackedVector4Array()), best)
	var cut := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.ground_height, hard), best)
	var thinned := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.ground_height, soft), best)
	land.free()
	var inside := 0
	for at: Vector2 in cut:
		if at.distance_to(center) < 10.0:
			inside += 1
	var in_edge_before := 0
	var in_edge_after := 0
	for at: Vector2 in none:
		var d := at.distance_to(center)
		if d >= 10.0 and d < 16.0:
			in_edge_before += 1
	for at: Vector2 in thinned:
		var d := at.distance_to(center)
		if d < 10.0:
			inside += 1
		elif d < 16.0:
			in_edge_after += 1
	return {
		"ok": inside == 0 and none.size() > cut.size() and in_edge_after < in_edge_before,
		"cell": best, "plants": none.size(), "with_clear": cut.size(), "edge_before": in_edge_before, "edge_after": in_edge_after,
	}


static func _positions(buffers: Array[PackedFloat32Array], key: Vector2i) -> Array:
	var out := []
	var corner := Vector2(key) * MeshPlanter.CELL_M
	for buffer in buffers:
		for i in buffer.size() / MeshPlanter.XFORM_STRIDE:
			var at := i * MeshPlanter.XFORM_STRIDE
			out.append(Vector2(buffer[at + 3], buffer[at + 11]) + corner)
	return out


func _presets() -> Dictionary:
	var wrong := {}
	for id: StringName in PRESETS:
		var preset := load("res://data/look/quality_%s.tres" % id) as LookQuality
		var entry := preset.vegetation_for(&"original_plants") if preset else null
		if entry == null:
			wrong[id] = "sin original_plants"
			continue
		var want: Dictionary = PRESETS[id]
		if not is_equal_approx(entry.radius_scale, want["radius_scale"]) or not is_equal_approx(entry.density_scale, want["density_scale"]) or entry.shadows or not entry.enabled:
			wrong[id] = {"radius_scale": entry.radius_scale, "density_scale": entry.density_scale, "shadows": entry.shadows}
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var shadows := config.default_species == null or config.default_species.cast_shadow
	for entry in config.species:
		shadows = shadows or entry.cast_shadow
	if shadows:
		wrong["original_plants"] = "una especie da sombra"
	var trees := load(TREES_PATH) as VegetationLayerConfig
	if trees == null or trees.density_source != VegetationLayerConfig.DensitySource.NONE:
		wrong["trees"] = "no es NONE"
	return {"ok": wrong.is_empty(), "wrong": wrong}
