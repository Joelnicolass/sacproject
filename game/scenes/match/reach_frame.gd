@tool
class_name ReachFrame
extends Node3D

## The reaches of the match as nodes you can drag in the editor: how far a wizard picks up a soul, how far the mana of a fount and an
## altar reaches, the Manahoar aura, and how far a Guardian can be armed, strays and comes back. It only holds them: nothing here
## moves, draws or decides (ReachFacts reads the numbers once). The scene is never instanced by the game (its Area3D would move the
## simulation); it is read from its SceneState. To change a reach, open `reach_places.tscn` (or an inherited scene) and drag the shape.

@export_group("Souls")
## How far a wizard picks up a soul: the radius on the ground, and half the height up and down (a cylinder).
@export var soul: CollisionShape3D
@export_group("Mana")
## How far a mana fount feeds the wizards around it.
@export var fount: CollisionShape3D
## How far an altar feeds the wizards around it.
@export var altar: CollisionShape3D
@export_group("Manahoar")
## Inside this sphere the Manahoar gives mana to its allies' side.
@export var manahoar_aura: CollisionShape3D
## Up to this distance from an allied Manalith the Manahoar gives its full rate.
@export var manahoar_peak: CollisionShape3D
## Farther than this from an allied Manalith the Manahoar gives nothing.
@export var manahoar_end: CollisionShape3D
@export_group("Guardian")
## The wizard needs a standing building of his own this close to arm Guardian.
@export var guardian_arm: CollisionShape3D
## Farther than this from the post the guardian gets an order back.
@export var guardian_leash: CollisionShape3D
## How close to the building the guardian is sent back.
@export var guardian_return: CollisionShape3D
## Where on the guardian the leash is measured from, relative to its feet.
@export var guardian_leash_from: Marker3D


func _get_configuration_warnings() -> PackedStringArray:
	var shapes: Dictionary[String, CollisionShape3D] = {
		"soul": soul, "fount": fount, "altar": altar, "manahoar_aura": manahoar_aura, "manahoar_peak": manahoar_peak,
		"manahoar_end": manahoar_end, "guardian_arm": guardian_arm, "guardian_leash": guardian_leash,
		"guardian_return": guardian_return}
	var marks: Dictionary[String, Marker3D] = {"guardian_leash_from": guardian_leash_from}
	return PlaceWarnings.check(shapes, marks)
