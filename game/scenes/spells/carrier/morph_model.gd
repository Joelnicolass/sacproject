@tool
class_name MorphModel
extends Node3D

## Plays the animations of a model whose frames are blend shapes (the cow, Death, Blind Rage's fist: tools/import/import_morph_models.py): each
## MorphClip names the poses to go through and how long each lasts, and the weights of the shapes blend one into the next. It follows its
## SpellCarrier: `phase_clips` says which clip each phase plays (a finished clip goes on to its `next`). It moves nothing and hurts nobody;
## every peer plays its own from the replicated phase, and a headless process plays none.

@export var carrier: SpellCarrier
## The mesh that has the blend shapes (the glb's own MeshInstance3D); empty: the first one found below this node.
@export var mesh: MeshInstance3D
@export var clips: Array[MorphClip] = []
## The clip each SpellCarrier.Phase plays (the key is the phase as an integer).
@export var phase_clips: Dictionary[int, StringName] = {}
## The clip it starts with (before any phase says otherwise).
@export var start_clip: StringName = &""

var _clip: MorphClip
var _seconds := 0.0
var _set := PackedInt32Array()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if not clips.is_empty() else PackedStringArray(["The clips are missing."])


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	if mesh == null:
		mesh = _first_mesh(self)
	if carrier != null:
		carrier.phase_changed.connect(_on_phase)
	play(phase_clips.get(carrier.phase, start_clip) if carrier != null else start_clip)
	set_process(true)


## The clip called `id` from its first pose (nothing if there is none).
func play(id: StringName) -> void:
	_clip = null
	for clip in clips:
		if clip != null and clip.id == id:
			_clip = clip
	_seconds = 0.0
	if _clip != null:
		_show()


func current() -> StringName:
	return _clip.id if _clip != null else &""


func _on_phase(now: SpellCarrier.Phase) -> void:
	if phase_clips.has(now) and phase_clips[now] != current():
		play(phase_clips[now])


func _process(delta: float) -> void:
	if _clip == null:
		return
	_seconds += delta
	if not _clip.loop and _seconds >= _clip.duration_s() and _clip.next != &"":
		play(_clip.next)
		return
	_show()


## The weights for the instant `_seconds` of the clip.
func _show() -> void:
	if mesh == null:
		return
	var at := _clip.at(_seconds)
	for index in _set:
		mesh.set_blend_shape_value(index, 0.0)
	_set.clear()
	_weigh(int(at[0]), 1.0 - float(at[2]))
	if int(at[1]) != int(at[0]):
		_weigh(int(at[1]), float(at[2]))
	if _clip.reveal.x >= 0.0:
		mesh.set_instance_shader_parameter(&"reveal", lerpf(_clip.reveal.x, _clip.reveal.y, clampf(_seconds / maxf(_clip.duration_s(), 0.001), 0.0, 1.0)))


## Pose 0 is the mesh itself; pose n is the blend shape n - 1.
func _weigh(pose: int, weight: float) -> void:
	if pose > 0 and pose - 1 < mesh.get_blend_shape_count():
		mesh.set_blend_shape_value(pose - 1, weight)
		_set.append(pose - 1)


static func _first_mesh(root: Node) -> MeshInstance3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).get_blend_shape_count() > 0:
			return node as MeshInstance3D
	return null
