extends MeshInstance3D

## Runtime OBJ reader, kept for tools. Scenes use body_visual.gd with baked meshes.

const _OBJ := preload("res://scenes/world/obj_mesh.gd")

@export var cache_path: String = "res://cache/james.obj"
@export var texture_path: String = ""
@export var two_sided: bool = false
@export var missing_message: String = "Falta el mago."


func _ready() -> void:
	var built := _OBJ.build(cache_path, texture_path, {_OBJ.FOLIAGE: two_sided})
	visible = built != null
	if built == null:
		print(missing_message)
		return
	mesh = built
	material_override = null
