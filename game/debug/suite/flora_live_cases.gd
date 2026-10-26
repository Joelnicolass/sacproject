extends RefCounted

## RFC-057 057e (criterion 11) case of terrain_cases: the plants follow a stamp that plays for long (the Volcano mound, 64 s).
## Volcano at the suite's center; once the mound comes down, a MeshPlanter (every High Noon layer painted white, so every cell
## has plants) and a FloraGroundWatch with `live_every_s` = 1 follow the ground. Each round jumps the mound 10 s ahead, stops it
## (the ground holds still) and runs the watch's 1 s flush: the playing ticks left one joined area, only the cells it touches
## plan again (0 outside the mound's rect), they are built, and their plants stand within 0.5 m of height_at while a plan from
## before the jump is off by more. A watch with 0 keeps nothing. (Headless draws no mesh, so the plants come from plan_cell.)
## It borrows the world of TerrainCases (`cases`): its bed, its Volcano, its planter helpers and its checks.

const Maps := preload("res://debug/look/flora_test_maps.gd")
const ROUNDS := 4
## Mound ticks each round jumps (10 s: about 6 m down at the center).
const JUMP_TICKS := 600
const TOLERANCE_M := 0.5

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"flora_live": _live}


func _live() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var wizard: Node3D = _c._wizard(1, _c._far_wizard_spot(), "pyro", 8)
	var before := shape.field().permanent.duplicate()
	var zone: GroundZone = _c._volcano(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	while mound.ticks < _c.ERUPT_TICKS + 30:
		await _c._frames(1)
	var reach_m := (mound.reach.shape as CylinderShape3D).radius
	var rect := TerrainGrid.vertex_rect(mound.center(), reach_m)
	var area := TerrainGrid.area_of(rect)
	var config := load("res://data/look/vegetation/original_plants.tres") as VegetationLayerConfig
	var quality := (load("res://data/look/quality_high.tres") as LookQuality).vegetation_for(config.id)
	var layers := Maps.layer_copies("high_noon")
	for layer in layers:
		var white := layer.density_image()
		white.fill(Color.WHITE)
		layer.show_painting(white, Rect2())
	var flora := FloraDensity.from_layers(layers)
	var plain := MeshPlanter.plan_groups(MeshPlanter.describe_groups(config, flora))
	var holder := Node3D.new()
	_c._root.add_child(holder)
	var planter := MeshPlanter.new(config, quality, flora, shape, holder)
	planter.threaded = false
	var eye := Vector3(mound.center().x, shape.height_at(mound.center().x, mound.center().y) + 30.0, mound.center().y)
	await _c._settle(planter, eye)
	var watch := FloraGroundWatch.new()
	watch.live_every_s = 1.0
	watch.follow(shape)
	var off := FloraGroundWatch.new()
	off.follow(shape)
	var tree: SceneTree = _c._host.get_tree()
	var joined := true
	var outside := 0
	var all_queued := true
	var all_built := true
	var worst := 0.0
	var stale_worst := 0.0
	var touched_total := 0
	for _step in ROUNDS:
		var old_ground := shape.sampler()
		mound.ticks += JUMP_TICKS
		mound.synced_ticks = mound.ticks
		await _c._frames(3)
		mound.set_physics_process(false)
		await _c._frames(2)
		joined = joined and watch.live_waiting() == 1
		var touched: Array[Vector2i] = []
		for key: Vector2i in planter._cells:
			if planter._hits(key, area):
				touched.append(key)
		touched_total += touched.size()
		var built_before := planter.built_cells
		watch.update(1.0, 0.25, [planter], tree)
		off.update(1.0, 0.25, [planter], tree)
		var queued: Array = planter._jobs.keys()
		queued.append_array(planter._pending)
		for key: Vector2i in queued:
			if not planter._hits(key, area):
				outside += 1
		for key in touched:
			all_queued = all_queued and queued.has(key)
		# The eye stays 30 m above the sinking mound: the planter's ring keeps its size (a fixed eye would see it shrink).
		eye.y = shape.height_at(eye.x, eye.z) + 30.0
		await _c._settle(planter, eye)
		all_built = all_built and planter.built_cells - built_before >= touched.size() and planter.pending_count() == 0
		var now := shape.sampler()
		for key in touched:
			worst = maxf(worst, _off_ground(shape, key, MeshPlanter.plan_cell(config, flora, plain, quality.density_scale, key, now, PackedVector4Array())))
			stale_worst = maxf(stale_worst, _off_ground(shape, key, MeshPlanter.plan_cell(config, flora, plain, quality.density_scale, key, old_ground, PackedVector4Array())))
		mound.set_physics_process(true)
	_c._note("flora live: touched cells / outside / worst m / stale worst m", [touched_total, outside, worst, stale_worst])
	checks["mound_coming_down"] = shape.field().live_count() == 1
	checks["live_ticks_joined_in_one_area"] = joined
	checks["touched_cells_have_plants"] = touched_total > 0
	checks["touched_cells_replanned"] = all_queued and all_built
	checks["no_replan_outside_the_rect"] = outside == 0
	checks["plants_on_the_ground"] = worst <= TOLERANCE_M
	checks["old_plan_would_float"] = stale_worst > TOLERANCE_M
	checks["zero_keeps_nothing"] = off.live_waiting() == 0
	planter.clear()
	watch.follow(null)
	off.follow(null)
	holder.free()
	for layer in layers:
		layer.free()
	var center := mound.center()
	zone.queue_free()
	wizard.queue_free()
	await _c._frames(2)
	await _put_back(shape, before, center, reach_m)
	return _c._verdict("terrain_flora_live", checks)


## Worst |y - height_at| of the plants in the buffers of cell `key` (cell-local x, z; plants over a hole are skipped).
static func _off_ground(shape: Terrain, key: Vector2i, buffers: Array[PackedFloat32Array]) -> float:
	var corner := Vector2(key) * MeshPlanter.CELL_M
	var worst := 0.0
	for buffer in buffers:
		for i in buffer.size() / MeshPlanter.XFORM_STRIDE:
			var at := i * MeshPlanter.XFORM_STRIDE
			var ground := shape.height_at(corner.x + buffer[at + 3], corner.y + buffer[at + 11])
			if not is_nan(ground):
				worst = maxf(worst, absf(buffer[at + 7] - ground))
	return worst


## What the Volcano kept (the crater, a quarter of the mound if it ended) goes away over its rect.
func _put_back(shape: Terrain, before: PackedFloat32Array, center: Vector2, reach_m: float) -> void:
	var rect := TerrainGrid.vertex_rect(center, reach_m)
	var restore := PackedFloat32Array()
	restore.resize(rect.get_area())
	for row in rect.size.y:
		for column in rect.size.x:
			var id := TerrainGrid.id_of(rect.position + Vector2i(column, row))
			restore[row * rect.size.x + column] = before[id] - shape.field().permanent[id]
	_c._keep(shape, center, reach_m, restore)
	await _c._frames(2)
