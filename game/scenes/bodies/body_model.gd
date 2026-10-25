@tool
class_name BodyModel
extends Node3D

## The root of scenes/bodies/models/<tag>.tscn, one per skeletal model: the .glb, the clips it plays and the tree that picks one.
## The scene is made once (tools/bake/new_creature.gd for a new model) and edited in the editor from then on:
##   Model       the .glb of assets/original/models/ (or of assets/custom/models/; skeleton, skinned mesh and every clip of the model),
##               drawn with the game's axes (z mirrored, like the baked meshes).
##   Clips       an AnimationPlayer that holds the model's AnimationLibrary (<tag>_clips.tres): one Animation per ROLE (idle, run,
##               attack...), with the exact length, the markers `hit`/`shoot` where the blow lands or the shot leaves, and the
##               method track that calls ClipEvents.fire(kind) at the frame of each event (sound, foot, strike...).
##   Tree        the AnimationTree whose AnimationNodeStateMachine has one state PER ROLE. A state plays the Animation of its own
##               name: change which Animation a role plays in the library, or point the state at another one.
##   ClipEvents  receives the method tracks of the Animations.
## Open the scene and press play on the Tree (or set `preview_role` here) to see a role move.
## The body draws from it (a BodyRig instances this scene under its ModelSlot); the rules read the same library through
## ClipFacts, and never a pose.
## Ref: RFC-036 (036g), RFC-055 (055c1).

## Roles the state machine of a model scene can have a state for. A new role is a new state in the scenes (and here).
## attack2 and attack3 are the other swings of a creature of your own; walk, shoot2, pull, death2, death3, ghost_rise and unghost
## are roles the rules read (the library has them) even when no state draws them.
const ROLES: PackedStringArray = ["idle", "run", "walk", "attack", "attack2", "attack3", "shoot", "shoot2", "cast", "hit", "death", "death2",
	"death3", "held", "thrash", "rise", "fly", "cower", "talk_cower", "work", "pull", "takeoff", "land", "knock", "get_up", "fly_damage",
	"gesture", "cast_run", "hover", "fly_death", "fall", "hit_floor", "ghost_rise", "unghost"]
## Roles that end by themselves and hand the body back to idle (the Tree gives them the to-idle transition).
const ONE_SHOT_ROLES: PackedStringArray = ["attack", "attack2", "attack3", "shoot", "shoot2", "cast", "hit", "rise", "hit_floor", "ghost_rise",
	"unghost"]
## Roles that play once and stay on their last frame; every other role repeats.
const HOLD_ROLES: PackedStringArray = ["death", "death2", "death3", "fly_death", "fall"]
const SCENE_DIR := "res://scenes/bodies/models/"
## The roles whose Animation carries the `hit` marker.
const MELEE_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]
## Frames per second of a clip the `clips` table does not list (glTF animations carry none; Godot imports them at 30).
const DEFAULT_FRAMERATE := 30
const PLAYBACK := &"parameters/playback"

## Model tag (eorc, jnwr...). Filled by the bake: BodyCatalog and the rig find the scene by it.
@export var model := ""
## Meters added to every side of the skinned mesh's bounding box (it is the rest pose's; arms swing outside it).
@export_range(0.0, 4.0, 0.05, "or_greater") var aabb_margin := 0.5
## Role shown in the editor when the scene opens (the preview). Runtime owners pick the role with BodyRig.play().
@export var preview_role := "idle":
	set(value):
		preview_role = value
		if Engine.is_editor_hint() and is_node_ready():
			preview(value)

## Where the sprite effect a creature carries floats (the Manahoar's mana flame): a node that follows a bone of the skeleton,
## placed in this scene so the editor moves it with a gizmo. Empty: the model carries none (CreatureFx then uses its fallback offset).
@export var carried_fx_socket: Node3D

@export_group("Baked from the original")
## Bounding box of the rest pose (from the exporter index at bake time).
@export var bind_aabb := AABB()
## The body parts each mesh surface merges; the material of a surface is the one of its first part (OriginalMaterial).
@export var surface_parts: Array = []
## clip tag -> {frames, framerate, hands: [{on, bone_name, offset}, {...}]}. Only the clips a role uses. `hands` are the two
## sockets of the clip (a hand on the root bone is "no hand": sacengine leaves it NaN).
@export var clips: Dictionary = {}

@onready var _model: Node3D = %Model
@onready var _tree: AnimationTree = %Tree
@onready var _clips: AnimationPlayer = %Clips


static func scene_path(model_tag: String) -> String:
	return SCENE_DIR + model_tag + ".tscn"


## True when `model_tag` has a baked scene (a skeletal model with a playable idle clip).
static func exists(model_tag: String) -> bool:
	return not model_tag.is_empty() and ResourceLoader.exists(scene_path(model_tag))


func _ready() -> void:
	_dress()
	if Engine.is_editor_hint():
		preview(preview_role)


func _notification(what: int) -> void:
	# The editor preview moves the skeleton: the saved scene keeps the Tree off.
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_tree.active = false
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		preview(preview_role)


func skeleton() -> Skeleton3D:
	var found := _model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


func tree() -> AnimationTree:
	return _tree


## The AnimationPlayer inside the .glb: it holds every raw clip of the model, by tag.
func clip_player() -> AnimationPlayer:
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


## The player of the model's AnimationLibrary: one Animation per role.
func clips_player() -> AnimationPlayer:
	return _clips


## The library of the model (role -> Animation), the same file the rules read through ClipFacts.
func library() -> AnimationLibrary:
	return _clips.get_animation_library(&"") if _clips != null else null


## The state machine of the Tree.
func machine() -> AnimationNodeStateMachine:
	return _tree.tree_root as AnimationNodeStateMachine if _tree != null else null


## The Animation (key of the library) the state of `role` plays; empty when the model has no state for it.
func animation_for(role: String) -> StringName:
	var states := machine()
	if states == null or not states.has_node(role):
		return &""
	var state := states.get_node(role) as AnimationNodeAnimation
	return state.animation if state != null else &""


## The clip tag of the .glb (HUa1...) behind `role`: the name stored in its Animation. "" when the model has no state for it.
func tag_for(role: String) -> String:
	var wanted := animation_for(role)
	return _clips.get_animation(wanted).resource_name if not wanted.is_empty() and _clips.has_animation(wanted) else ""


## True when the model has a playable clip for `role`.
func has_role(role: String) -> bool:
	var wanted := animation_for(role)
	return not wanted.is_empty() and _clips != null and _clips.has_animation(wanted)


## Roles that have a state in this scene, in ROLES order.
func roles() -> PackedStringArray:
	var out := PackedStringArray()
	for role in ROLES:
		if has_role(role):
			out.append(role)
	return out


## The `hands` (and, for a clip of your own, the frames) of the .glb clip `tag`. A clip the table does not list (the role was
## pointed at another clip of the .glb in the inspector) comes without hands.
func clip_data(tag: String) -> Dictionary:
	if clips.has(tag):
		return clips[tag]
	var player := clip_player()
	if player == null or not player.has_animation(tag):
		return {}
	var animation := player.get_animation(tag)
	var rate := roundi(1.0 / animation.step) if animation.step > 0.0 else DEFAULT_FRAMERATE
	return {"frames": roundi(animation.length * rate), "framerate": rate, "hands": []}


## Frames and frames per second of the Animation `role` plays (0 / 30 without one), read from the library.
func frames_of(role: String) -> int:
	return ClipFacts.of(library()).frames(animation_for(role))


func framerate_of(role: String) -> float:
	return float(ClipFacts.of(library()).fps(animation_for(role)))


## The frame of the first `hit` marker of the Animation `role` plays (where the strike lands), -1 without one.
func impact_frame(role: String) -> int:
	var hits := ClipFacts.of(library()).hits(animation_for(role))
	return mini(hits[0], frames_of(role) - 1) if not hits.is_empty() else -1


## Plays `role` in the editor (the Tree travels to its state).
func preview(role: String) -> void:
	if _tree == null or not has_role(role):
		return
	_tree.active = true
	var playback := _tree.get(PLAYBACK) as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.start(role, true)


## Puts the shared materials on the meshes and a fixed box with margin on them (the skinned mesh's box is the rest pose's: it
## would be culled mid-swing). Not saved: the .glb is an instance.
func _dress() -> void:
	OriginalMaterial.apply_to(_model, model, surface_parts)
	if bind_aabb.size == Vector3.ZERO:
		return
	var box := bind_aabb.grow(aabb_margin)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.custom_aabb = box


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model.is_empty():
		warnings.append("`model` está vacío: la escena se hace con tools/bake/new_creature.gd (Project > Tools > Sacrifice).")
	elif scene_file_path.is_empty() == false and scene_file_path.get_file().get_basename() != model:
		warnings.append("El archivo se llama «%s» pero `model` es «%s»: el juego busca la escena por `model`." % [
			scene_file_path.get_file().get_basename(), model])
	var player := get_node_or_null("%Clips") as AnimationPlayer
	if player == null or not player.has_animation(&"idle"):
		warnings.append("Falta el nodo `Clips` con la biblioteca <modelo>_clips.tres (rol idle incluido): el cuerpo no tiene qué reproducir.")
		return warnings
	for role in MELEE_ROLES:
		var wanted := animation_for(role)
		if player.has_animation(wanted) and not player.get_animation(wanted).has_marker(ClipFacts.HIT):
			warnings.append("El rol `%s` no tiene marcador `hit` en su Animation: el golpe caería en el último cuadro." % role)
	return warnings
