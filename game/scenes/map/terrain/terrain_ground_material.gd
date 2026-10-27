class_name TerrainGroundMaterial
extends RefCounted

## Which material the ground mesh shows: its own (the plain «no look» one terrain.tscn stores) or the one a look layer gives,
## which wins until it is cleared. In the editor the scene always saves its own material, never a preview. What it does NOT do:
## decide the look (TerrainLayer does) or touch the mesh.

var _target: GeometryInstance3D
## The scene's own material, taken the first time a ground is worn.
var _own: Material
var _taken := false
var _worn: Material


func _init(target: GeometryInstance3D) -> void:
	_target = target


## Shows `material` on the mesh; null gives back the scene's own.
func wear(material: Material) -> void:
	if not _taken:
		_own = _target.material_override
		_taken = true
	_worn = material
	_target.material_override = material if material != null else _own


## Editor: before saving the scene keeps its own material, never a preview.
func before_save() -> void:
	if _taken:
		_target.material_override = _own


func after_save() -> void:
	if _taken:
		_target.material_override = _worn if _worn != null else _own
