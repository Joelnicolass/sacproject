extends RefCounted

## RFC-054 054c (F382): FloraField and MeshPlanter without a window.
## - flora_headless: every map.tscn of the original, instanced in this (headless) process, leaves 0 MultiMeshInstance3D
##   (internal children included) and no FloraField with a planter; run it again with `-- --dedicated --no-flow` for the
##   dedicated server (`dedicated` in the result says which one ran).
## - flora_guard: a FloraField with a rig, FloraLayer nodes and a terrain would draw (active_layers) but builds nothing here.
## - flora_plan: every 32 m cell of every map planned at density 1 (the high preset): the instances kept against
##   FloraDensity.total() (only the spots that fall off the land are lost), the same floats twice, every instance on the
##   ground. The counts and the planning time per cell are in the result (for 054e).
## - flora_clear: no instance inside a clear; its edge thins them.
## - flora_switch (054f): with the rig's «Vegetación» switch off (GraphicsPrefs.vegetation_enabled through
##   GraphicsApplier) the field has no layer and no cell; on, the layer comes back. The shared prefs start on.
## - flora_worker (054e): the densest peaks cells planned on WorkerThreadPool tasks (MeshPlanter.PlanJob with a
##   GroundSurface.sampler snapshot, several at once) give the same buffers as plan_cell on this thread with
##   GroundSurface.height_at; and a threaded MeshPlanter (no FloraField: it would not build here) driven over the densest
##   spot fills each MultiMesh with exactly those bytes, drops the plans of cells that left the ring and leaves no task.
## - flora_maps: every map of the catalog with a map scene (playable or not, tutorial_valley and alpine_meadow included):
##   its `Vegetation` node holds FloraLayers, their images hold the plants of the old flora.res (flora_test_maps.gd TOTALS),
##   every species it draws has its prop (the mesh would load in a window: headless never loads meshes, so MeshPlanter keeps
##   no group here), and planning the fullest cell on the map's own ground keeps plants. A playable map without FloraLayers
##   fails. Also: the debug scene that instances a map without a GraphicsApplier (persephone_compare) hands the rig a preset,
##   or FloraField draws nothing there.
## - flora_patch (055d-d3): a VegetationPatch's plan on the flat test map is the same twice, keeps every spot on the ground,
##   leaves a house's clear bare, and a lower density keeps a prefix of the same plants.
## - flora_presets: the original_plants entry of each preset is the RFC-054 §4.4 table, and no species casts a shadow.

const Maps := preload("res://debug/look/flora_test_maps.gd")
const CONFIG_PATH := "res://data/look/vegetation/original_plants.tres"
const SPECIES_DIR := "res://data/vegetation/species/"
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
	results["flora_maps"] = _maps()
	results["flora_clear"] = _clear()
	results["flora_worker"] = await _worker()
	results["flora_patch"] = _patch()
	results["flora_presets"] = _presets()
	results["flora_switch"] = await _switch()
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
	for tag in Maps.ORIGINAL_MAPS:
		var map := MapCatalog.shared().find(StringName(tag))
		var packed := map.map_scene if map else null
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


## The value the scene's node `node_name` saves for `property`, or null.
static func _saved(packed: PackedScene, node_name: String, property: String) -> Variant:
	var state := packed.get_state()
	for n in state.get_node_count():
		if state.get_node_name(n) != node_name:
			continue
		for p in state.get_node_property_count(n):
			if state.get_node_property_name(n, p) == property:
				return state.get_node_property_value(n, p)
	return null


func _maps() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var catalog := MapCatalog.shared()
	var playable := catalog.playable_tags()
	var seen := {}
	var wrong := {}
	for tag in catalog.all_tags():
		var map := catalog.find(StringName(tag))
		if map == null or map.map_scene == null:
			continue
		var root := map.map_scene.instantiate()
		var layers := Maps.layers_of(root)
		root.free()
		if layers.is_empty():
			# test_* maps are flat fixtures of the rules suite: no plants by design.
			if tag in playable and not tag.begins_with("test"):
				wrong[tag] = "sin FloraLayer"
			continue
		var flora := Maps.density_of(tag)
		var land := Maps.land_of(map)
		if land == null:
			wrong[tag] = "sin datos"
			continue
		var groups := MeshPlanter.describe_groups(config, flora)
		var no_prop := []
		for group in groups:
			if group["mesh"] == null:
				no_prop.append(group["tag"])
		var kept := 0
		var best := _fullest(flora, groups, 1)
		if not best.is_empty():
			for buffer in MeshPlanter.plan_cell(config, flora, groups, 1.0, best[0], land.shape.height_at, PackedVector4Array()):
				kept += buffer.size() / MeshPlanter.XFORM_STRIDE
		land.free()
		seen[tag] = {"total": flora.total(), "layers": layers.size(), "species": groups.size(), "fullest_cell_kept": kept}
		if flora.total() <= 0 or groups.is_empty() or not no_prop.is_empty() or kept <= 0 or (Maps.TOTALS.has(tag) and flora.total() != Maps.TOTALS[tag]):
			wrong[tag] = {"seen": seen[tag], "no_prop": no_prop}
	var compare := load("res://debug/look/persephone_compare.tscn") as PackedScene
	var preset: Variant = _saved(compare, "PersephoneCompare", "quality") if compare else null
	if preset == null:
		wrong["persephone_compare"] = "sin preset: FloraField no dibuja"
	return {"ok": wrong.is_empty() and not seen.is_empty(), "maps": seen, "wrong": wrong}


func _guard() -> Dictionary:
	var map := MapCatalog.shared().find(&"peaks")
	var land := Maps.land_of(map)
	var rig := LookRig.new()
	rig.ground = land.shape
	rig.quality_preset = load("res://data/look/quality_high.tres") as LookQuality
	var host := _host_with_layers("peaks")
	var field := FloraField.new()
	field.rig = rig
	field.configs = [load(CONFIG_PATH) as VegetationLayerConfig]
	host.add_child(field)
	for i in SETTLE_FRAMES:
		await tree.process_frame
	var layers := field.active_layers()
	var result := {
		"active_layers": layers.size(),
		"planters": field.planters().size(),
		"multimesh": count_multimeshes(field),
		"presentationless": FloraField.presentationless(),
	}
	host.queue_free()
	rig.free()
	land.free()
	await tree.process_frame
	result["ok"] = result["active_layers"] == 1 and result["planters"] == 0 and result["multimesh"] == 0 and result["presentationless"]
	return result


## A node in the tree holding copies of the FloraLayers of map `tag` (a bare FloraField goes beside them).
func _host_with_layers(tag: String) -> Node3D:
	var host := Node3D.new()
	for layer in Maps.layer_copies(tag):
		host.add_child(layer)
	tree.root.add_child(host)
	return host


func _plan() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var maps := {}
	var wrong := {}
	for tag in Maps.ORIGINAL_MAPS:
		var map := MapCatalog.shared().find(StringName(tag))
		var flora := Maps.density_of(tag)
		var land := Maps.land_of(map)
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
				var buffers := MeshPlanter.plan_cell(config, flora, groups, 1.0, key, land.shape.height_at, PackedVector4Array())
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
			var a := MeshPlanter.plan_cell(config, flora, groups, 1.0, first_full, land.shape.height_at, PackedVector4Array())
			var b := MeshPlanter.plan_cell(config, flora, groups, 1.0, first_full, land.shape.height_at, PackedVector4Array())
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


## Instances of a buffer that do not stand on the ground (more than 1 cm from height_at; the pose may lift a model,
## so the check is that the instance origin before the pose is on the ground: the pose of the plants has no offset).
static func _off_ground(buffer: PackedFloat32Array, key: Vector2i, land: TerrainMesh) -> int:
	var wrong := 0
	var corner := Vector2(key) * MeshPlanter.CELL_M
	for i in buffer.size() / MeshPlanter.XFORM_STRIDE:
		var at := i * MeshPlanter.XFORM_STRIDE
		var x := buffer[at + 3] + corner.x
		var z := buffer[at + 11] + corner.y
		var ground := land.shape.height_at(x, z)
		if is_nan(ground) or absf(ground - buffer[at + 7]) > 0.05:
			wrong += 1
	return wrong


func _clear() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var map := MapCatalog.shared().find(&"peaks")
	var flora := Maps.density_of("peaks")
	var land := Maps.land_of(map)
	var groups := MeshPlanter.describe_groups(config, flora)
	var best: Vector2i = _fullest(flora, groups, 1)[0]
	var center := (Vector2(best) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M
	var hard := PackedVector4Array([Vector4(center.x, center.y, 10.0, 0.0)])
	var soft := PackedVector4Array([Vector4(center.x, center.y, 10.0, 6.0)])
	var none := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.shape.height_at, PackedVector4Array()), best)
	var cut := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.shape.height_at, hard), best)
	var thinned := _positions(MeshPlanter.plan_cell(config, flora, groups, 1.0, best, land.shape.height_at, soft), best)
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


## The `n` 32 m cells with the most plants, fullest first.
static func _fullest(flora: FloraDensity, groups: Array[Dictionary], n: int) -> Array[Vector2i]:
	var scored := []
	for cz in MeshPlanter.MAP_CELLS:
		for cx in MeshPlanter.MAP_CELLS:
			var sum := 0
			for g in groups:
				for dz in MeshPlanter.DATA_PER_CELL:
					for dx in MeshPlanter.DATA_PER_CELL:
						sum += flora.count_at(int(g["tag_index"]), cx * MeshPlanter.DATA_PER_CELL + dx, cz * MeshPlanter.DATA_PER_CELL + dz)
			if sum > 0:
				scored.append([sum, Vector2i(cx, cz)])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and (a[1] as Vector2i) < (b[1] as Vector2i)))
	var out: Array[Vector2i] = []
	for item in scored.slice(0, n):
		out.append(item[1])
	return out


func _worker() -> Dictionary:
	var config := load(CONFIG_PATH) as VegetationLayerConfig
	var map := MapCatalog.shared().find(&"peaks")
	var flora := Maps.density_of("peaks")
	var land := Maps.land_of(map)
	var groups := MeshPlanter.describe_groups(config, flora)
	var keys := _fullest(flora, groups, 8)
	var center := (Vector2(keys[0]) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M
	var clears := PackedVector4Array([Vector4(center.x, center.y, 7.0, 5.0)])
	# Every cell twice at once (with a clear on the fullest), so tasks of the same cell race each other.
	var jobs := []
	for round in 2:
		for key in keys:
			var job := MeshPlanter.PlanJob.new()
			job.key = key
			job.config = config
			job.flora = flora
			job.groups = MeshPlanter.plan_groups(groups)
			job.density = 1.0
			job.height = land.shape.sampler()
			job.clears = clears
			job.task_id = WorkerThreadPool.add_task(job.run, false, "flora case")
			jobs.append(job)
	var differ := []
	var plants := 0
	for job: MeshPlanter.PlanJob in jobs:
		job.finish()
		var sync := MeshPlanter.plan_cell(config, flora, groups, 1.0, job.key, land.shape.height_at, clears)
		if job.buffers != sync:
			differ.append(job.key)
		for buffer in sync:
			plants += buffer.size() / MeshPlanter.XFORM_STRIDE
	var planted := await _planter_run(config, flora, land, keys[0])
	land.free()
	return {
		"ok": differ.is_empty() and plants > 0 and planted["ok"], "cells": keys.size(), "plants_x2": plants,
		"differ": differ, "planter": planted,
	}


## A threaded MeshPlanter over cell `key` until nothing is pending; then far away and back mid-plan.
func _planter_run(config: VegetationLayerConfig, flora: FloraDensity, land: TerrainMesh, key: Vector2i) -> Dictionary:
	var quality := (load("res://data/look/quality_high.tres") as LookQuality).vegetation_for(config.id)
	var host := Node3D.new()
	tree.root.add_child(host)
	var planter := MeshPlanter.new(config, quality, flora, land.shape, host)
	planter.threaded = true
	var spot := (Vector2(key) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M
	var ground := land.shape.height_at(spot.x, spot.y)
	var eye := planter.map_xform * Vector3(spot.x, (0.0 if is_nan(ground) else ground) + 6.0, spot.y)
	var frames := 0
	var worst_us := 0
	while frames < 600:
		var started := Time.get_ticks_usec()
		planter.update(eye, started + 1000)
		worst_us = maxi(worst_us, Time.get_ticks_usec() - started)
		frames += 1
		await tree.process_frame
		if planter.pending_count() == 0 and planter.cell_count() > 0:
			break
	var settled := planter.pending_count() == 0
	var cells := planter.cell_count()
	# Every shown cell holds exactly the bytes of plan_cell (species with no instance have no node).
	var wrong := []
	for cell: Vector2i in planter._cells:
		var sync := MeshPlanter.plan_cell(config, flora, planter.groups, quality.density_scale, cell, land.shape.height_at, PackedVector4Array())
		var full: Array[PackedFloat32Array] = []
		for buffer in sync:
			if not buffer.is_empty():
				full.append(buffer)
		var nodes: Array = planter._cells[cell]
		if nodes.size() != full.size():
			wrong.append(cell)
			continue
		for i in nodes.size():
			if (nodes[i] as MultiMeshInstance3D).multimesh.buffer != full[i]:
				wrong.append(cell)
				break
	# Far away for one frame (the ring empties while plans are in flight), then back.
	var far := planter.map_xform * Vector3(spot.x + 1200.0, 0.0, spot.y + 1200.0)
	planter.clear()
	planter.update(eye, Time.get_ticks_usec() + 1000)
	var in_flight := planter._jobs.size()
	planter.update(far, Time.get_ticks_usec() + 1000)
	for i in 30:
		await tree.process_frame
		planter.update(far, Time.get_ticks_usec() + 1000)
	var dropped := planter.dropped_plans
	planter.clear()
	var left := planter.pending_count()
	host.free()
	return {
		"ok": settled and cells > 0 and wrong.is_empty() and in_flight > 0 and dropped > 0 and left == 0,
		"frames": frames, "cells": cells, "wrong": wrong, "worst_update_ms": snappedf(worst_us / 1000.0, 0.01),
		"in_flight": in_flight, "dropped": dropped, "left": left,
	}


static func _positions(buffers: Array[PackedFloat32Array], key: Vector2i) -> Array:
	var out := []
	var corner := Vector2(key) * MeshPlanter.CELL_M
	for buffer in buffers:
		for i in buffer.size() / MeshPlanter.XFORM_STRIDE:
			var at := i * MeshPlanter.XFORM_STRIDE
			out.append(Vector2(buffer[at + 3], buffer[at + 11]) + corner)
	return out


func _patch() -> Dictionary:
	var land := Maps.land_of(MapCatalog.shared().find(&"test_flat"))
	var species := load(SPECIES_DIR + "persephone_fern_1.tres") as VegetationSpecies
	var at := Transform3D(Basis.IDENTITY, Vector3(1325.0, 10.0, 1300.0))
	var house := Vector4(1335.0, 1300.0, 14.65, 0.0)
	var free := PatchPlanner.plan(species, 1, 600, 30.0, at, land.shape, Transform3D.IDENTITY, 1.0, PackedVector4Array())
	var again := PatchPlanner.plan(species, 1, 600, 30.0, at, land.shape, Transform3D.IDENTITY, 1.0, PackedVector4Array())
	var cleared := PatchPlanner.plan(species, 1, 600, 30.0, at, land.shape, Transform3D.IDENTITY, 1.0, PackedVector4Array([house]))
	var half := PatchPlanner.plan(species, 1, 600, 30.0, at, land.shape, Transform3D.IDENTITY, 0.5, PackedVector4Array())
	var other := PatchPlanner.plan(species, 2, 600, 30.0, at, land.shape, Transform3D.IDENTITY, 1.0, PackedVector4Array())
	var inside := 0
	var outside_disc := 0
	var stride := MeshPlanter.XFORM_STRIDE
	for i in cleared.size() / stride:
		if Vector2(cleared[i * stride + 3] - house.x, cleared[i * stride + 11] - house.y).length() < house.z:
			inside += 1
	for i in free.size() / stride:
		if Vector2(free[i * stride + 3] - at.origin.x, free[i * stride + 11] - at.origin.z).length() > 30.01:
			outside_disc += 1
	land.free()
	var result := {
		"planted": free.size() / stride, "with_clear": cleared.size() / stride, "inside_clear": inside, "half": half.size() / stride,
		"outside_disc": outside_disc,
	}
	result["ok"] = free.size() / stride == 600 and free == again and inside == 0 and cleared.size() < free.size() \
		and half.size() / stride == 300 and half == free.slice(0, half.size()) and free != other and outside_disc == 0
	return result


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
	for file in DirAccess.get_files_at(SPECIES_DIR):
		if not file.ends_with(".tres"):
			continue
		var species := load(SPECIES_DIR + file) as VegetationSpecies
		if species == null or species.density_tag().is_empty():
			wrong[file] = "no es una especie con tag"
		elif species.cast_shadow:
			wrong[file] = "da sombra"
	return {"ok": wrong.is_empty(), "wrong": wrong}


func _switch() -> Dictionary:
	var map := MapCatalog.shared().find(&"roads")
	var land := Maps.land_of(map)
	var rig := LookRig.new()
	rig.ground = land.shape
	rig.quality_preset = load("res://data/look/quality_high.tres") as LookQuality
	var host := _host_with_layers("roads")
	var field := FloraField.new()
	field.rig = rig
	field.configs = [load(CONFIG_PATH) as VegetationLayerConfig]
	host.add_child(field)
	await tree.process_frame
	var on_before := field.active_layers().size()
	rig.set_vegetation_enabled(false)
	for i in SETTLE_FRAMES:
		await tree.process_frame
	var off_layers := field.active_layers().size()
	var off_cells := field.cell_count()
	var off_meshes := count_multimeshes(field)
	rig.set_vegetation_enabled(true)
	await tree.process_frame
	var on_after := field.active_layers().size()
	host.queue_free()
	rig.free()
	land.free()
	await tree.process_frame
	var prefs := load(GraphicsPrefs.SHARED_PATH) as GraphicsPrefs
	var result := {
		"on_before": on_before, "off_layers": off_layers, "off_cells": off_cells, "off_multimesh": off_meshes,
		"on_after": on_after, "prefs_default_on": prefs != null and prefs.default_vegetation,
	}
	result["ok"] = on_before == 1 and off_layers == 0 and off_cells == 0 and off_meshes == 0 and on_after == 1 and result["prefs_default_on"]
	return result
