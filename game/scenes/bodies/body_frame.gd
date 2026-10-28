@tool
class_name BodyFrame
extends Node3D

## The size and the sockets of one creature or wizard, as nodes you can drag in the editor: the
## capsule it collides with, the footprint other bodies keep away from, and the markers (reach,
## center, top, muzzle, feet) the rules read.
## It only holds them: nothing here moves, draws or decides (BodyFacts reads the numbers once,
## BodyCollider sizes the physics capsule). The scene never points at its creature's type, never
## carries a synchronizer, and never loads a sound or a model: its `Look` is an instance placeholder
## of `<name>_look.tscn`, the appearance (model, sounds), and only a client builds it (BodyMount).
## Each creature has `creatures/<name>/<name>.tscn`, each wizard
## `scenes/wizards/bodies/<name>.tscn`. A creature with passives (the Firefist's fury, the Phoenix's
## shield) has a `Passives` child: an instance of `<name>_passives.tscn`, whose nodes carry the
## numbers in the inspector.

## The model id that travels in the network packets; read only, the tool writes it.
@export var model_id := ""
@export_group("Bounds")
## The capsule the body collides with on the ground (height floors at 0.6 m, radius at most 0.45 of
## the height).
@export var capsule: CollisionShape3D
## The capsule while a hybrid flier is in the air. Empty: the ground capsule is used.
@export var flying_capsule: CollisionShape3D
## The cylinder of the box other bodies keep clear of: radius = half the width, height = the real
## height of the body.
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
## The appearance (model, sounds) hangs here, as an instance placeholder of the `<name>_look.tscn`
## next to this scene (the editor draws it; a game only loads it when a client asks). Do not
## override anything on it: an override would load with this scene.
@export var look: Node
## What the creature always has (UnitPassive nodes): an instance of `<name>_passives.tscn` next to
## this scene, or empty for none. Edit the numbers in that scene: the game builds it on its own, so
## changes made to it here are not used.
@export var passives: Node


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if capsule == null or not capsule.shape is CapsuleShape3D:
		warnings.append("Missing `capsule` (a CollisionShape3D with a CapsuleShape3D).")
	if flying_capsule != null and not flying_capsule.shape is CapsuleShape3D:
		warnings.append("`flying_capsule` must hold a CapsuleShape3D.")
	if footprint == null or not footprint.shape is CylinderShape3D:
		warnings.append("Missing `footprint` (a CollisionShape3D with a CylinderShape3D).")
	if reach == null or center == null or top == null:
		warnings.append("Missing markers: `reach`, `center` and `top`.")
	if look == null:
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"Missing `look`: the `Look` node with the look (<name>_look.tscn) as an instance, «Load As Placeholder»."
			)
		)
	elif look.scene_file_path.is_empty() and not look is InstancePlaceholder:
		warnings.append("`look` must be the instance of <name>_look.tscn.")
	elif not look is InstancePlaceholder and not look.get_scene_instance_load_placeholder():
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"`look` must load as a placeholder (right click › Load As Placeholder): otherwise the server loads the model and the sounds."
			)
		)
	if model_id.is_empty():
		warnings.append("`model_id` is empty: the network would not know which model to draw.")
	if passives != null and passives.scene_file_path.is_empty():
		warnings.append("`passives` must be the instance of <name>_passives.tscn.")
	elif passives != null and is_editable_instance(passives):
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"Changes to `Passives` made in this scene are not used: edit the numbers in <name>_passives.tscn."
			)
		)
	return warnings


## True when every node the rules read is in place.
func is_complete() -> bool:
	return (
		capsule != null
		and capsule.shape is CapsuleShape3D
		and footprint != null
		and footprint.shape is CylinderShape3D
		and reach != null
		and center != null
		and top != null
		and not model_id.is_empty()
	)


## Where the appearance scene of this body is (creatures/<name>/<name>_look.tscn); ""
## without a `Look`. Read from the placeholder, so nothing of the appearance is loaded.
func look_path() -> String:
	if look is InstancePlaceholder:
		return (look as InstancePlaceholder).get_instance_path()
	return look.scene_file_path if look != null else ""
