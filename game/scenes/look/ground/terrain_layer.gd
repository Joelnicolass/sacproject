@tool
class_name TerrainLayer
extends LookLayer

## Ground layer of the rig: the only writer of the map's terrain material. A look with a `GodGround` gets the god's ground on
## the map's ground roles and baked light (`ground.gdshader`, built by GroundMaterial); a look without one keeps the biome's
## classic ground (`ground_classic`: atlas x light map; the map's own tiles when the map is made of the look's god,
## `NativeGround`) until every god has its GodGround (plan 062, cut 3). Hiding the node or a null profile shows the classic
## one. Heights and collision are untouched (the mesh is the same). The materials are rebuilt on every load and never saved.

var _rig: LookRig
var _ground: GodGround
var _classic: ShaderMaterial
var _classic_given: ShaderMaterial
var _preset: LookQuality
var _material: ShaderMaterial


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


## Editor: editing the GodGround (or one of its roles) in the inspector refreshes the preview.
func _set_ground(ground: GodGround) -> void:
	_unwatch()
	_ground = ground
	_material = null
	if _ground and Engine.is_editor_hint():
		_ground.changed.connect(_refresh)
	_refresh()


func _unwatch() -> void:
	if _ground and _ground.changed.is_connected(_refresh):
		_ground.changed.disconnect(_refresh)


func _refresh() -> void:
	var terrain := _mesh()
	if terrain == null:
		return
	# The terrain keeps a private copy of the classic material (the grass paints into it): hand it over once per material.
	if terrain is TerrainMesh and _classic != null and _classic != _classic_given:
		(terrain as TerrainMesh).set_classic_material(_classic)
		_classic_given = _classic
	if _ground == null or not is_visible_in_tree():
		_restore()
		return
	if _material == null:
		var map_terrain := terrain as TerrainMesh
		_material = GroundMaterial.build(_ground, map_terrain.ground_roles if map_terrain else null,
				map_terrain.light_map if map_terrain else null, _preset)
	else:
		GroundMaterial.update(_material, _ground, _preset)
	terrain.call("set_ground_override", _material)  # dynamic: TerrainMesh or the grass lab's GrassLabGround (debug/look) answers it


func _restore() -> void:
	var terrain := _mesh()
	if terrain:
		terrain.call("clear_ground_override")  # dynamic: TerrainMesh or the grass lab's GrassLabGround (debug/look) answers it


## The node that draws the map's ground (`terrain.mesh`).
func _mesh() -> MeshInstance3D:
	return _rig.terrain.mesh if _rig and _rig.terrain else null


func _exit_tree() -> void:
	_unwatch()
