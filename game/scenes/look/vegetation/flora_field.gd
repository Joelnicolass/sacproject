@tool
class_name FloraField
extends LookLayer

## RFC-054 054c (F382): the mesh vegetation of a map (Look/Layers/Flora). One MeshPlanter per VegetationLayerConfig of
## `configs` (original_plants.tres: the plants of the original; trees.tres: empty), each drawing the map's FloraMap
## (`LookRig.flora_map`, set in the map.tscn) around the camera: the 3D viewport's in the editor, the game's when playing.
## How much each layer draws comes from the quality preset (`LookQuality.vegetation_for(config.id)`; the editor uses
## `editor_quality`); a preset without an entry for a layer, the rig's «Vegetación» switch off (GraphicsPrefs), the node
## hidden or a map without a FloraMap draws nothing.
## Presentation only: no collision, no RPC, no shared RNG. Every node it makes is an internal child, never saved. In a
## dedicated or headless process the rig is freed, and this never builds anything there either.
## A `VegetationClear` that moves calls `clears_changed` (group `vegetation_field`): only the cells it touches are rebuilt.

const CLEAR_POLL_S := 1.0

## The rig this layer belongs to (look_rig.tscn sets it): the FloraMap, the terrain, the preset and the switch.
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
## Main-thread time per frame for every layer together (054e, F384): past it the finished cells wait for the next frame.
## The planning itself runs on WorkerThreadPool tasks (in the editor, on the main thread inside this same budget).
@export_range(0.1, 8.0, 0.1, "suffix:ms") var build_budget_ms := 1.0

var _planters: Array[MeshPlanter] = []
var _signature := ""
var _clears_dirty := true
var _clear_timer := 0.0
var _watching: Array[Resource] = []
var _bound_rig: LookRig
## Main-thread microseconds of the planters (ring + applying cells) in the last frame, and the worst frame since the
## planters were made.
var _last_frame_us := 0
var _worst_frame_us := 0


func _ready() -> void:
	add_to_group(VegetationClear.FIELD_GROUP)
	visibility_changed.connect(_refresh)
	set_process(false)
	_watch_configs()
	# After the map (terrain, rig sockets) is ready.
	_refresh.call_deferred()


func _enter_tree() -> void:
	if is_node_ready():
		_refresh.call_deferred()


func apply_look(_profile: LookProfile, look_rig: LookRig) -> void:
	# The plants of the original are drawn in every look (classic or a biome): the profile does not matter.
	if rig == null:
		rig = look_rig
	_refresh()


func apply_quality(_preset: LookQuality) -> void:
	_refresh()


## `VegetationClear` nodes call this (through the group) when one moves, resizes or leaves.
func clears_changed() -> void:
	_clears_dirty = true


## True in a process that draws nothing: headless or the dedicated server.
static func presentationless() -> bool:
	return DisplayServer.get_name() == "headless" or MpBoot.is_dedicated_process()


## The preset in use: the editor's, or the rig's in the game (none: nothing is drawn).
func preset() -> LookQuality:
	if Engine.is_editor_hint():
		return editor_quality
	return rig.quality_preset if rig else null


## The layers this field draws with the current rig, preset and switch: [{config, quality}]. The process kind (headless,
## dedicated) is not part of it: `presentationless` stops the building on top.
func active_layers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rig == null or rig.flora_map == null or not rig.vegetation_enabled:
		return out
	var current := preset()
	if current == null:
		return out
	for config in configs:
		if config == null or not config.draws():
			continue
		var layer_quality := current.vegetation_for(config.id)
		if layer_quality == null or not layer_quality.enabled or layer_quality.density_scale <= 0.0:
			continue
		out.append({"config": config, "quality": layer_quality})
	return out


func _refresh() -> void:
	if not is_inside_tree():
		return
	_bind_rig()
	var layers: Array[Dictionary] = []
	if is_visible_in_tree() and not presentationless():
		layers = active_layers()
	var terrain := rig.terrain as Terrain if rig else null
	if terrain == null or not terrain.has_ground_data():
		layers.clear()
	var signature := _signature_of(layers, terrain)
	if signature == _signature:
		return
	_free_planters()
	_signature = signature
	_last_frame_us = 0
	_worst_frame_us = 0
	for layer in layers:
		var planter := MeshPlanter.new(layer["config"], layer["quality"], rig.flora_map, terrain, self)
		# The editor reloads tool scripts under a running task: plan on the main thread there.
		planter.threaded = not Engine.is_editor_hint()
		_planters.append(planter)
	_clears_dirty = true
	set_process(not _planters.is_empty())


func _bind_rig() -> void:
	if _bound_rig == rig:
		return
	if is_instance_valid(_bound_rig) and _bound_rig.vegetation_toggled.is_connected(_on_vegetation_toggled):
		_bound_rig.vegetation_toggled.disconnect(_on_vegetation_toggled)
	_bound_rig = rig
	if rig and not rig.vegetation_toggled.is_connected(_on_vegetation_toggled):
		rig.vegetation_toggled.connect(_on_vegetation_toggled)


func _on_vegetation_toggled(_enabled: bool) -> void:
	_refresh()


## What the planters depend on: a change of it rebuilds them.
func _signature_of(layers: Array[Dictionary], terrain: Terrain) -> String:
	var parts := PackedStringArray()
	parts.append(str(rig.flora_map.get_instance_id() if rig and rig.flora_map else 0))
	parts.append(str(terrain.get_instance_id() if terrain else 0))
	for layer in layers:
		var q: VegetationQuality = layer["quality"]
		parts.append("%d:%s:%s:%s:%s:%d" % [(layer["config"] as Object).get_instance_id(), q.enabled, q.radius_scale, q.density_scale, q.shadows, q.max_builds_per_frame])
	return "|".join(parts)


func _process(delta: float) -> void:
	if _planters.is_empty():
		return
	var camera := CellRing.view_camera(self, follow_editor_camera)
	if camera == null:
		return
	_update_clears(delta)
	var started := Time.get_ticks_usec()
	var deadline := started + int(build_budget_ms * 1000.0)
	for planter in _planters:
		planter.update(camera.global_position, deadline)
	_last_frame_us = Time.get_ticks_usec() - started
	_worst_frame_us = maxi(_worst_frame_us, _last_frame_us)


func _update_clears(delta: float) -> void:
	_clear_timer -= delta
	if _clear_timer <= 0.0:
		_clear_timer = CLEAR_POLL_S
		_clears_dirty = true
	if not _clears_dirty:
		return
	_clears_dirty = false
	for planter in _planters:
		planter.set_clears(_gather_clears(planter.map_xform.affine_inverse()))


## Every VegetationClear in map coordinates: x, z, radius, edge.
func _gather_clears(to_map: Transform3D) -> PackedVector4Array:
	var found := PackedVector4Array()
	for node in get_tree().get_nodes_in_group(VegetationClear.GROUP):
		var clear := node as VegetationClear
		if clear and clear.is_inside_tree() and clear.radius_m > 0.0:
			var local := to_map * clear.global_position
			found.append(Vector4(local.x, local.z, clear.radius_m, clear.edge_m))
	return found


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
	_watching.clear()
	for config in configs:
		if config == null:
			continue
		_watch(config)
		if config.default_species:
			_watch(config.default_species)
		for entry in config.species:
			if entry:
				_watch(entry)


func _watch(resource: Resource) -> void:
	if not resource.changed.is_connected(_on_config_changed):
		resource.changed.connect(_on_config_changed)
		_watching.append(resource)


## Editing a config or a species in the inspector rebuilds the layers (RFC-054 §11.2).
func _on_config_changed() -> void:
	_watch_configs()
	_free_planters()
	_refresh()


## Instances drawn now by every layer (the visible prefix of each shown cell).
func instance_count() -> int:
	var sum := 0
	for planter in _planters:
		sum += planter.instance_count()
	return sum


## Cells built and shown by every layer.
func cell_count() -> int:
	var sum := 0
	for planter in _planters:
		sum += planter.cell_count()
	return sum


## MultiMeshInstance3D nodes shown by every layer.
func node_count() -> int:
	var sum := 0
	for planter in _planters:
		sum += planter.node_count()
	return sum


func pending_count() -> int:
	var sum := 0
	for planter in _planters:
		sum += planter.pending_count()
	return sum


## Main-thread time of the planters (microseconds, every layer): x the last frame, y the worst since they were made.
func build_us() -> Vector2i:
	return Vector2i(_last_frame_us, _worst_frame_us)


func planters() -> Array[MeshPlanter]:
	return _planters


func _exit_tree() -> void:
	_free_planters()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if rig == null:
		warnings.append("Falta el socket Rig (el LookRig del mapa).")
	if editor_quality == null:
		warnings.append("Falta editor_quality: el editor no muestra las plantas.")
	return warnings
