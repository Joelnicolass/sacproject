extends StaticBody3D

## Trimesh del terreno solo para el rayo. No es la regla del juego.

@export var terrain: MeshInstance3D

@onready var _shape: CollisionShape3D = %Shape


func _ready() -> void:
	call_deferred("_build")


func _get_configuration_warnings() -> PackedStringArray:
	if terrain == null:
		return PackedStringArray(["Falta el terreno."])
	return PackedStringArray()


func _build() -> void:
	if _shape == null or terrain == null or terrain.mesh == null:
		print("La sonda no tiene terreno.")
		return
	var trimesh := terrain.mesh.create_trimesh_shape()
	if trimesh == null:
		print("La sonda no tiene terreno.")
		return
	global_transform = terrain.global_transform
	_shape.shape = trimesh
