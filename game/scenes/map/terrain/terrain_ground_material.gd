class_name TerrainGroundMaterial
extends RefCounted

## Which material the ground mesh shows: the classic one the scene stores (a god's ground_classic.tres), and the
## biome's PBR ground when a look layer gives one (it wins until cleared). In the editor it remembers the scene's own
## material so saving never writes a preview. What it does NOT do: decide the look (LookRig does) or touch the mesh.

const DEFAULT_GROUND := "res://assets/original/themes/james/ground_classic.tres"

var _target: GeometryInstance3D
## The classic ground (the `material_override` the scene stores).
var _classic: ShaderMaterial
var _override: Material
## Editor only: what the scene saves while code shows another ground.
var _stored: Material
var _swapped := false


func _init(target: GeometryInstance3D) -> void:
	_target = target


## The classic atlas x light map material (null until the ground is loaded), also while a look layer shows its own
## ground: the classic grass paints it and bakes its colors from it.
func classic() -> ShaderMaterial:
	return _classic


## Takes the classic ground from the scene's `material_override`; a TerrainMesh built from the script alone (a probe) gets
## James's.
func adopt_scene_material() -> void:
	var scene_material: ShaderMaterial = null if _swapped else (_target.material_override as ShaderMaterial)
	if Engine.is_editor_hint() and scene_material:
		_classic = scene_material
	elif _classic == null:
		if scene_material == null and ResourceLoader.exists(DEFAULT_GROUND):
			scene_material = load(DEFAULT_GROUND) as ShaderMaterial
		_classic = _runtime_copy(scene_material)
	if _classic == null:
		return
	if not _swapped:
		_target.material_override = _override if _override else _classic


## A biome's classic ground (`LookProfile.ground_classic`). In a match the terrain works on a copy: the grass writes
## its paint into the classic material and the shared resource must stay as saved.
func set_classic(material: ShaderMaterial) -> void:
	_classic = _runtime_copy(material)
	_show(_override if _override else _classic)


## A look layer's ground material replaces the classic one until it is cleared (null). The mesh, heights and
## collision do not change.
func set_override(material: Material) -> void:
	_override = material
	_show(_override if _override else _classic)


## Editor: before saving the scene keeps its own material, never a preview.
func before_save() -> void:
	if _swapped:
		_target.material_override = _stored


func after_save() -> void:
	if _swapped:
		_target.material_override = _override if _override else _classic


func _runtime_copy(material: ShaderMaterial) -> ShaderMaterial:
	if Engine.is_editor_hint() or material == null or material.resource_path.is_empty():
		return material
	return material.duplicate()


## Shows `material`; in the editor remembers the scene's own so saving never writes a preview.
func _show(material: Material) -> void:
	if Engine.is_editor_hint() and not _swapped:
		_stored = _target.material_override
	_target.material_override = material
	_swapped = Engine.is_editor_hint() and material != _stored
