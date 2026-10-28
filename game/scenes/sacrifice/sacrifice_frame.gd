@tool
class_name SacrificeFrame
extends Node3D

## The places of the sacrifice as nodes you can drag in the editor: the ring the doctors stand on, how far the push reaches, where
## the carrier asks for the ritual, where the creature hangs, how far a doctor lifts a soul and where the red vortex opens.
## It only holds them: nothing here moves, draws or decides (SacrificeFacts reads the numbers once). The scene is never instanced
## by the game (its Area3D would move the simulation); it is read from its SceneState. To change a place, open
## `sacrifice_places.tscn` (or an inherited scene of it) and drag the shape or the marker.

@export_group("Ritual")
## The ring the four doctors stand on (a cylinder around the site).
@export var ring: CollisionShape3D
## The ring closed in for the last fifth of the walk.
@export var ring_end: CollisionShape3D
## The edge of the push that clears the site.
@export var push: CollisionShape3D
## The core of the push, where it is at full speed.
@export var push_core: CollisionShape3D
## Inside this sphere the carrier asks for the ritual.
@export var carrier_stop: CollisionShape3D
## Where the creature hangs while the ritual lasts (above the site).
@export var ritual_hang: Marker3D
@export_group("Carry")
## How far a doctor reaches to pick up a soul to desecrate.
@export var pickup: CollisionShape3D
## How far a doctor reaches to pump the captive (convert).
@export var pump_reach: CollisionShape3D
## Where the carried body hangs, relative to the doctor's feet (up and behind).
@export var carry_hang: Marker3D
@export_group("Drop")
## Where the vortex opens, relative to the target (up, and toward the thrower).
@export var vortex: Marker3D
## Where the doctor leaves the vortex, relative to the vortex (below it).
@export var exit: Marker3D


func _get_configuration_warnings() -> PackedStringArray:
	var shapes: Dictionary[String, CollisionShape3D] = {
		"ring": ring, "ring_end": ring_end, "push": push, "push_core": push_core,
		"carrier_stop": carrier_stop, "pickup": pickup, "pump_reach": pump_reach}
	var marks: Dictionary[String, Marker3D] = {"ritual_hang": ritual_hang, "carry_hang": carry_hang, "vortex": vortex, "exit": exit}
	return PlaceWarnings.check(shapes, marks)
