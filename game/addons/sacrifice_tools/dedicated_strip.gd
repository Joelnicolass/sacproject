@tool
class_name DedicatedStrip
extends EditorExportPlugin

## What the dedicated server build does not carry: when the export preset is a Godot "Dedicated Server" one, every AudioStream
## goes into the pack as an empty stream of the same class and every body clip (the Animation files of
## scenes/bodies/models/*_clips/) as an Animation with only its length, step, loop mode and markers, no tracks.
## The server never plays a sound and never poses a bone: the rules read the length and the `hit`/`shoot` markers of a clip
## (ClipFacts), and those stay. Every Mesh file (scenes/props/meshes, scenes/bodies/meshes, the spell tubes, ...) goes in as a
## PlaceholderMesh with the same `aabb`: the server never draws, and the only thing the rules read from a mesh is get_aabb()
## (BuildingFit). Two things keep their geometry, each with the reader that needs it:
##   - MESH_KEEP_DIRS: the map (scenes/map/ and assets/original/maps/). TerrainMesh compares surface_get_array_len and the metas of its
##     mesh with the GroundSurface data (TerrainMesh._saved_mesh_matches), builds the ground trimesh from it (Mesh.create_trimesh_shape in
##     TerrainMesh.ground_shape) and the falling chunks and hole walls are cut from its arrays. A placeholder has none.
##   - PrimitiveMesh (Cylinder, Sphere, ...): its parameters are the data (RiftSpawner reads the radius of a CylinderMesh) and it costs
##     a few bytes. Not a size problem, so not touched.
## The navmesh is not baked from meshes (NavBakeSettings: static colliders, i.e. shapes), so nothing under scenes/ needs more.
## NOT here: textures (Godot's own dedicated mode already turns them into placeholders),
## and nothing runs outside an export: the game and the editor never load this class.
## Environment, for measuring only: SAC_DEDICATED_STRIP=0 exports the preset untouched; SAC_PACK_PROBE=1 also puts the memory
## probe (agent/harness/dedicated_mem_probe.gd) in the pack, to run as `--main-pack <pck> res://dedicated_mem_probe/probe.tscn`.

const VERSION := 2
const ENV_OFF := "SAC_DEDICATED_STRIP"
const ENV_PROBE := "SAC_PACK_PROBE"
const CLIP_DIR := "res://scenes/bodies/models/"
const CLIP_FOLDER_SUFFIX := "_clips"
## Mesh files under these folders keep their geometry (see the header for the reader of each).
const MESH_KEEP_DIRS: PackedStringArray = ["res://scenes/map/", "res://assets/original/maps/"]
const PROBE_SOURCE := "res://agent/harness/dedicated_mem_probe.gd"
const PROBE_SCRIPT := "res://dedicated_mem_probe/probe.gd"
const PROBE_SCENE := "res://dedicated_mem_probe/probe.tscn"
const PROBE_SCENE_TEXT := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n\n[node name=\"Probe\" type=\"Node\"]\nscript = ExtResource(\"1\")\n"

var _audio := 0
var _animations := 0
var _tracks := 0
var _meshes := 0


## True for the Animation files of a model's clip library (res://scenes/bodies/models/<model>_clips/<role>.res).
static func is_clip_path(path: String) -> bool:
	return path.begins_with(CLIP_DIR) and path.get_base_dir().ends_with(CLIP_FOLDER_SUFFIX) and not path.get_file().is_empty()


## True for a mesh file whose geometry the server needs (the map's folders).
static func keeps_mesh_path(path: String) -> bool:
	for dir: String in MESH_KEEP_DIRS:
		if path.begins_with(dir):
			return true
	return false


## True when `mesh` of `path` goes into the dedicated pack as a placeholder.
static func strips_mesh(mesh: Mesh, path: String) -> bool:
	return not (mesh is PrimitiveMesh) and not (mesh is PlaceholderMesh) and not keeps_mesh_path(path)


## A PlaceholderMesh with the bounds of the original: get_aabb() answers the same, nothing is drawn.
static func stripped_mesh(source: Mesh) -> Mesh:
	var out := PlaceholderMesh.new()
	out.resource_name = source.resource_name
	out.aabb = source.get_aabb()
	return out


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


func _begin_customize_resources(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	_audio = 0
	_animations = 0
	_tracks = 0
	_meshes = 0
	## The preset's "Dedicated Server" mode is not among `features` (Godot passes the platform's and the custom ones): ask the preset.
	var preset := get_export_preset()
	return preset != null and preset.is_dedicated_server() and OS.get_environment(ENV_OFF) != "0"


func _end_customize_resources() -> void:
	## A second export may serve the customized files from Godot's cache: then these are 0 and the pack is still stripped.
	print("DedicatedStrip audio=%d animations=%d tracks_removed=%d meshes=%d" % [_audio, _animations, _tracks, _meshes])


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
	if resource is Mesh and strips_mesh(resource as Mesh, path):
		_meshes += 1
		return stripped_mesh(resource as Mesh)
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
