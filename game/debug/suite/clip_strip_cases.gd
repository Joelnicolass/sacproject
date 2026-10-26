extends RefCounted

## 055s s4 case of rules_suite: the dedicated server build keeps each body clip with only its length, step, loop mode and markers
## (DedicatedStrip), and the rules must read the same numbers from it. For every clip library of the models this builds the stripped
## copy with the SAME functions the export uses and checks:
##   - the copy has no track and the same length, step, loop mode and markers (name, time, color);
##   - ClipFacts on the copy answers exactly as on the original: has, frames, fps, seconds, seconds_at_30, hits and shots of every role;
##   - the clip folders are recognised by is_clip_path and nothing else is;
##   - an audio stream of every class a sound can have comes out empty and of the same class.
##   - every Mesh file of a sample of props, buildings and bodies comes out a PlaceholderMesh with the same aabb and name;
##     the map's folders, a PrimitiveMesh and a PlaceholderMesh are not stripped (strips_mesh / keeps_mesh_path).
## Prints CLIP STRIP libs=<n> roles=<n> tracks_in=<n> tracks_out=<n> bad=<n>.

const STRIP := preload("res://addons/sacrifice_tools/dedicated_strip.gd")
const MODELS_DIR := "res://scenes/bodies/models/"
const MAX_LINES := 12
const MESH_SAMPLE := 6
const AUDIO_CLASSES: PackedStringArray = ["AudioStreamWAV", "AudioStreamOggVorbis", "AudioStreamMP3", "AudioStreamRandomizer"]


func run(_host: Node) -> Dictionary:
	var bad := PackedStringArray()
	var totals := _libraries(bad)
	_paths(bad)
	_audio(bad)
	var meshes := _meshes(bad)
	print("CLIP STRIP libs=%d roles=%d tracks_in=%d tracks_out=%d meshes=%d bad=%d" % [totals["libs"], totals["roles"], totals["tracks_in"], totals["tracks_out"], meshes, bad.size()])
	for line in bad:
		print("CLIP STRIP   " + line)
	var ok: bool = bad.is_empty() and meshes > 0 and totals["roles"] > 0 and totals["tracks_in"] > 0 and totals["tracks_out"] == 0
	return {"clip_strip": {"ok": ok, "libs": totals["libs"], "roles": totals["roles"], "tracks_in": totals["tracks_in"], "tracks_out": totals["tracks_out"], "meshes": meshes, "bad": bad}}


func _libraries(bad: PackedStringArray) -> Dictionary:
	var totals := {"libs": 0, "roles": 0, "tracks_in": 0, "tracks_out": 0}
	for file: String in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with("_clips.tres"):
			continue
		var original := load(MODELS_DIR + file) as AnimationLibrary
		if original == null:
			_note(bad, file + ": does not load")
			continue
		totals["libs"] += 1
		var copy := AnimationLibrary.new()
		for role: StringName in original.get_animation_list():
			var source := original.get_animation(role)
			var stripped: Animation = STRIP.stripped_animation(source)
			copy.add_animation(role, stripped)
			totals["roles"] += 1
			totals["tracks_in"] += source.get_track_count()
			totals["tracks_out"] += stripped.get_track_count()
			_check_animation(file, role, source, stripped, bad)
		_check_facts(file, original, copy, bad)
	return totals


func _check_animation(file: String, role: StringName, source: Animation, stripped: Animation, bad: PackedStringArray) -> void:
	if stripped.length != source.length or stripped.step != source.step or stripped.loop_mode != source.loop_mode:
		_note(bad, "%s/%s: length, step or loop mode changed" % [file, role])
	var names := source.get_marker_names()
	if stripped.get_marker_names().size() != names.size():
		_note(bad, "%s/%s: %d markers, the copy has %d" % [file, role, names.size(), stripped.get_marker_names().size()])
		return
	for marker_name: String in names:
		var marker := StringName(marker_name)
		if not stripped.has_marker(marker) or stripped.get_marker_time(marker) != source.get_marker_time(marker) \
				or stripped.get_marker_color(marker) != source.get_marker_color(marker):
			_note(bad, "%s/%s: marker %s differs" % [file, role, marker_name])


func _check_facts(file: String, original: AnimationLibrary, copy: AnimationLibrary, bad: PackedStringArray) -> void:
	var before := ClipFacts.of(original)
	var after := ClipFacts.of(copy)
	for role: StringName in original.get_animation_list():
		if before.has(role) != after.has(role) or before.frames(role) != after.frames(role) or before.fps(role) != after.fps(role) \
				or before.seconds(role) != after.seconds(role) or before.seconds_at_30(role) != after.seconds_at_30(role) \
				or before.hits(role) != after.hits(role) or before.shots(role) != after.shots(role):
			_note(bad, "%s/%s: ClipFacts reads other numbers on the stripped clip" % [file, role])


func _paths(bad: PackedStringArray) -> void:
	for path: String in ["res://scenes/bodies/models/trogg_model_clips/HUst.res", "res://scenes/bodies/models/sylph_model_clips/AAa1.res"]:
		if not STRIP.is_clip_path(path):
			_note(bad, path + ": a clip file that is_clip_path does not recognise")
	for path: String in ["res://scenes/bodies/models/trogg_model_clips.tres", "res://scenes/bodies/models/trogg_model.tscn", "res://scenes/spells/zones/volcano_lava_tube.res", "res://scenes/bodies/models/_clips/"]:
		if STRIP.is_clip_path(path):
			_note(bad, path + ": is_clip_path takes a file that is not a clip")


func _audio(bad: PackedStringArray) -> void:
	for stream_class: String in AUDIO_CLASSES:
		var source := ClassDB.instantiate(stream_class) as AudioStream
		if source == null:
			_note(bad, stream_class + ": cannot be built here")
			continue
		var empty: AudioStream = STRIP.stripped_audio(source)
		if empty == null or empty.get_class() != stream_class:
			_note(bad, "%s: the stripped stream is %s" % [stream_class, empty.get_class() if empty != null else "null"])
	var wav := AudioStreamWAV.new()
	wav.data = PackedByteArray([1, 2, 3, 4])
	var stripped_wav := STRIP.stripped_audio(wav) as AudioStreamWAV
	if stripped_wav == null or not stripped_wav.data.is_empty():
		_note(bad, "AudioStreamWAV: the stripped stream keeps its samples")


## Samples of the standalone mesh files the export strips (props, bodies, spell tubes) and of the folders it keeps.
func _meshes(bad: PackedStringArray) -> int:
	var checked := 0
	for dir: String in ["res://scenes/props/meshes/", "res://scenes/bodies/meshes/", "res://scenes/spells/zones/", "res://scenes/spells/tornado/"]:
		var taken := 0
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".res") or taken >= MESH_SAMPLE:
				continue
			var path: String = dir + file
			var source := load(path) as Mesh
			if source == null:
				continue
			taken += 1
			checked += 1
			if not STRIP.strips_mesh(source, path):
				_note(bad, path + ": a mesh file the export should strip")
				continue
			var out := STRIP.stripped_mesh(source)
			if not (out is PlaceholderMesh) or out.get_aabb() != source.get_aabb() or out.resource_name != source.resource_name:
				_note(bad, "%s: the placeholder does not keep aabb %s" % [path, source.get_aabb()])
	## BuildingFit measures buildings with get_aabb(): the box of the parts must not change.
	var building := load("res://scenes/structures/buildings/james_rock_1.tscn") as PackedScene
	if building != null:
		var root := building.instantiate()
		for part in root.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := part as MeshInstance3D
			if mesh_node.mesh != null and mesh_node.mesh.resource_path.ends_with(".res"):
				var copy := STRIP.stripped_mesh(mesh_node.mesh)
				if copy.get_aabb() != mesh_node.mesh.get_aabb():
					_note(bad, "%s: building part aabb changes" % mesh_node.mesh.resource_path)
		root.free()
	for path: String in ["res://scenes/map/maps/high_noon/terrain.res", "res://assets/original/maps/high_noon/terrain.res", "res://scenes/map/anything.res"]:
		if not STRIP.keeps_mesh_path(path):
			_note(bad, path + ": a map file that keeps_mesh_path does not keep")
	for path: String in ["res://scenes/props/meshes/rock.res", "res://scenes/bodies/meshes/baby.res", "res://scenes/spells/zones/volcano_lava_tube.res"]:
		if STRIP.keeps_mesh_path(path):
			_note(bad, path + ": keeps_mesh_path keeps a file that is not the map's")
	var ground := ArrayMesh.new()
	if STRIP.strips_mesh(ground, "res://assets/original/maps/high_noon/terrain.res") or STRIP.strips_mesh(ground, "res://scenes/map/maps/x/terrain.res"):
		_note(bad, "a map mesh would be stripped")
	if STRIP.strips_mesh(CylinderMesh.new(), "res://scenes/props/meshes/x.res") or STRIP.strips_mesh(PlaceholderMesh.new(), "res://scenes/props/meshes/x.res"):
		_note(bad, "a PrimitiveMesh or a PlaceholderMesh would be stripped")
	if not STRIP.strips_mesh(ground, "res://scenes/props/meshes/x.res"):
		_note(bad, "an ArrayMesh of props would not be stripped")
	return checked


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)
