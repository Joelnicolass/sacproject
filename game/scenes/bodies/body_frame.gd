@tool
class_name BodyFrame
extends Node3D

## The size and the sockets of one creature or wizard, as nodes you can drag in the editor: the capsule it collides with, the
## footprint other bodies keep away from, and the markers (reach, center, top, muzzle, feet) the rules read.
## It only holds them: nothing here moves, draws or decides (BodyFacts reads the numbers once, BodyCollider sizes the physics capsule).
## The scene never points at its creature's type, never carries a synchronizer, and never loads a sound or a model.
## Each creature has `scenes/units/bodies/<name>.tscn`, each wizard `scenes/wizards/bodies/<name>.tscn`.

## The model id that travels in the network packets (what the original calls the body); read only, the tool writes it.
@export var model_id := ""
@export_group("Bounds")
## The capsule the body collides with on the ground (height floors at 0.6 m, radius at most 0.45 of the height).
@export var capsule: CollisionShape3D
## The capsule while a hybrid flier is in the air. Empty: the ground capsule is used.
@export var flying_capsule: CollisionShape3D
## The cylinder of the box other bodies keep clear of: radius = half the width, height = the real height of the body.
@export var footprint: CollisionShape3D
@export_group("Sockets")
## How far in front of the body its blow reaches (local +Z).
@export var reach: Marker3D
## The middle of the body: where the soul appears, where effects aim.
@export var center: Marker3D
## The top of the body: where the health bar and the damage numbers sit.
@export var top: Marker3D
## Where a thrown ball leaves the hand (wizards). Empty: 0.65 of the height, `reach` in front.
@export var muzzle: Marker3D
## The soles of the feet, relative to the origin of the body (wizards).
@export var feet: Marker3D
## The appearance (model, sounds) hangs here; it stays empty until the appearance scenes exist.
@export var look: Node3D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if capsule == null or not capsule.shape is CapsuleShape3D:
		warnings.append("Falta `capsule` (CollisionShape3D con una CapsuleShape3D).")
	if flying_capsule != null and not flying_capsule.shape is CapsuleShape3D:
		warnings.append("`flying_capsule` tiene que llevar una CapsuleShape3D.")
	if footprint == null or not footprint.shape is CylinderShape3D:
		warnings.append("Falta `footprint` (CollisionShape3D con una CylinderShape3D).")
	if reach == null or center == null or top == null:
		warnings.append("Faltan marcadores: `reach`, `center` y `top`.")
	if model_id.is_empty():
		warnings.append("`model_id` vacío: el cable no sabría qué modelo dibujar.")
	return warnings


## True when every node the rules read is in place.
func is_complete() -> bool:
	return _get_configuration_warnings().is_empty()
