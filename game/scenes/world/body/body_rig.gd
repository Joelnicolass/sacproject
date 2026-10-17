@tool
class_name BodyRig
extends Node3D

## RFC-023 (023b): a skeletal body of the original game. Loads assets/original/models/<model>.glb (Skeleton3D, one
## skinned mesh, every clip of the model), puts the shared OriginalMaterial on it and plays ROLES (idle, run, attack...)
## through the AnimationTree of this scene. Which clip plays a role is a BodyClips resource.
## Nothing derived is saved in the .tscn: the model under %ModelSlot and the "role" animation library of %Anim are made
## at run time (owner = null). Without the asset the rig shows nothing and warns in the inspector; no error.
## On the dedicated server (headless) nothing loads: the rig is inert (the clip clock runs without meshes, RFC-023 3.4).
## Presentation only: the simulation never reads the rig.

## The AnimationPlayer library the state machine's animation nodes point at ("role/idle"...).
const LIBRARY := &"role"
const MODEL_NODE := "Model"
## Path from the Model node to %ClipEvents, the target of the method tracks of every clip.
const EVENTS_PATH := "../../ClipEvents"
## The exporter writes the OBJ axes of sacengine; the game draws them with z mirrored (ObjMesh.MIRROR_Z).
const MIRROR := Vector3(1.0, 1.0, -1.0)

## "model|tag|stepped|looping" -> Animation. One copy per variant, shared by every rig of that model.
static var _variants: Dictionary = {}
static var _index: Dictionary = {}
static var _index_loaded := false

## Body to show (index.json key: eorc, jnwr...). The owner sets it at run time; in the editor it is the preview.
@export var model := "":
	set(value):
		model = value
		_reload_if_ready()
## Role -> clip tag for this model. Without it no role plays.
@export var clips: BodyClips:
	set(value):
		clips = value
		_reload_if_ready()
## Role shown after loading (the editor preview and the starting role).
@export var preview_role := "idle":
	set(value):
		preview_role = value
		if is_node_ready() and _model_root != null:
			play(value)
## false: smooth, linear between the frames of the clip (more fluid than the original). true: the original's
## frame by frame look (nearest key), to compare against the baked frames.
@export var stepped := false:
	set(value):
		stepped = value
		_reload_if_ready()
## Meters added to every side of the skinned mesh's bounding box (it is the rest pose's; arms swing outside it).
@export_range(0.0, 4.0, 0.05, "or_greater") var aabb_margin := 0.5
## Draws the model with the game's axes (z mirrored, like the baked meshes). Off only to inspect the raw export.
@export var mirror_z := true:
	set(value):
		mirror_z = value
		_reload_if_ready()

var _model_root: Node3D
var _skeleton: Skeleton3D
## tag -> Animation of the .glb, as imported. Never edited: variants are copies.
var _source: Dictionary = {}
var _role := ""
var _missing := false
var _batching := false

@onready var _slot: Node3D = %ModelSlot
@onready var _anim: AnimationPlayer = %Anim
@onready var _tree: AnimationTree = %Tree
@onready var _hand_l: BoneAttachment3D = %HandL
@onready var _hand_r: BoneAttachment3D = %HandR
@onready var _events: ClipEvents = %ClipEvents


func _ready() -> void:
	if not BodyCatalog.loads_meshes():
		_tree.active = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_reload()


## Measurements and clips of `model_tag` from models/index.json ({} for an unknown model).
static func model_info(model_tag: String) -> Dictionary:
	if not _index_loaded:
		_index_loaded = true
		var path := OriginalAssets.models_index()
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_index = parsed
	return _index.get(model_tag, {})


## One clip of the model: frames, framerate, events, hands ({} when the model has no such tag).
static func clip_info(model_tag: String, tag: String) -> Dictionary:
	return (model_info(model_tag).get("clips", {}) as Dictionary).get(tag, {})


## True when `role` has a clip in the loaded model.
func has_role(role: String) -> bool:
	return clips != null and _source.has(clips.tag_for(role))


## The role that will play for `role`: itself, or idle when the model has no clip for it (like the baked player did).
func resolve_role(role: String) -> String:
	return role if has_role(role) else "idle"


func active_role() -> String:
	return _role


## Clip tag, frame count and framerate of a role of the loaded model.
func role_tag(role: String) -> String:
	return clips.tag_for(resolve_role(role)) if clips else ""


func role_frames(role: String) -> int:
	return int(clip_info(model, role_tag(role)).get("frames", 0))


func role_framerate(role: String) -> float:
	return float(clip_info(model, role_tag(role)).get("framerate", 30))


func skeleton() -> Skeleton3D:
	return _skeleton


func is_loaded() -> bool:
	return _model_root != null


## Plays `role` through the state machine (travel: it blends with xfade). `restart` starts it again from frame 0.
func play(role: String, restart := false) -> void:
	if _model_root == null:
		return
	var wanted := resolve_role(role)
	if wanted == _role and not restart and _tree.active:
		return
	var first := _role.is_empty() or not _tree.active
	_stop_player()
	_tree.active = true
	var playback := _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		return
	if restart or first:
		playback.start(wanted, true)
	else:
		playback.travel(wanted)
	_role = wanted
	_apply_hands(wanted)


## Holds the body at `seconds` of `role`'s clip, outside the state machine (comparisons and captures). The skeleton
## starts from its rest pose first: the glTF importer drops constant tracks equal to the rest, so a bone the clip
## does not animate would keep the previous clip's pose.
func pose_at(role: String, seconds: float) -> void:
	if _model_root == null:
		return
	var wanted := resolve_role(role)
	_tree.active = false
	_stop_player()
	_skeleton.reset_bone_poses()
	_anim.play("%s/%s" % [LIBRARY, wanted])
	_anim.seek(seconds, true)
	_anim.pause()
	_role = wanted
	_apply_hands(wanted)


## Steps the state machine by hand (tests and, later, a body-LOD that updates far bodies less often).
func advance(delta: float) -> void:
	if _model_root != null and _tree.active:
		_tree.advance(delta)


## Sets the model and its aliases together and loads once (two property writes would load a mismatched pair).
func set_body(model_tag: String, aliases: BodyClips) -> void:
	_batching = true
	model = model_tag
	clips = aliases
	_batching = false
	_reload_if_ready()


## Stops %Anim only when the clip it holds still exists: stop() seeks it, and a library of another model has no such clip.
func _stop_player() -> void:
	if _anim.has_animation(_anim.assigned_animation):
		_anim.stop()


func _reload_if_ready() -> void:
	if not _batching and is_node_ready() and BodyCatalog.loads_meshes():
		_reload()


func _reload() -> void:
	_clear()
	_missing = false
	if model.is_empty():
		update_configuration_warnings()
		return
	var info := model_info(model)
	var path := OriginalAssets.model(model)
	if info.is_empty() or not ResourceLoader.exists(path):
		_missing = true
		update_configuration_warnings()
		if not Engine.is_editor_hint():
			push_warning("BodyRig: missing asset %s; run tools/export_skeletal.py" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		_missing = true
		update_configuration_warnings()
		return
	var root := packed.instantiate() as Node3D
	root.name = MODEL_NODE
	_take_animations(root)
	OriginalMaterial.apply_to(root, model)
	root.scale = MIRROR if mirror_z else Vector3.ONE
	_slot.add_child(root)
	_model_root = root
	_skeleton = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_fit_bounds(root, info)
	_anim.root_node = _anim.get_path_to(root)
	_tree.root_node = _tree.get_path_to(root)
	_bind_hands()
	_build_library()
	update_configuration_warnings()
	play(preview_role, true)


## Moves the .glb's own AnimationPlayer's clips into `_source` and frees it: %Anim is the player of the rig.
func _take_animations(root: Node) -> void:
	for player: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
		for clip_name: StringName in player.get_animation_list():
			_source[str(clip_name)] = player.get_animation(clip_name)
		player.get_parent().remove_child(player)
		player.free()


func _clear() -> void:
	_tree.active = false
	_stop_player()
	if _anim.has_animation_library(LIBRARY):
		_anim.remove_animation_library(LIBRARY)
	for child in _slot.get_children():
		_slot.remove_child(child)
		child.free()
	_model_root = null
	_skeleton = null
	_source = {}
	_role = ""


## The skinned mesh's box is the rest pose's: a fixed box with margin keeps it from being culled mid-swing.
func _fit_bounds(root: Node, info: Dictionary) -> void:
	var box: Dictionary = info.get("bind_aabb", {})
	if box.is_empty():
		return
	var low: Array = box["min"]
	var high: Array = box["max"]
	var start := Vector3(low[0], low[1], low[2]) - Vector3.ONE * aabb_margin
	var end := Vector3(high[0], high[1], high[2]) + Vector3.ONE * aabb_margin
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.custom_aabb = AABB(start, end - start)


## The "role" library: one Animation per role this model's BodyClips names. Variants (looping, stepped, events) are
## copies cached per model, so rigs of one model share them and the imported clips stay untouched.
func _build_library() -> void:
	var library := AnimationLibrary.new()
	if clips != null:
		for role in BodyClips.ROLES:
			var tag := clips.tag_for(role)
			if tag.is_empty() or not _source.has(tag):
				continue
			library.add_animation(role, _variant(tag, clips.is_looping(role)))
	_anim.add_animation_library(LIBRARY, library)


func _variant(tag: String, looping: bool) -> Animation:
	var key := "%s|%s|%s|%s" % [model, tag, stepped, looping]
	if _variants.has(key):
		return _variants[key]
	var clip := clip_info(model, tag)
	var fps := maxf(float(clip.get("framerate", 30)), 1.0)
	var frames := int(clip.get("frames", 1))
	var source := _source[tag] as Animation
	var made := source.duplicate() as Animation
	made.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	if looping:
		# The original shows `frames` frames per cycle and wraps: the last key blends into the first.
		made.length = frames / fps
	if stepped:
		# The import keeps every key (tools/skeletal_post_import.gd): holding the nearest one is the original's frame.
		for track in made.get_track_count():
			made.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	var event_track := -1
	for event: Dictionary in clip.get("events", []):
		if event_track < 0:
			event_track = made.add_track(Animation.TYPE_METHOD)
			made.track_set_path(event_track, NodePath(EVENTS_PATH))
		var at := minf(float(event["frame"]) / fps, made.length)
		made.track_insert_key(event_track, at, {"method": &"fire", "args": [str(event["kind"])]})
	_variants[key] = made
	return made


## The hand attachments follow the skeleton of the instanced model; their bone changes with the clip.
func _bind_hands() -> void:
	for attach in [_hand_l, _hand_r]:
		attach.use_external_skeleton = true
		attach.external_skeleton = attach.get_path_to(_skeleton)
		(attach.get_node("Socket") as Node3D).scale = MIRROR if mirror_z else Vector3.ONE


func _apply_hands(role: String) -> void:
	if _skeleton == null or clips == null:
		return
	var hands: Array = clip_info(model, clips.tag_for(role)).get("hands", [])
	var scaling := float(model_info(model).get("scaling", 1.0))
	var attachments := [_hand_l, _hand_r]
	for i in mini(hands.size(), 2):
		var attach: BoneAttachment3D = attachments[i]
		var hand: Dictionary = hands[i]
		if attach.bone_name != str(hand["bone_name"]):
			attach.bone_name = str(hand["bone_name"])
		var raw: Array = hand["offset_raw"]
		# Same conversion as the exporter's to_obj: (-x, y, z) times the model's scaling.
		(attach.get_node("Socket") as Node3D).position = Vector3(-raw[0], raw[1], raw[2]) * scaling


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _missing:
		warnings.append("Missing asset %s: run tools/export_skeletal.py." % OriginalAssets.model(model))
	if not model.is_empty() and clips == null:
		warnings.append("Assign clips (BodyClips): without role aliases nothing plays.")
	return warnings
