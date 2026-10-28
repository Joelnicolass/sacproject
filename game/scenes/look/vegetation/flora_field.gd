@tool
class_name FloraField
extends LookLayer

## The mesh vegetation of a map (Look/Layers/Flora). One MeshPlanter per VegetationLayerConfig of
## `configs` (original_plants.tres), each drawing the FloraLayer nodes of the map (the `Vegetation`
## node of its map.tscn; a snapshot, FloraDensity) around the camera: the 3D viewport's in the
## editor, the game's when playing. How much each layer draws comes from the quality preset
## (`LookQuality.vegetation_for(config.id)`; the editor uses `editor_quality`); a preset without an
## entry for a layer, the rig's «Vegetación» switch off (GraphicsPrefs), the node hidden or a map
## without FloraLayers draws nothing. A FloraLayer that changes calls `layers_changed` (group
## `GROUP`).
## Presentation only: no collision, no RPC, no shared RNG. Every node it makes is an internal child,
## never saved. In a dedicated or headless process the rig is freed, and this never builds anything
## there either. A `VegetationClear` that moves calls `clears_changed` (group `vegetation_field`;
## FloraClears): only the cells it touches are rebuilt. The map brush painting a layer calls
## `layer_painted`: only that area plans again, the planters stay.

## Group of the fields: FloraLayer calls `layers_changed` on it.
const GROUP := &"flora_field"

## The rig this layer belongs to (look_rig.tscn sets it): the terrain, the preset and the switch.
@export var rig: LookRig
## One mesh layer each.
@export var configs: Array[VegetationLayerConfig] = []:
	set(value):
		configs = value
		if is_node_ready():
			_watch_configs()
			_refresh()
## The preset the editor previews with (the editor has no GraphicsPrefs).
@export var editor_quality: LookQuality:
	set(value):
		editor_quality = value
		if is_node_ready():
			_refresh()
## Editor only: the plants follow the 3D viewport camera (turn off to freeze them).
@export var follow_editor_camera := true
## Main-thread time per frame for every layer together: past it the finished cells wait for the next
## frame. The planning itself runs on WorkerThreadPool tasks (in the editor, on the main thread
## inside this same budget).
@export_range(0.1, 8.0, 0.1, "suffix:ms") var build_budget_ms := 1.0
## The ground moved (a spell raised it): the plants of that part are planned again at most this
## often.
@export_range(0.05, 2.0, 0.05, "suffix:s") var replan_every_s := 0.25
## A stamp still playing (the Volcano mound, 64 s) plants the cells it touches again this often; 0 =
## only when settled.
@export_range(0.0, 5.0, 0.05, "suffix:s") var live_replan_s := 1.0

var _planters: Array[MeshPlanter] = []
var _ground := FloraGroundWatch.new()
var _signature := ""
var _clears := FloraClears.new()
var _watching: Array[Resource] = []
var _bound_rig: LookRig
## What the FloraLayer nodes of the map say now (rebuilt when one changes) and how many times it was
## rebuilt.
var _density: FloraDensity
var _density_dirty := true
## The match's land plants (the biome's GodFlora); null = the layers' own species.
var _land: GodFlora
var _density_version := 0


func _ready() -> void:
	add_to_group(VegetationClear.FIELD_GROUP)
	add_to_group(GROUP)
	visibility_changed.connect(_refresh)
	# The rig can push its saved preset before this node is ready (planters already made): keep them
	# running.
	set_process(not _planters.is_empty())
	_watch_configs()
	# After the map (terrain, rig sockets) is ready.
	_refresh.call_deferred()


func _enter_tree() -> void:
	if is_node_ready():
		_refresh.call_deferred()


func apply_look(profile: LookProfile, look_rig: LookRig) -> void:
	# The map's plants are drawn in every look; the biome's GodFlora picks the species of the
	# layers that paint a land role.
	if rig == null:
		rig = look_rig
	var land: GodFlora = profile.flora if profile else null
	if land != _land:
		_land = land
		_density_dirty = true
	_refresh()


func apply_quality(_preset: LookQuality) -> void:
	_refresh()


## `FloraLayer` nodes call this (through the group) when one changes, enters or leaves the tree.
func layers_changed() -> void:
	_density_dirty = true
	_refresh.call_deferred()


## `VegetationClear` nodes call this (through the group) when one moves, resizes or leaves.
func clears_changed() -> void:
	_clears.mark()


## The map brush painted `layer` over `area_m` (map x, z; FloraLayer.show_painting): a new snapshot
## with its bytes goes to the same planters, which plan that area again under the ground's brake. A
## layer not drawn yet makes the full rebuild.
func layer_painted(layer: FloraLayer, area_m: Rect2) -> void:
	var id := layer.get_instance_id()
	if _density == null or _density_dirty or not _density.layer_ids.has(id):
		layers_changed()
		return
	_density = _density.with_layer_bytes(id, layer.density_image().get_data())
	for planter in _planters:
		planter.set_flora(_density)
	_ground.mark(area_m)


## True in a process that draws nothing: headless or the dedicated server.
static func presentationless() -> bool:
	return DisplayServer.get_name() == "headless" or MpBoot.is_dedicated_process()


## The preset in use: the editor's, or the rig's in the game (none: nothing is drawn).
func preset() -> LookQuality:
	if Engine.is_editor_hint():
		return editor_quality
	return rig.quality_preset if rig else null


## The layers this field draws with the current rig, preset and switch: [{config, quality}]. The
## process kind (headless, dedicated) is not part of it: `presentationless` stops the building on
## top.
func active_layers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if (
		rig == null
		or not is_inside_tree()
		or not rig.vegetation_enabled
		or density().entries() == 0
	):
		return out
	var current := preset()
	if current == null:
		return out
	for config in configs:
		if config == null:
			continue
		var layer_quality := current.vegetation_for(config.id)
		if layer_quality == null or not layer_quality.enabled or layer_quality.density_scale <= 0.0:
			continue
		out.append({"config": config, "quality": layer_quality})
	return out


func _refresh() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group(VegetationPatch.GROUP, &"field_changed")
	_bind_rig()
	var layers: Array[Dictionary] = []
	if is_visible_in_tree() and not presentationless():
		layers = active_layers()
	var surface := rig.terrain if rig else null
	if surface == null or not surface.is_loaded():
		layers.clear()
	_ground.follow(surface)  # the editor too: a brush stroke settles the ground under the plants
	var signature := _signature_of(layers, surface)
	if signature == _signature:
		return
	_free_planters()
	_signature = signature
	for layer in layers:
		var planter := MeshPlanter.new(layer["config"], layer["quality"], density(), surface, self)
		# The editor reloads tool scripts under a running task: plan on the main thread there.
		planter.threaded = not Engine.is_editor_hint()
		_planters.append(planter)
	_clears.mark()
	set_process(not _planters.is_empty())


func _bind_rig() -> void:
	if _bound_rig == rig:
		return
	if (
		is_instance_valid(_bound_rig)
		and _bound_rig.vegetation_toggled.is_connected(_on_vegetation_toggled)
	):
		_bound_rig.vegetation_toggled.disconnect(_on_vegetation_toggled)
	_bound_rig = rig
	if rig and not rig.vegetation_toggled.is_connected(_on_vegetation_toggled):
		rig.vegetation_toggled.connect(_on_vegetation_toggled)


func _on_vegetation_toggled(_enabled: bool) -> void:
	_refresh()


## What the planters depend on: a change of it rebuilds them.
func _signature_of(layers: Array[Dictionary], surface: Terrain) -> String:
	var parts := PackedStringArray()
	parts.append(str(_density_version))
	parts.append(str(surface.get_instance_id() if surface else 0))
	for layer in layers:
		var q: VegetationQuality = layer["quality"]
		parts.append(
			(
				"%d:%s:%s:%s:%s:%d"
				% [
					(layer["config"] as Object).get_instance_id(),
					q.enabled,
					q.radius_scale,
					q.density_scale,
					q.shadows,
					q.max_builds_per_frame
				]
			)
		)
	return "|".join(parts)


func _process(delta: float) -> void:
	if _planters.is_empty():
		return
	var camera := CellRing.view_camera(self, follow_editor_camera)
	if camera == null:
		return
	_clears.update(delta, _planters, get_tree())
	_ground.live_every_s = live_replan_s
	_ground.update(delta, replan_every_s, _planters, get_tree())
	var deadline := Time.get_ticks_usec() + int(build_budget_ms * 1000.0)
	for planter in _planters:
		planter.update(camera.global_position, deadline)


func _free_planters() -> void:
	for planter in _planters:
		planter.clear()
	_planters.clear()
	_signature = ""
	set_process(false)


func _watch_configs() -> void:
	for resource in _watching:
		if is_instance_valid(resource) and resource.changed.is_connected(_on_config_changed):
			resource.changed.disconnect(_on_config_changed)
	_watching.assign(
		configs.filter(func(config: VegetationLayerConfig) -> bool: return config != null)
	)
	for resource in _watching:
		resource.changed.connect(_on_config_changed)


## Editing a config in the inspector rebuilds the layers.
func _on_config_changed() -> void:
	_watch_configs()
	_free_planters()
	_refresh()


## Instances drawn now by every layer (the visible prefix of each shown cell).
func instance_count() -> int:
	return _planters.reduce(
		func(sum: int, planter: MeshPlanter) -> int: return sum + planter.instance_count(), 0
	)


## Cells built and shown by every layer.
func cell_count() -> int:
	return _planters.reduce(
		func(sum: int, planter: MeshPlanter) -> int: return sum + planter.cell_count(), 0
	)


## MultiMeshInstance3D nodes shown by every layer.
func node_count() -> int:
	return _planters.reduce(
		func(sum: int, planter: MeshPlanter) -> int: return sum + planter.node_count(), 0
	)


func pending_count() -> int:
	return _planters.reduce(
		func(sum: int, planter: MeshPlanter) -> int: return sum + planter.pending_count(), 0
	)


## The FloraLayer nodes of this field's map as a snapshot: the layers under the same MapRoot (or,
## without one, in the tree), taken again after one changed.
func density() -> FloraDensity:
	if _density == null or _density_dirty:
		_density_dirty = false
		_density_version += 1
		_density = FloraDensity.gather(_scope(), _land)
	return _density


func _scope() -> Node:
	var node: Node = self
	while node and not node is MapRoot:
		node = node.get_parent()
	return node if node else get_tree().root


func planters() -> Array[MeshPlanter]:
	return _planters


func _exit_tree() -> void:
	_ground.follow(null)
	_free_planters()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if rig == null:
		warnings.append("The Rig socket is missing (the map's LookRig).")
	if editor_quality == null:
		warnings.append("editor_quality is missing: the editor shows no plants.")
	return warnings
