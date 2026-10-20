class_name MeshPlanter
extends RefCounted

## RFC-054 054c (F382): draws one VegetationLayerConfig of FloraField as meshes. A CellRing of 32 m cells (4 x 4 cells of
## the FloraMap) follows the camera; each cell is built once on the CPU and holds one MultiMeshInstance3D per species
## (an internal child of the host, never saved).
## - Build (`plan_cell`, a pure function): per 8 m data cell and species, FloraPlacement gives the instances; they are
##   ordered by rank (i + 0.5) / n so any prefix of a 32 m cell is an even sample of its 16 data cells; the height is
##   Terrain.ground_height, and an instance off the ground or inside a VegetationClear is dropped (the clear's edge thins
##   them by a hash). Final transform: T·R·S·BodyCatalog.pose(model, false). Meshes and materials are BodyCatalog's,
##   shared by every cell.
## - At most `max_builds_per_frame` cells per frame, the nearest first. A cell that leaves the ring is hidden and kept in
##   an LRU cache of CACHE_SIZE cells; coming back shows it again without a rebuild.
## - LOD: the tier of a cell (CellRing, by ground distance to the camera) sets `visible_instance_count` to the first
##   `tier_fractions[tier]` of its instances. Each species ends at a camera distance (the radius or its visibility_end_m):
##   a dithered distance fade on a copy of its material (one per species, shared by its cells; the mesh's own material is
##   never touched) and `visibility_range_end` on the node, past which the whole cell is culled.
## - The ring radius is a camera distance: on the ground it is sqrt(radius² - height²), so a high camera keeps fewer cells.
## Presentation only: FloraField never makes one in a headless or dedicated process.

const CELL_M := 32.0
const MAP_CELLS := 80
## FloraMap cells per side of a planter cell (32 m / 8 m).
const DATA_PER_CELL := 4
const CACHE_SIZE := 64
## Half the diagonal of a cell plus some height: the node's visibility range is measured to its AABB center.
const CELL_REACH_M := CELL_M * 0.7072 + 4.0
## Floats per instance in a MultiMesh TRANSFORM_3D buffer.
const XFORM_STRIDE := 12
const SALT_SPECIES := 0x3C6EF372
const SALT_CLEAR := 0x7F4A7C15

var config: VegetationLayerConfig
var quality: VegetationQuality
var flora: FloraMap
var terrain: Terrain
var host: Node3D

## Per species drawn: {tag, tag_index, model, pose, scale_range, weight, cast_shadow, end_m, mesh, material}.
var groups: Array[Dictionary] = []
## The map's transform (the terrain's global transform) and its inverse.
var map_xform := Transform3D.IDENTITY
var _map_inverse := Transform3D.IDENTITY
var _ring := CellRing.new(CELL_M, MAP_CELLS)
## Built cells inside the ring: Vector2i -> Array of MultiMeshInstance3D.
var _cells := {}
## Cells inside the ring still to build.
var _pending: Array[Vector2i] = []
var _pending_sorted := true
## Cells out of the ring, hidden: Vector2i -> nodes; `_cache_order` oldest first.
var _cache := {}
var _cache_order: Array[Vector2i] = []
## Rows: x, z (map), radius, edge.
var _clears := PackedVector4Array()
var _eye := Vector2.ZERO
var _radius := 0.0
## Microseconds spent building in the last frame, and the worst frame so far.
var last_frame_build_us := 0
var worst_frame_build_us := 0
var built_cells := 0


func _init(layer: VegetationLayerConfig, preset: VegetationQuality, map: FloraMap, land: Terrain, owner_node: Node3D) -> void:
	config = layer
	quality = preset
	flora = map
	terrain = land
	host = owner_node
	map_xform = land.global_transform if land.is_inside_tree() else land.transform
	_map_inverse = map_xform.affine_inverse()
	var scale := quality.radius_scale
	var starts := PackedFloat32Array()
	for start in config.tier_starts_m:
		starts.append(start * scale)
	if starts.is_empty():
		starts.append(0.0)
	_ring.tier_starts = starts
	groups = describe_groups(config, flora)
	for group in groups:
		group["end_m"] = species_end(group, config, quality)
		group["mesh"] = BodyCatalog.mesh(str(group["model"]))
		group["material"] = _fade_material(group["mesh"], float(group["end_m"]), config.fade_m)
	groups = groups.filter(func(group: Dictionary) -> bool: return group["mesh"] != null)


## The species a config draws on a map, without meshes (headless-safe): one entry per tag (MAP_TAGS) or per species of
## the tag (MAP_TAG). Tags the map does not have give nothing.
static func describe_groups(layer: VegetationLayerConfig, map: FloraMap) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map == null:
		return out
	match layer.density_source:
		VegetationLayerConfig.DensitySource.MAP_TAGS:
			for index in map.tags.size():
				var tag := map.tags[index]
				var entry := layer.species_for_tag(tag)
				out.append(_group(tag, index, layer.model_for(tag, entry), entry))
		VegetationLayerConfig.DensitySource.MAP_TAG:
			var index := map.tag_index(layer.map_tag)
			if index < 0:
				return out
			for entry in layer.species:
				if entry and entry.weight > 0.0:
					out.append(_group(layer.map_tag, index, layer.model_for(layer.map_tag, entry), entry))
	return out


static func _group(tag: String, index: int, model: String, entry: VegetationSpecies) -> Dictionary:
	return {
		"tag": tag,
		"tag_index": index,
		"model": model,
		"pose": BodyCatalog.pose(model, false),
		"scale_range": entry.scale_range if entry else Vector2.ONE,
		"weight": entry.weight if entry else 1.0,
		"cast_shadow": entry.cast_shadow if entry else false,
		"visibility_end_m": entry.visibility_end_m if entry else 0.0,
	}


## Camera distance where a species is gone: the layer radius, or the species' own end if nearer.
static func species_end(group: Dictionary, layer: VegetationLayerConfig, preset: VegetationQuality) -> float:
	var radius := layer.radius_m * preset.radius_scale
	var own := float(group.get("visibility_end_m", 0.0))
	return minf(own, radius) if own > 0.0 else radius


## The instances of planter cell `key`, one MultiMesh buffer (XFORM_STRIDE floats each, cell-local: the cell's corner
## at the map origin's height 0) per entry of `groups`. Pure: the same inputs give the same floats.
## `height` is a Callable(x, z) -> float, NAN off the ground. `clears`: rows x, z, radius, edge.
static func plan_cell(layer: VegetationLayerConfig, map: FloraMap, layer_groups: Array[Dictionary], density: float,
		key: Vector2i, height: Callable, clears: PackedVector4Array) -> Array[PackedFloat32Array]:
	var items: Array = []
	items.resize(layer_groups.size())
	for g in layer_groups.size():
		items[g] = []
	var seed := layer.placement_seed
	var texel := map.texel_m
	var split := layer.density_source == VegetationLayerConfig.DensitySource.MAP_TAG
	var total_weight := 0.0
	for group in layer_groups:
		total_weight += float(group["weight"])
	# Tags plant once each (MAP_TAG: all groups share one tag).
	var tags_done := {}
	for dz in DATA_PER_CELL:
		for dx in DATA_PER_CELL:
			var tx := key.x * DATA_PER_CELL + dx
			var tz := key.y * DATA_PER_CELL + dz
			var sub := dz * DATA_PER_CELL + dx
			tags_done.clear()
			for g in layer_groups.size():
				var group: Dictionary = layer_groups[g]
				var tag: String = group["tag"]
				if tags_done.has(tag):
					continue
				tags_done[tag] = true
				var count := map.count_at(int(group["tag_index"]), tx, tz)
				if count <= 0:
					continue
				var n := FloraPlacement.instance_count(seed, tag, tx, tz, count, density)
				if n <= 0:
					continue
				var tag_h := FloraPlacement.tag_hash(tag)
				var spots := FloraPlacement.cell_instances(seed, tag, tx, tz, n, texel, Vector2(0.0, 1.0))
				for i in n:
					var target := g
					if split:
						target = _pick(layer_groups, total_weight, FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_SPECIES, tag_h, tx, tz, i)))
					var at := i * FloraPlacement.STRIDE
					(items[target] as Array).append([(float(i) + 0.5) / float(n), sub, spots[at], spots[at + 1], spots[at + 2], spots[at + 3], tag_h, tx, tz, i])
	var out: Array[PackedFloat32Array] = []
	var corner := Vector2(key) * CELL_M
	for g in layer_groups.size():
		var list: Array = items[g]
		list.sort_custom(_by_rank)
		var group: Dictionary = layer_groups[g]
		var pose: Transform3D = group["pose"]
		var range_v: Vector2 = group["scale_range"]
		var buffer := PackedFloat32Array()
		buffer.resize(list.size() * XFORM_STRIDE)
		var kept := 0
		for item: Array in list:
			var x: float = item[2]
			var z: float = item[3]
			if not clears.is_empty() and _cleared(clears, x, z, seed, item):
				continue
			var y: float = height.call(x, z)
			if is_nan(y):
				continue
			var s := lerpf(range_v.x, range_v.y, float(item[5]))
			var xform := Transform3D(Basis(Vector3.UP, float(item[4])).scaled(Vector3(s, s, s)), Vector3(x - corner.x, y, z - corner.y)) * pose
			_write(buffer, kept, xform)
			kept += 1
		buffer.resize(kept * XFORM_STRIDE)
		out.append(buffer)
	return out


static func _by_rank(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	return a[1] < b[1]


static func _pick(layer_groups: Array[Dictionary], total: float, u: float) -> int:
	var at := u * total
	for g in layer_groups.size():
		at -= float(layer_groups[g]["weight"])
		if at < 0.0:
			return g
	return layer_groups.size() - 1


## Inside a clear, or in its edge where a hash of the instance thins it linearly to nothing at the rim.
static func _cleared(clears: PackedVector4Array, x: float, z: float, seed: int, item: Array) -> bool:
	for clear in clears:
		var d := Vector2(x - clear.x, z - clear.y).length()
		if d < clear.z:
			return true
		if clear.w > 0.0 and d < clear.z + clear.w:
			var keep := (d - clear.z) / clear.w
			if FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_CLEAR, int(item[6]), int(item[7]), int(item[8]), int(item[9]))) > keep:
				return true
	return false


## MultiMesh TRANSFORM_3D layout: the 3 x 4 matrix row by row.
static func _write(buffer: PackedFloat32Array, index: int, t: Transform3D) -> void:
	var at := index * XFORM_STRIDE
	buffer[at] = t.basis.x.x
	buffer[at + 1] = t.basis.y.x
	buffer[at + 2] = t.basis.z.x
	buffer[at + 3] = t.origin.x
	buffer[at + 4] = t.basis.x.y
	buffer[at + 5] = t.basis.y.y
	buffer[at + 6] = t.basis.z.y
	buffer[at + 7] = t.origin.y
	buffer[at + 8] = t.basis.x.z
	buffer[at + 9] = t.basis.y.z
	buffer[at + 10] = t.basis.z.z
	buffer[at + 11] = t.origin.z


## A copy of the mesh's only material that dithers out between end - fade and end (camera distance). Null for a mesh with
## several surfaces (material_override would paint them all one way) or no fade: the node's visibility range still ends it.
static func _fade_material(mesh: Mesh, end_m: float, fade_m: float) -> Material:
	if mesh == null or mesh.get_surface_count() != 1 or fade_m <= 0.0:
		return null
	var base := mesh.surface_get_material(0) as BaseMaterial3D
	if base == null:
		return null
	var copy := base.duplicate() as BaseMaterial3D
	copy.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	# max < min reverses the fade: opaque up to max, gone at min.
	copy.distance_fade_max_distance = maxf(end_m - fade_m, 0.0)
	copy.distance_fade_min_distance = end_m
	return copy


## Brings the ring to the camera (`camera_global`) and builds up to the budget. Call once per frame.
func update(camera_global: Vector3) -> void:
	var cam := _map_inverse * camera_global
	var ground := terrain.ground_height(cam.x, cam.z)
	var above := maxf(cam.y - (ground if not is_nan(ground) else terrain.lowest_ground()), 0.0)
	var radius := config.radius_m * quality.radius_scale
	_radius = sqrt(radius * radius - above * above) if radius > above else -2.0 * _ring.keep_margin_m
	_eye = Vector2(cam.x, cam.z)
	var changes := _ring.update(_radius, _eye, _eye)
	for key: Vector2i in changes["added"]:
		if _cache.has(key):
			_restore(key)
		else:
			_pending.append(key)
			_pending_sorted = false
	for key: Vector2i in changes["removed"]:
		if _cells.has(key):
			_stash(key)
		else:
			_pending.erase(key)
	for key: Vector2i in changes["retiered"]:
		if _cells.has(key):
			_apply_tier(_cells[key], _ring.tier_of(key))
	_build_some()


## The clears changed (map coordinates): the cells they touched (before or after) are built again.
func set_clears(clears: PackedVector4Array) -> void:
	if clears == _clears:
		return
	var touched := PackedVector4Array()
	for clear in clears:
		if not _clears.has(clear):
			touched.append(clear)
	for clear in _clears:
		if not clears.has(clear):
			touched.append(clear)
	_clears = clears
	for key: Vector2i in _cache.keys():
		if _touches(key, touched):
			_free_nodes(_cache[key])
			_cache.erase(key)
			_cache_order.erase(key)
	for key: Vector2i in _cells.keys():
		if _touches(key, touched):
			_free_nodes(_cells[key])
			_cells.erase(key)
			_pending.append(key)
			_pending_sorted = false


func _touches(key: Vector2i, touched: PackedVector4Array) -> bool:
	for clear in touched:
		if _ring.rect_distance(key, Vector2(clear.x, clear.y)) < clear.z + clear.w:
			return true
	return false


func _build_some() -> void:
	last_frame_build_us = 0
	if _pending.is_empty():
		return
	if not _pending_sorted:
		var eye := _eye
		var ring := _ring
		_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return ring.rect_distance(a, eye) > ring.rect_distance(b, eye))
		_pending_sorted = true
	var started := Time.get_ticks_usec()
	for i in quality.max_builds_per_frame:
		if _pending.is_empty():
			break
		var key: Vector2i = _pending.pop_back()
		_cells[key] = _build(key)
		built_cells += 1
	last_frame_build_us = Time.get_ticks_usec() - started
	worst_frame_build_us = maxi(worst_frame_build_us, last_frame_build_us)


func _build(key: Vector2i) -> Array:
	var buffers := plan_cell(config, flora, groups, quality.density_scale, key, terrain.ground_height, _clears)
	var nodes := []
	var cell_xform := map_xform * Transform3D(Basis.IDENTITY, Vector3(key.x * CELL_M, 0.0, key.y * CELL_M))
	var tier := _ring.tier_of(key)
	for g in groups.size():
		var buffer: PackedFloat32Array = buffers[g]
		var count := buffer.size() / XFORM_STRIDE
		if count == 0:
			continue
		var group: Dictionary = groups[g]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group["mesh"]
		multimesh.instance_count = count
		multimesh.buffer = buffer
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.material_override = group["material"]
		var shadow := bool(group["cast_shadow"]) and quality.shadows
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.visibility_range_end = float(group["end_m"]) + CELL_REACH_M
		node.top_level = true
		host.add_child(node, false, Node.INTERNAL_MODE_BACK)
		node.global_transform = cell_xform
		nodes.append(node)
	_apply_tier(nodes, tier)
	return nodes


func _apply_tier(nodes: Array, tier: int) -> void:
	var fractions := config.tier_fractions
	var fraction := fractions[clampi(tier, 0, fractions.size() - 1)] if not fractions.is_empty() else 1.0
	for node: MultiMeshInstance3D in nodes:
		var multimesh := node.multimesh
		multimesh.visible_instance_count = -1 if fraction >= 1.0 else ceili(multimesh.instance_count * fraction)


func _stash(key: Vector2i) -> void:
	var nodes: Array = _cells[key]
	_cells.erase(key)
	for node: Node3D in nodes:
		node.visible = false
	_cache[key] = nodes
	_cache_order.append(key)
	while _cache_order.size() > CACHE_SIZE:
		var oldest: Vector2i = _cache_order.pop_front()
		_free_nodes(_cache[oldest])
		_cache.erase(oldest)


func _restore(key: Vector2i) -> void:
	var nodes: Array = _cache[key]
	_cache.erase(key)
	_cache_order.erase(key)
	for node: Node3D in nodes:
		node.visible = true
	_apply_tier(nodes, _ring.tier_of(key))
	_cells[key] = nodes


func _free_nodes(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()


## Frees every node (shown and cached) and forgets the ring.
func clear() -> void:
	for key in _cells:
		_free_nodes(_cells[key])
	for key in _cache:
		_free_nodes(_cache[key])
	_cells.clear()
	_cache.clear()
	_cache_order.clear()
	_pending.clear()
	_ring.clear()


## Cells built and shown (inside the ring).
func cell_count() -> int:
	return _cells.size()


func pending_count() -> int:
	return _pending.size()


func node_count() -> int:
	var sum := 0
	for key in _cells:
		sum += (_cells[key] as Array).size()
	return sum


## Instances drawn by the shown cells (their visible prefix).
func instance_count() -> int:
	var sum := 0
	for key in _cells:
		for node: MultiMeshInstance3D in _cells[key]:
			var shown := node.multimesh.visible_instance_count
			sum += node.multimesh.instance_count if shown < 0 else shown
	return sum
