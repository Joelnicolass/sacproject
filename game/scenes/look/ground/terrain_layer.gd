@tool
class_name TerrainLayer
extends LookLayer

## Ground layer of the rig: the only writer of the map's terrain material. It gives the terrain the biome's
## classic ground (`ground_classic`: atlas x light map; the map's own tiles when the map is made of the
## look's god, `NativeGround`) and, over it, the `GroundSet` as a PBR material (`ground_pbr.gdshader`).
## Hiding the node, a null profile or a profile without ground shows the classic one. Heights and
## collision are untouched (the mesh is the same). The materials and the zone mask are rebuilt from
## the map on every load and never saved.

var _rig: LookRig
var _ground: GroundSet
var _classic: ShaderMaterial
var _classic_given: ShaderMaterial
var _preset: LookQuality
var _material: ShaderMaterial
var _watching: Array[Resource] = []


func _ready() -> void:
	visibility_changed.connect(_refresh)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_preset = rig.quality_preset
	_classic = _classic_for(profile, rig)
	_set_ground(profile.ground if profile else null)


## The biome's classic ground; a copy dressed with the map's own tiles when the map is made of the look's god.
func _classic_for(profile: LookProfile, rig: LookRig) -> ShaderMaterial:
	var classic := profile.ground_classic if profile else null
	var native := rig.native_ground
	if classic == null or native == null or profile.god != native.god:
		return classic
	var dressed := classic.duplicate() as ShaderMaterial
	native.dress(dressed)
	return dressed


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
	# The terrain keeps a private copy of the classic material (the grass paints into it): hand it over once per material.
	if terrain is Terrain and _classic != null and _classic != _classic_given:
		(terrain as Terrain).set_classic_material(_classic)
		_classic_given = _classic
	if _ground == null or not is_visible_in_tree():
		_restore()
		return
	if _material == null:
		var shape := TerrainShape.of(self)
		_material = GroundMaterial.build(_ground, shape.tile_ids() if shape else PackedByteArray(), _preset)
	else:
		GroundMaterial.update(_material, _ground, _preset)
	terrain.call("set_ground_override", _material)  # dynamic: Terrain or the grass lab's GrassLabGround (debug/look) answers it


func _restore() -> void:
	var terrain := _rig.terrain if _rig else null
	if terrain:
		terrain.call("clear_ground_override")  # dynamic: Terrain or the grass lab's GrassLabGround (debug/look) answers it


func _exit_tree() -> void:
	_unwatch()
