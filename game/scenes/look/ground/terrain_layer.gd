@tool
class_name TerrainLayer
extends LookLayer

## Ground layer of the rig: gives the map's terrain the biome's `GroundSet` as a PBR material
## (`ground_pbr.gdshader`). Hiding the node, a null profile or a profile without ground puts the
## classic atlas x light map ground back. Heights and collision are untouched (the mesh is the
## same). The material and the zone mask are rebuilt from the map on every load and never saved.

var _rig: LookRig
var _ground: GroundSet
var _preset: LookQuality
var _material: ShaderMaterial
var _watching: Array[Resource] = []


func _ready() -> void:
	visibility_changed.connect(_refresh)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_preset = rig.quality_preset
	_set_ground(profile.ground as GroundSet if profile else null)


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	if _material and _ground:
		GroundMaterial.update(_material, _ground, _preset)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	# The preview is a runtime override that the terrain never stores; put the classic back anyway.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_restore()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_refresh()


func _set_ground(ground: GroundSet) -> void:
	_unwatch()
	_ground = ground
	_material = null
	if _ground:
		_watch(_ground)
		for layer in _ground.layers:
			if layer:
				_watch(layer)
	_refresh()


## Editor: editing a GroundSet or a GroundLayer in the inspector refreshes the preview.
func _watch(resource: Resource) -> void:
	if not resource.changed.is_connected(_on_resource_changed):
		resource.changed.connect(_on_resource_changed)
		_watching.append(resource)


func _unwatch() -> void:
	for resource in _watching:
		if is_instance_valid(resource) and resource.changed.is_connected(_on_resource_changed):
			resource.changed.disconnect(_on_resource_changed)
	_watching.clear()


func _on_resource_changed() -> void:
	if Engine.is_editor_hint():
		_set_ground(_ground)


func _refresh() -> void:
	var terrain := _rig.terrain if _rig else null
	if terrain == null:
		return
	if _ground == null or not is_visible_in_tree():
		_restore()
		return
	if _material == null:
		_material = GroundMaterial.build(_ground, terrain.call("tile_ids"), _preset)
	else:
		GroundMaterial.update(_material, _ground, _preset)
	terrain.call("set_ground_override", _material)


func _restore() -> void:
	var terrain := _rig.terrain if _rig else null
	if terrain:
		terrain.call("clear_ground_override")


func _exit_tree() -> void:
	_unwatch()
