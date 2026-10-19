@tool
class_name BodyModel
extends Node3D

## RFC-036 (036g, F208): the root of scenes/bodies/models/<tag>.tscn, one per skeletal model of the original game.
## The scene is generated once by tools/bake/bake_body_scenes.gd and edited in the editor from then on:
##   Model       the .glb of assets/original/models/ (skeleton, skinned mesh and every clip of the model), drawn with the
##               game's axes (z mirrored, like the baked meshes).
##   Tree        the AnimationTree whose AnimationNodeStateMachine has one state PER ROLE (idle, run, attack...). Each
##               state plays the clip (tag) of the .glb that role uses: this is the role -> animation mapping. Change a
##               state's animation in the editor to change which clip a role plays.
##   Events      an AnimationPlayer with one small animation per clip tag that has SKEL events: a method track calls
##               ClipEvents.fire(kind) at the frame of each event (the "attack" key is the visual impact moment).
## Open the scene and press play on the Tree (or set `preview_role` here) to see a role move.
## Presentation only: the simulation never reads it. A BodyRig instances this scene under its ModelSlot.

## Roles the state machine of a model scene can have a state for. A new role is a new state in the scenes (and here).
const ROLES: PackedStringArray = ["idle", "run", "attack", "shoot", "cast", "hit", "death", "held", "thrash", "rise", "fly",
	"cower", "talk_cower", "work", "takeoff", "land", "knock", "get_up", "fly_damage", "gesture", "cast_run", "hover", "fly_death"]
## Roles that end by themselves and hand the body back to idle (the bake gives them the to-idle transition).
const ONE_SHOT_ROLES: PackedStringArray = ["attack", "shoot", "cast", "hit", "rise"]
## Roles that play once and stay on their last frame; every other role repeats.
const HOLD_ROLES: PackedStringArray = ["death", "fly_death"]
const SCENE_DIR := "res://scenes/bodies/models/"
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
@onready var _events: AnimationPlayer = %Events


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


## The AnimationPlayer inside the .glb: it holds every clip of the model, by tag.
func clip_player() -> AnimationPlayer:
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null


func events_player() -> AnimationPlayer:
	return _events


## The state machine of the Tree.
func machine() -> AnimationNodeStateMachine:
	return _tree.tree_root as AnimationNodeStateMachine


## The clip tag `role` plays ("" when the model has no state for it).
func tag_for(role: String) -> String:
	var states := machine()
	if states == null or not states.has_node(role):
		return ""
	var state := states.get_node(role) as AnimationNodeAnimation
	return String(state.animation) if state != null else ""


## True when the model has a playable clip for `role`.
func has_role(role: String) -> bool:
	var tag := tag_for(role)
	var player := clip_player()
	return not tag.is_empty() and player != null and player.has_animation(tag)


## Roles that have a state in this scene, in ROLES order.
func roles() -> PackedStringArray:
	var out := PackedStringArray()
	for role in ROLES:
		if has_role(role):
			out.append(role)
	return out


func clip_data(tag: String) -> Dictionary:
	return clips.get(tag, {})


func frames_of(tag: String) -> int:
	return int(clip_data(tag).get("frames", 0))


func framerate_of(tag: String) -> float:
	return float(clip_data(tag).get("framerate", 30))


## The frame of the first "attack" event of clip `tag` (where the strike lands), -1 without one. Read from the method track
## of the Events animation.
func impact_frame(tag: String) -> int:
	if _events == null or not _events.has_animation(tag):
		return -1
	var animation := _events.get_animation(tag)
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in animation.track_get_key_count(track):
			var call: Dictionary = animation.track_get_key_value(track, key)
			if (call.get("args", []) as Array).has("attack"):
				return mini(roundi(animation.track_get_key_time(track, key) * framerate_of(tag)), frames_of(tag) - 1)
	return -1


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
		warnings.append("`model` is empty: regenerate the scene with tools/bake/bake_body_scenes.gd.")
	return warnings
