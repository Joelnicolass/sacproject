@tool
class_name ClipPosePlayer
extends Node

## Plays real SXSK clips as per-frame meshes exported by sacengine, baked to .res by tools/bake_clips.gd (027h).
## An unbaked frame is built from its OBJ; falls back to the static baked mesh if cache or clip is missing.

## The active clip went past its last frame and started again (RFC-028c). Emitted on the physics tick that wraps,
## on every peer (the clip clock runs without meshes too); the body picks the next variant from it.
signal clip_looped(role: String)

const _OBJ := preload("res://scenes/world/obj_mesh.gd")

## One mesh per clip frame OBJ, shared by every body that plays it. Meshes are read-only here.
static var _mesh_cache: Dictionary = {}
## "model/tag" pairs already queued for the warm-up (RFC-027b, clients only).
static var _warm_tags: Dictionary = {}
## Frame OBJ paths waiting to be built, oldest first. Drained a few per frame by whichever player runs first.
static var _warm_queue: PackedStringArray = []
static var _warm_head := 0
## Process frame that already spent its warm-up budget (all players share one budget per frame).
static var _warm_frame := -1
## Longest single-frame warm-up in microseconds; only logged (`--clip-warm-log`).
static var _warm_max_us := 0
## -1 unknown, 0 off, 1 on: the `--clip-warm-log` user argument prints each warm-up frame.
static var _warm_log := -1

@export var mesh_path: NodePath
@export var cache_path := "res://cache/data/anim_mesh_clips_f37.json"
## Frames per role queued for building the first time a MODEL is set up (RFC-027b): the queue is shared, so the
## first body of a model decides for all of them. 1 removes the frame-0 hitch of a role change (the first order
## of 150); 0 turns the warm-up off.
@export_range(0, 8) var warm_frames_per_role := 1
## Time per frame for the warm-up queue. A baked frame loads in ~1 ms; an unbaked OBJ costs ~9–12 ms. At least one
## is built per frame, so a frame never pays more than one over the budget.
@export_range(0.0, 16.0, 0.5) var warm_budget_ms := 4.0

## F137 (RFC-030i-b): the pose holds (sacengine petrified, bone.d / state.d:11631-11640): the clock stops, play() does not
## switch the clip and the frame on the mesh stays. Set by its owner (Petrified) on every peer; off resumes from it.
var frozen := false

var _cache: Dictionary = {}
var _cache_loaded := false
var _model := ""
var _roles: Dictionary = {}
var _active_role := ""
var _active_clip: Dictionary = {}
var _active_frames: Array[String] = []
var _frame := 0
var _tick_left := 0.0
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _base_mesh: Mesh
var _warned_missing_mesh := false
## What `_apply_frame_mesh` last put on the mesh: skip the write while nothing changed.
var _shown_idx := -1
var _shown_role := ""
var _shown_mesh: Mesh

@onready var _mesh: MeshInstance3D


func _ready() -> void:
	# `_process` only drains the warm-up queue; `_warm_model` turns it on when it queues something.
	set_process(false)
	if Engine.is_editor_hint():
		# No clips in the editor: advance() would put back an empty base mesh every tick.
		set_physics_process(false)
		_bind_mesh()
		update_configuration_warnings()
		return
	set_physics_process(true)
	_bind_mesh()
	if _mesh:
		_base_pos = _mesh.position
		_base_rot = _mesh.rotation
		_base_mesh = _mesh.mesh
	_load_cache()
	_apply_role("", true)


## The player owns its clock: one advance per physics tick. Bodies only pick the role with play(); they must not call
## advance() too (until RFC-028c units and wizards did, and every creature clip ran at twice its framerate).
func _physics_process(delta: float) -> void:
	advance(delta)


## Presentation only: builds queued clip meshes within `warm_budget_ms`. The clip clock never reads them.
func _process(_delta: float) -> void:
	if _warm_head >= _warm_queue.size():
		set_process(false)
		return
	var frame := Engine.get_process_frames()
	if frame == _warm_frame:
		return
	_warm_frame = frame
	var started := Time.get_ticks_usec()
	var budget_us := int(warm_budget_ms * 1000.0)
	var built := 0
	while _warm_head < _warm_queue.size():
		var path := _warm_queue[_warm_head]
		_warm_head += 1
		if _mesh_cache.has(path):
			continue
		_frame_mesh(path)
		built += 1
		if Time.get_ticks_usec() - started >= budget_us:
			break
	if _warm_head >= _warm_queue.size():
		_warm_queue = PackedStringArray()
		_warm_head = 0
	if built == 0 or not _warm_logging():
		return
	var spent := Time.get_ticks_usec() - started
	_warm_max_us = maxi(_warm_max_us, spent)
	print("ClipPosePlayer: precalentado %d mallas %.1f ms (max %.1f ms, cola %d)" % [
		built, spent / 1000.0, _warm_max_us / 1000.0, _warm_queue.size() - _warm_head])


func setup(model: String, role_to_tag: Dictionary, mesh_base_pos: Vector3, mesh_base_rot: Vector3) -> void:
	_bind_mesh()
	_model = model
	_roles = role_to_tag.duplicate()
	_base_pos = mesh_base_pos
	_base_rot = mesh_base_rot
	_warm_model()
	var preferred := _active_role
	if preferred.is_empty() and _roles.has("idle"):
		preferred = "idle"
	elif preferred.is_empty() and _roles.has("run"):
		preferred = "run"
	_apply_role(preferred, true)


func play(role: String, restart := false) -> void:
	if frozen:
		return
	_apply_role(role, restart)


func active_role() -> String:
	return _active_role


## True when this model has a playable clip (more than one frame) for `role` in the cache.
func has_role(role: String) -> bool:
	return not _clip_for_role(role).is_empty()


## True when `model` has a playable clip (more than one frame) called `tag` in the cache, whatever the roles.
func has_clip(model: String, tag: String) -> bool:
	_load_cache()
	var clip: Dictionary = _cache.get(model, {}).get(tag, {})
	return int(clip.get("frames", 0)) > 1 and not (clip.get("frame_objs", []) as Array).is_empty()


func active_tag() -> String:
	return str(_active_clip.get("tag", ""))


func active_framerate() -> int:
	return int(_active_clip.get("framerate", 0))


func active_frame() -> int:
	return _frame


func impact_frame() -> int:
	var impact: Array = _active_clip.get("impact_frames", [])
	if impact.is_empty():
		return -1
	return int(impact[0])


func advance(delta: float) -> void:
	_bind_mesh()
	if _mesh == null or frozen:
		return
	if _active_clip.is_empty() or _active_frames.is_empty():
		_restore_base()
		return
	var fps := maxf(float(_active_clip.get("framerate", 0)), 1.0)
	var frame_time := 1.0 / fps
	var count := _active_frames.size()
	var looped := false
	_tick_left -= delta
	while _tick_left <= 0.0:
		_tick_left += frame_time
		_frame = (_frame + 1) % count
		looped = looped or _frame == 0
	_apply_frame_mesh()
	if looped:
		# After the frame is shown: a listener may switch the role, which shows its own frame 0.
		clip_looped.emit(_active_role)


func _apply_role(role: String, restart: bool) -> void:
	var wanted := role
	var clip := _clip_for_role(wanted)
	if clip.is_empty():
		wanted = ""
	if not restart and wanted == _active_role:
		return
	_active_role = wanted
	_active_clip = clip
	_active_frames = []
	for path: Variant in _active_clip.get("frame_objs", []):
		_active_frames.append(str(path))
	_frame = 0
	_tick_left = 0.0
	_shown_idx = -1
	if _active_clip.is_empty() or _active_frames.is_empty():
		_restore_base()
	else:
		_apply_frame_mesh()


func _clip_for_role(role: String) -> Dictionary:
	if _model.is_empty() or role.is_empty():
		return {}
	var by_model: Dictionary = _cache.get(_model, {})
	var tag := str(_roles.get(role, ""))
	if tag.is_empty():
		return {}
	var clip: Dictionary = by_model.get(tag, {})
	if int(clip.get("frames", 0)) <= 1:
		return {}
	var frames: Array = clip.get("frame_objs", [])
	return clip if not frames.is_empty() else {}


func _apply_frame_mesh() -> void:
	if _mesh == null or _active_frames.is_empty():
		return
	if not BodyCatalog.loads_meshes():
		# The dedicated server runs the clip clock (frames, impact) but never builds meshes.
		return
	var idx := clampi(_frame, 0, _active_frames.size() - 1)
	if idx == _shown_idx and _active_role == _shown_role and _shown_mesh != null \
			and _mesh.mesh == _shown_mesh and _mesh.position == _base_pos and _mesh.rotation == _base_rot:
		return
	var obj_path := String(_active_frames[idx])
	var built := _frame_mesh(obj_path)
	if built == null:
		_restore_base()
		return
	_mesh.position = _base_pos
	_mesh.rotation = _base_rot
	_mesh.mesh = built
	_shown_idx = idx
	_shown_role = _active_role
	_shown_mesh = built


## RFC-027b: queues the first `warm_frames_per_role` frames of every role of this model, once per model and
## clip; `_process` builds them within `warm_budget_ms` per frame. A role change starts at frame 0 on every body
## of the model at once (the first order of 150), so frame 0 is the one that hitched. A frame not built yet when
## it is shown is built right there, as before. Clients only; the dedicated server never builds meshes.
func _warm_model() -> void:
	if warm_frames_per_role <= 0 or Engine.is_editor_hint() or not BodyCatalog.loads_meshes() or _model.is_empty():
		return
	var by_model: Dictionary = _cache.get(_model, {})
	if by_model.is_empty():
		return
	var queued := false
	for role: Variant in _roles.keys():
		var tag := str(_roles[role])
		var key := "%s/%s" % [_model, tag]
		if tag.is_empty() or _warm_tags.has(key):
			continue
		_warm_tags[key] = true
		var clip: Dictionary = by_model.get(tag, {})
		var frames: Array = clip.get("frame_objs", [])
		for i in mini(warm_frames_per_role, frames.size()):
			_warm_queue.append(str(frames[i]))
			queued = true
	if queued:
		set_process(true)


static func _warm_logging() -> bool:
	if _warm_log < 0:
		_warm_log = 1 if OS.get_cmdline_user_args().has("--clip-warm-log") else 0
	return _warm_log == 1


func _frame_mesh(path: String) -> Mesh:
	if path.is_empty():
		return null
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var started := Time.get_ticks_usec()
	var built := _baked_frame(path)
	var source := "horneado"
	if built == null:
		built = _OBJ.build(path, {_OBJ.MIRROR_Z: true})
		source = "obj"
	_mesh_cache[path] = built
	if _warm_logging():
		print("ClipPosePlayer: cuadro %s %s %.1f ms" % [path.trim_prefix(BodyCatalog.LOOK_DIR), source, (Time.get_ticks_usec() - started) / 1000.0])
	return built


## RFC-027 027h: the frame's geometry baked by tools/bake_clips.gd, read with ResourceLoader (~1 ms instead of
## 10–15 ms of OBJ parsing). The bake saves no materials (they would embed one texture copy per frame): each surface
## is named after its OBJ label and gets the same shared OriginalMaterial that build() would put. Null when the
## frame is not baked, or the OBJ is newer than its bake: then the caller builds the OBJ as before.
static func _baked_frame(obj_path: String) -> ArrayMesh:
	var baked := BodyCatalog.clip_frame_path(obj_path)
	if baked.is_empty() or not ResourceLoader.exists(baked):
		return null
	# A frame whose OBJ is gone falls back like an unbuildable OBJ (base mesh), not to orphan geometry.
	if not FileAccess.file_exists(obj_path):
		return null
	# Baked frames are invalidated by OBJ mtime only: changing obj_mesh.gd needs `bake_clips.gd -- --force`.
	if FileAccess.get_modified_time(obj_path) > FileAccess.get_modified_time(baked):
		return null
	var mesh := ResourceLoader.load(baked) as ArrayMesh
	if mesh == null:
		return null
	var model := OriginalMaterial.model_of(obj_path)
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, OriginalMaterial.for_label(model, mesh.surface_get_name(i)))
	return mesh


func _restore_base() -> void:
	_shown_idx = -1
	if _mesh == null:
		return
	_mesh.position = _base_pos
	_mesh.rotation = _base_rot
	_mesh.mesh = _base_mesh


func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	if not FileAccess.file_exists(cache_path):
		return
	var raw := FileAccess.get_file_as_string(cache_path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_cache = parsed


func _bind_mesh() -> void:
	if _mesh and is_instance_valid(_mesh):
		return
	if not mesh_path.is_empty():
		_mesh = get_node_or_null(mesh_path) as MeshInstance3D
	if _mesh == null:
		_mesh = get_node_or_null("../Mesh") as MeshInstance3D
	if _mesh == null:
		_mesh = get_node_or_null("../Visual") as MeshInstance3D
	if _mesh == null:
		_mesh = get_node_or_null("../Tilt/Mesh") as MeshInstance3D
	if _mesh == null and not _warned_missing_mesh:
		_warned_missing_mesh = true
		push_warning("ClipPosePlayer could not bind mesh_path. Assign mesh_path in the inspector.")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if mesh_path.is_empty():
		warnings.append("Assign mesh_path to the MeshInstance3D used by this clip player.")
		return warnings
	var node := get_node_or_null(mesh_path)
	if node == null:
		warnings.append("mesh_path does not resolve in this scene instance.")
	elif not node is MeshInstance3D:
		warnings.append("mesh_path must point to a MeshInstance3D.")
	return warnings
