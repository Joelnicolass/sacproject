@tool
class_name BodyModel
extends Node3D

## The root of <name>_model.tscn, one per skeletal model (in creatures/<name>/model/, or in
## scenes/bodies/models/ when several bodies wear it): the .glb, the clips it plays and the tree
## that picks one. The scene is made once (tools/bake/new_creature.gd for a
## new model) and edited in the editor from then on:
##   Model       the .glb of assets/original/models/ (or of assets/custom/models/; skeleton, skinned
##   mesh and every clip of the model),
##               drawn with the game's axes (z mirrored, like the baked meshes).
##   Clips       an AnimationPlayer that holds the model's AnimationLibrary
##   (<name>_model_clips.tres): one Animation per ROLE (idle, run,
##               attack...), with the exact length, the markers `hit`/`shoot` where the blow lands
##               or the shot leaves, and the method track that calls ClipEvents.fire(kind) at the
##               frame of each event (sound, foot, strike...).
##   Tree        the AnimationTree whose AnimationNodeStateMachine has one state PER ROLE. A state
##   plays the Animation of its own
##               name: change which Animation a role plays in the library, or point the state at
##               another one.
##   ClipEvents  receives the method tracks of the Animations.
##   Skeleton3D/HandL, HandR...  where the hands are: a BoneAttachment3D on the hand bone with a
##   Marker3D `Socket` (the casting particles of a
##               wizard go there). A hand shows only in the clips that have it: each clip carries a
##               `visible` track for it and the library's RESET hides it. Move the Socket with the
##               gizmo; delete the node to give the model no hand.
## Open the scene and press play on the Tree (or set `preview_role` here) to see a role move. The
## body draws from it (a BodyRig instances this scene under its ModelSlot); the rules read the same
## library through ClipFacts, and never a pose.

## Roles the state machine of a model scene can have a state for. A new role is a new state in the
## scenes (and here). attack2 and attack3 are the other swings of a creature of your own; walk,
## shoot2, pull, death2, death3, ghost_rise and unghost are roles the rules read (the library has
## them) even when no state draws them.
const ROLES: PackedStringArray = [
	"idle",
	"run",
	"walk",
	"attack",
	"attack2",
	"attack3",
	"shoot",
	"shoot2",
	"cast",
	"hit",
	"death",
	"death2",
	"death3",
	"held",
	"thrash",
	"rise",
	"fly",
	"cower",
	"talk_cower",
	"work",
	"pull",
	"takeoff",
	"land",
	"knock",
	"get_up",
	"fly_damage",
	"gesture",
	"cast_run",
	"hover",
	"fly_death",
	"fall",
	"hit_floor",
	"ghost_rise",
	"unghost"
]
## Roles that end by themselves and hand the body back to idle (the Tree gives them the to-idle
## transition).
const ONE_SHOT_ROLES: PackedStringArray = [
	"attack",
	"attack2",
	"attack3",
	"shoot",
	"shoot2",
	"cast",
	"hit",
	"rise",
	"hit_floor",
	"ghost_rise",
	"unghost"
]
## Roles that play once and stay on their last frame; every other role repeats.
const HOLD_ROLES: PackedStringArray = ["death", "death2", "death3", "fly_death", "fall"]
## The roles whose Animation carries the `hit` marker.
const MELEE_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]
## Frames per second of a glTF animation, which carries none (Godot imports them at 30).
const DEFAULT_FRAMERATE := 30
const PLAYBACK := &"parameters/playback"

## Model tag (eorc, jnwr...), the id that travels on the wire. Filled by the bake; the file is named
## after its creature (trogg_model.tscn), and tools/bake/model_paths.tres says which file holds
## which tag.
@export var model := ""
## Meters added to every side of the skinned mesh's bounding box (it is the rest pose's; arms swing
## outside it).
@export_range(0.0, 4.0, 0.05, "or_greater") var aabb_margin := 0.5
## Role shown in the editor when the scene opens (the preview). Runtime owners pick the role with
## BodyRig.play().
@export var preview_role := "idle":
	set(value):
		preview_role = value
		if Engine.is_editor_hint() and is_node_ready():
			preview(value)

## Where the sprite effect a creature carries floats (the Manahoar's mana flame): a node that
## follows a bone of the skeleton, placed in this scene so the editor moves it with a gizmo. Empty:
## the model carries none (CreatureFx then uses its fallback offset).
@export var carried_fx_socket: Node3D
## Where the tool a body works with sits (the Sac Doctor's needle tip, `Needle/Tip` under the
## skeleton): a Marker3D that follows a bone of the skeleton, placed in this scene so the editor
## moves it with a gizmo. Its +Z is the direction the tool points. Empty: the model has none.
@export var tool_socket: Node3D

@export_group("Baked from the original")
## Bounding box of the rest pose (from the exporter index at bake time).
@export var bind_aabb := AABB()

@export_group("Ragdoll")
## The physical skeleton the body falls and hangs with (the `Ragdoll` simulator under the
## Skeleton3D, written by tools/bake/bake_ragdolls.gd).
## Empty: the model never falls as a rag doll (it plays its death clip or tips over).
@export var ragdoll: PhysicalBoneSimulator3D
## The physical bone a hanging body dangles from: a child of `ragdoll`. Empty: the model never hangs
## (a captive plays its clips).
@export var hang_bone: PhysicalBone3D

@onready var _model: Node3D = %Model
@onready var _tree: AnimationTree = %Tree
@onready var _clips: AnimationPlayer = %Clips


func _ready() -> void:
	_fit_bounds()
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


## The physical skeleton of the model, null without one.
## WORKAROUND: a scene that does not assign `ragdoll` yet (the models are rewritten by the bake)
## falls back to the `Ragdoll` child of the skeleton.
func ragdoll_simulator() -> PhysicalBoneSimulator3D:
	if ragdoll != null:
		return ragdoll
	var skin := skeleton()
	return (
		skin.find_child("Ragdoll", false, false) as PhysicalBoneSimulator3D
		if skin != null
		else null
	)


## The state machine of the Tree.
func machine() -> AnimationNodeStateMachine:
	return _tree.tree_root as AnimationNodeStateMachine if _tree != null else null


## The Animation (key of the library) the state of `role` plays; empty when the model has no state
## for it.
func animation_for(role: String) -> StringName:
	var states := machine()
	if states == null or not states.has_node(role):
		return &""
	var state := states.get_node(role) as AnimationNodeAnimation
	return state.animation if state != null else &""


## The clip tag of the .glb (HUa1...) behind `role`: the name stored in its Animation. "" when the
## model has no state for it.
func tag_for(role: String) -> String:
	var wanted := animation_for(role)
	return (
		_clips.get_animation(wanted).resource_name
		if not wanted.is_empty() and _clips.has_animation(wanted)
		else ""
	)


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


## Frames and frames per second of the Animation `role` plays (0 / 30 without one), read from the
## library.
func frames_of(role: String) -> int:
	return ClipFacts.of(library()).frames(animation_for(role))


func framerate_of(role: String) -> float:
	return float(ClipFacts.of(library()).fps(animation_for(role)))


## The frame of the first `hit` marker of the Animation `role` plays (where the strike lands), -1
## without one.
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


## Puts a fixed box with margin on the meshes (the skinned mesh's box is the rest pose's: it would
## be culled mid-swing).
## Not saved: the .glb is an instance. The materials are saved in this scene
## (surface_material_override on the meshes).
func _fit_bounds() -> void:
	if bind_aabb.size == Vector3.ZERO:
		return
	var box := bind_aabb.grow(aabb_margin)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.custom_aabb = box


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if model.is_empty():
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"`model` is empty: the scene is made with tools/bake/new_creature.gd (Project > Tools > Sacrifice)."
			)
		)
	if hang_bone != null and ragdoll == null:
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"`hang_bone` is set but `ragdoll` is missing: the body cannot hang without the physical skeleton."
			)
		)
	elif hang_bone != null and hang_bone.get_parent() != ragdoll:
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"`hang_bone` must be a direct child of `ragdoll` (a PhysicalBone3D of the same simulator)."
			)
		)
	if ragdoll != null and ragdoll.get_child_count() == 0:
		warnings.append(
			"`ragdoll` has no PhysicalBone3D: bake them with tools/bake/bake_ragdolls.gd."
		)
	var player := get_node_or_null("%Clips") as AnimationPlayer
	if player == null or not player.has_animation(&"idle"):
		(
			warnings
			. append(
				# gdlint: ignore=max-line-length
				"Missing the `Clips` node with the <model>_clips.tres library (idle role included): the body has nothing to play."
			)
		)
		return warnings
	for role in MELEE_ROLES:
		var wanted := animation_for(role)
		if (
			player.has_animation(wanted)
			and not player.get_animation(wanted).has_marker(ClipFacts.HIT)
		):
			(
				warnings
				. append(
					(
						# gdlint: ignore=max-line-length
						"The role `%s` has no `hit` marker in its Animation: the blow would land on the last frame."
						% role
					)
				)
			)
	return warnings
