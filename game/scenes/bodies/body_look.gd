@tool
class_name BodyLook
extends Node3D

## The appearance of one creature or wizard: the model it is drawn with, what it sounds like and the
## effect it carries. It is the root of `<name>_look.tscn` (next to the body scene `<name>.tscn`),
## the scene behind the `Look` placeholder of the body. Only a client builds it (BodyMount), so the
## server and the room server never load a model or a sound. The model is an instance of
## <model>_model.tscn; the root transform is the pose that stands it on the ground (a
## flier that lifts itself, a model that sits low). A hybrid that no clip animates has no model: it
## carries `static_mesh` and the body draws that.
## What it does not do: size or place the body (BodyFrame), choose which look a body wears
## (BodyMount), play a clip (BodyRig).

## The skeletal model (an instance of a <model>_model.tscn). Empty for a hybrid, which
## draws `static_mesh`.
@export var model: BodyModel
## The mesh of a body that no clip animates (scenes/bodies/meshes/<name>.res, with its materials).
## Empty when `model` is set.
@export var static_mesh: Mesh
## What the creature sounds like: voice, swing, hurt and death (creatures/<name>/<name>_sounds.tres,
## or wizards/<name>/). Empty: silent, but the summon sound of every creature (UnitSounds) still
## plays.
@export var sounds: SoundSet
## A scene the creature carries (CreatureFx adds it, tinted with the side's mana color): the
## Manahoar's mana flame. Empty: none.
@export var carried_fx: PackedScene
## How the body bleeds (scenes/fx/effects/blood/). Empty: the `fallback` of its BloodFx, red like
## every other body.
@export var blood: BloodType


## The editor always shows meshes; a headless run (the dedicated server) never loads them.
static func loads_meshes() -> bool:
	return Engine.is_editor_hint() or DisplayServer.get_name() != "headless"


## True when a skeleton draws this look.
func has_model() -> bool:
	return model != null


## The look scene that goes with the body scene `body`: the `<name>_look.tscn` next to it (loaded
## now, so a client or a tool only; the server never calls it and never instances the body scene).
## Null for no body or no look.
static func of_body(body: PackedScene) -> PackedScene:
	var path := path_of_body(body)
	return load(path) as PackedScene if not path.is_empty() else null


## Where the look of the body scene `body` is saved (nothing is loaded): "" for no body or no look.
## The warm-up reads them all at once.
static func path_of_body(body: PackedScene) -> String:
	if body == null or body.resource_path.is_empty():
		return ""
	var path := body.resource_path.trim_suffix(".tscn") + "_look.tscn"
	return path if ResourceLoader.exists(path) else ""


## The set of sounds of the look `scene` (a `<name>_look.tscn`) without building it: read from the
## saved root. Null when it has none. For tools and cases; a game reads `BodyMount.look.sounds`.
static func sounds_in(scene: PackedScene) -> SoundSet:
	return _root_value(scene, &"sounds") as SoundSet


static func _root_value(scene: PackedScene, property: StringName) -> Variant:
	if scene == null:
		return null
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == property:
			return state.get_node_property_value(0, i)
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model == null and static_mesh == null:
		warnings.append(
			"Missing `model` (the model scene) or `static_mesh`: this body is not drawn."
		)
	return warnings
