@tool
class_name DedicatedStrip
extends EditorExportPlugin

## What the dedicated server build does not carry: when the export preset is a Godot "Dedicated Server" one, every AudioStream
## goes into the pack as an empty stream of the same class and every body clip (the Animation files of
## scenes/bodies/models/*_clips/) as an Animation with only its length, step, loop mode and markers, no tracks.
## The server never plays a sound and never poses a bone: the rules read the length and the `hit`/`shoot` markers of a clip
## (ClipFacts), and those stay. NOT here: meshes and textures (Godot's own dedicated mode already turns them into placeholders),
## and nothing runs outside an export: the game and the editor never load this class.
## Environment, for measuring only: SAC_DEDICATED_STRIP=0 exports the preset untouched; SAC_PACK_PROBE=1 also puts the memory
## probe (agent/harness/dedicated_mem_probe.gd) in the pack, to run as `--main-pack <pck> res://dedicated_mem_probe/probe.tscn`.

const VERSION := 1
const ENV_OFF := "SAC_DEDICATED_STRIP"
const ENV_PROBE := "SAC_PACK_PROBE"
const CLIP_DIR := "res://scenes/bodies/models/"
const CLIP_FOLDER_SUFFIX := "_clips"
const PROBE_SOURCE := "res://agent/harness/dedicated_mem_probe.gd"
const PROBE_SCRIPT := "res://dedicated_mem_probe/probe.gd"
const PROBE_SCENE := "res://dedicated_mem_probe/probe.tscn"
const PROBE_SCENE_TEXT := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n\n[node name=\"Probe\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"

var _audio := 0
var _animations := 0
var _tracks := 0


## True for the Animation files of a model's clip library (res://scenes/bodies/models/<model>_clips/<role>.res).
static func is_clip_path(path: String) -> bool:
	return path.begins_with(CLIP_DIR) and path.get_base_dir().ends_with(CLIP_FOLDER_SUFFIX) and not path.get_file().is_empty()


## The clip without tracks: same length, step, loop mode and markers (name, time, color), nothing else.
static func stripped_animation(source: Animation) -> Animation:
	var out := Animation.new()
	out.resource_name = source.resource_name
	out.length = source.length
	out.step = source.step
	out.loop_mode = source.loop_mode
	for marker_name: String in source.get_marker_names():
		var marker := StringName(marker_name)
		out.add_marker(marker, source.get_marker_time(marker))
		out.set_marker_color(marker, source.get_marker_color(marker))
	return out


## An empty stream of the same class, so a typed `@export var stream: AudioStreamOggVorbis` still accepts it.
static func stripped_audio(source: AudioStream) -> AudioStream:
	var stream_class := source.get_class()
	var out: AudioStream = null
	if ClassDB.can_instantiate(stream_class):
		out = ClassDB.instantiate(stream_class) as AudioStream
	if out == null:
		out = AudioStreamWAV.new()
	out.resource_name = source.resource_name
	return out


func _get_name() -> String:
	return "DedicatedStrip"


func _begin_customize_resources(_platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	_audio = 0
	_animations = 0
	_tracks = 0
	return features.has("dedicated_server") and OS.get_environment(ENV_OFF) != "0"


func _end_customize_resources() -> void:
	## A second export may serve the customized files from Godot's cache: then these are 0 and the pack is still stripped.
	print("DedicatedStrip audio=%d animations=%d tracks_removed=%d" % [_audio, _animations, _tracks])


## Part of the cache key of the customized files: change VERSION when the rules above change.
func _get_customization_configuration_hash() -> int:
	return hash("dedicated_strip_%d" % VERSION)


func _customize_resource(resource: Resource, path: String) -> Resource:
	if resource is AudioStream:
		_audio += 1
		return stripped_audio(resource as AudioStream)
	if resource is Animation and is_clip_path(path):
		var source := resource as Animation
		_animations += 1
		_tracks += source.get_track_count()
		return stripped_animation(source)
	return null


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if OS.get_environment(ENV_PROBE) != "1":
		return
	var source := FileAccess.get_file_as_bytes(PROBE_SOURCE)
	if source.is_empty():
		push_error("DedicatedStrip: %s is missing, the pack has no memory probe" % PROBE_SOURCE)
		return
	add_file(PROBE_SCRIPT, source, false)
	add_file(PROBE_SCENE, (PROBE_SCENE_TEXT % PROBE_SCRIPT).to_utf8_buffer(), false)
