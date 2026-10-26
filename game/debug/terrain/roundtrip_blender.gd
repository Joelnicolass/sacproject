extends RefCounted

## The Blender half of roundtrip_cases: a .blend made from the edit bed's pictures (copied to a work folder), then four ways
## of breaking it that bringing it back must refuse (exit 1, the pictures byte for byte as they were): a vertex moved in X,
## a vertex deleted, the object moved, the pictures changed after the .blend was made. Without Blender it prints SKIP and
## fails nothing. Not: the round trip without edits (agent/runs/run_terrain_blender.sh), Godot's side of the pictures.

const BlenderBridge := preload("res://addons/terrain_tools/blender_bridge.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const Png16 := preload("res://addons/terrain_tools/png16.gd")
## Python run inside Blender on the object «Terrain» (`o`) before the .blend is saved under another name.
const BREAKS := {
	"moved_vertex": "o.data.vertices[300].co.x += 0.5",
	"missing_vertex": "import bmesh\nbm = bmesh.new()\nbm.from_mesh(o.data)\nbm.verts.ensure_lookup_table()\nbmesh.ops.delete(bm, geom=[bm.verts[300]], context='VERTS')\nbm.to_mesh(o.data)",
	"moved_object": "o.location.x = 5.0",
}


## The names of the cases that failed, working on a copy of the pictures of `source` in `folder`.
static func check(source: String, folder: String) -> PackedStringArray:
	var failed := PackedStringArray()
	if BlenderBridge.find().is_empty():
		print("  SKIP blender refusals: " + BlenderBridge.HOW_TO)
		return failed
	for file in [MapImages.HEIGHTS_FILE, MapImages.VOID_FILE]:
		DirAccess.copy_absolute(BlenderBridge.absolute(source.path_join(file)), BlenderBridge.absolute(folder.path_join(file)))
	var made := BlenderBridge.make_blend(folder)
	if not made.ok():
		failed.append("blender_make (%s)" % made.summary())
		return failed
	var blend := BlenderBridge.blend_of(folder)
	for name: String in BREAKS:
		var broken := folder.path_join(BlenderBridge.WORK_DIR).path_join(name + ".blend")
		var script := "import bpy\no = bpy.data.objects['Terrain']\n%s\nbpy.ops.wm.save_as_mainfile(filepath=r'%s')" % [
				BREAKS[name], BlenderBridge.absolute(broken)]
		var edit := BlenderBridge.run(["--background", "--factory-startup", BlenderBridge.absolute(blend), "--python-expr", script])
		if not edit.ok():
			failed.append("blender_%s_edit (%s)" % [name, edit.summary()])
			continue
		_refused(failed, name, folder, broken)
	var heights := folder.path_join(MapImages.HEIGHTS_FILE)
	var picture := Png16.read_file(heights)
	picture.samples[0] = (picture.samples[0] + 1) % (MapImages.TOP_UNIT + 1)
	Png16.write_file(heights, picture.width, picture.height, picture.samples, 16)
	_refused(failed, "pictures_changed_since", folder, blend)
	return failed


## Bringing `blend` back into `folder` must exit 1 and leave the pictures as they are.
static func _refused(failed: PackedStringArray, name: String, folder: String, blend: String) -> void:
	var before := _pictures(folder)
	var run := BlenderBridge.export_images(folder, false, blend)
	print("  blender %s: exit %d, %s" % [name, run.code, run.summary().replace("\n", " | ")])
	if run.code != 1 or _pictures(folder) != before:
		failed.append("blender_refuses_%s (exit %d)" % [name, run.code])


static func _pictures(folder: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	for file in [MapImages.HEIGHTS_FILE, MapImages.VOID_FILE]:
		if FileAccess.file_exists(folder.path_join(file)):
			bytes.append_array(FileAccess.get_file_as_bytes(folder.path_join(file)))
	return bytes
