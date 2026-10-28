@tool
class_name TerrainLayer
extends LookLayer

## Ground layer of the rig: the only writer of the map's terrain material. A look with a `GodGround` lays the god's ground on the
## map's ground roles and baked light (`ground.gdshader`, built by GroundMaterial); a look without one, a null profile or the
## node hidden gives the terrain back its own plain material («no look»). Heights and collision are untouched (the mesh is the
## same). The material is rebuilt on every load and never saved (TerrainMesh keeps its own when the scene is saved).

var _rig: LookRig
var _ground: GodGround
var _preset: LookQuality
var _material: ShaderMaterial


func _ready() -> void:
	visibility_changed.connect(_refresh)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_preset = rig.quality_preset
	_set_ground(profile.ground if profile else null)


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	if _material and _ground:
		GroundMaterial.update(_material, _ground, _preset)


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
	var mesh := _mesh()
	if mesh == null:
		return
	if _ground == null or not is_visible_in_tree():
		mesh.clear_ground()
		return
	if _material == null:
		_material = GroundMaterial.build(
			_ground, _rig.terrain.ground_roles, _rig.terrain.light_map, _preset
		)
	else:
		GroundMaterial.update(_material, _ground, _preset)
	mesh.set_ground(_material)


## The node that draws the map's ground (`terrain.mesh`).
func _mesh() -> TerrainMesh:
	return _rig.terrain.mesh as TerrainMesh if _rig and _rig.terrain else null


func _exit_tree() -> void:
	_unwatch()
