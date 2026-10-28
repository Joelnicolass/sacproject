@tool
class_name MapWriter
extends RefCounted

## Puts the maps of a surface on disk and on its owner. Where: a picture under `mirror_from` gets its maps at the same place
## under `mirror_to` (textures/<owner>/001.png -> surfaces/<owner>/001_normal.png); any other picture gets them beside it.
## Writes a PNG and, the first time, its .import (VRAM compressed, mipmaps, normal map flag for the normal), and never
## replaces a PNG unless `overwrite`. Assigns them to a BaseMaterial3D (normal, occlusion R, roughness G) or to any Resource
## with `normal` / `orm` Texture2D fields, through the editor's undo when one is given. Not: the pixels (ReliefBaker), the UI.

const SETTING_FROM := "surface_maps/mirror_from"
const SETTING_TO := "surface_maps/mirror_to"
const DEFAULT_FROM := "res://assets/original/textures/"
const DEFAULT_TO := "res://assets/surfaces/"
const SUFFIXES := {"normal": "_normal", "orm": "_orm"}


## The colour picture a material or a role is painted with; null if it has none.
static func albedo_of(target: Resource) -> Texture2D:
	if target is BaseMaterial3D:
		return (target as BaseMaterial3D).albedo_texture
	return target.get("albedo") as Texture2D if "albedo" in target else null


## The source picture of the albedo read from its file (not the imported, maybe compressed, texture); null if missing.
static func albedo_image(target: Resource) -> Image:
	var albedo := albedo_of(target)
	if albedo == null or albedo.resource_path.is_empty() or albedo.resource_path.contains("::"):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(albedo.resource_path))


## Where the map `key` ("normal" or "orm") of the picture at `albedo_path` lives.
static func map_path(albedo_path: String, key: String) -> String:
	var from := str(ProjectSettings.get_setting(SETTING_FROM, DEFAULT_FROM))
	var to := str(ProjectSettings.get_setting(SETTING_TO, DEFAULT_TO))
	var dir := albedo_path.get_base_dir() + "/"
	if dir.begins_with(from):
		dir = to + dir.trim_prefix(from)
	return dir + albedo_path.get_file().get_basename() + str(SUFFIXES[key]) + ".png"


## Writes each Image of `maps` ({"normal": Image, "orm": Image or null}) beside the target's albedo; returns the paths written.
## An existing PNG is kept unless `overwrite`; an existing .import is always kept (its uid and settings stay).
static func write(target: Resource, maps: Dictionary, overwrite := false) -> PackedStringArray:
	var written := PackedStringArray()
	var albedo := albedo_of(target)
	if albedo == null or albedo.resource_path.is_empty():
		return written
	for key: String in SUFFIXES:
		var image := maps.get(key) as Image
		if image == null:
			continue
		var path := map_path(albedo.resource_path, key)
		if FileAccess.file_exists(path) and not overwrite:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		if image.save_png(path) != OK:
			push_error("MapWriter: could not write %s" % path)
			continue
		if not FileAccess.file_exists(path + ".import"):
			_write_import(path, key == "normal")
		written.append(path)
	return written


## The maps already on disk for the target's albedo: {"normal": path, "orm": path}, only those that exist.
static func existing(target: Resource) -> Dictionary:
	var out := {}
	var albedo := albedo_of(target)
	if albedo == null or albedo.resource_path.is_empty():
		return out
	for key: String in SUFFIXES:
		var path := map_path(albedo.resource_path, key)
		if FileAccess.file_exists(path):
			out[key] = path
	return out


## True once Godot imported the picture at `path` (its .import names an imported file that exists).
static func is_imported(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path + ".import") != OK or not config.has_section("remap"):
		return false
	for key in config.get_section_keys("remap"):
		if key.begins_with("path") and FileAccess.file_exists(str(config.get_value("remap", key))):
			return true
	return false


## In the editor: tells the file system about new pictures and imports them, so they can be loaded right away.
static func import_in_editor(paths: PackedStringArray) -> void:
	if not Engine.is_editor_hint() or paths.is_empty():
		return
	var files := EditorInterface.get_resource_filesystem()
	for path in paths:
		files.update_file(path)
	files.reimport_files(paths)


## Points the target at the imported maps of `paths` ({"normal": path, "orm": path}); one undo step when `undo` is given.
## Returns false when nothing could be assigned (no map imported yet).
static func assign(target: Resource, paths: Dictionary, undo: EditorUndoRedoManager = null) -> bool:
	var changes := {}
	for key: String in paths:
		if is_imported(str(paths[key])):
			changes.merge(_fields(target, key, load(str(paths[key])) as Texture2D))
	return _apply(target, changes, "Relief: assign maps", undo)


## Takes the maps off the target (the PNGs stay on disk); one undo step when `undo` is given.
static func clear(target: Resource, undo: EditorUndoRedoManager = null) -> bool:
	var changes := {}
	for key: String in SUFFIXES:
		changes.merge(_fields(target, key, null))
	return _apply(target, changes, "Relief: remove maps", undo)


## The fields that carry map `key` on the target, with `texture` (null = off).
static func _fields(target: Resource, key: String, texture: Texture2D) -> Dictionary:
	var on := texture != null
	if target is BaseMaterial3D:
		if key == "normal":
			return {"normal_enabled": on, "normal_texture": texture}
		# Godot multiplies the G channel by `roughness`: 1 while the ORM carries it, the recipe's constant again without it.
		var material := target as BaseMaterial3D
		var roughness := 1.0 if on else (ReliefRecipe.new().roughness if material.roughness_texture != null else material.roughness)
		return {"ao_enabled": on, "ao_texture": texture, "ao_texture_channel": BaseMaterial3D.TEXTURE_CHANNEL_RED,
			"roughness_texture": texture, "roughness_texture_channel": BaseMaterial3D.TEXTURE_CHANNEL_GREEN, "roughness": roughness}
	return {key: texture} if key in target else {}


static func _apply(target: Resource, changes: Dictionary, action: String, undo: EditorUndoRedoManager) -> bool:
	if changes.is_empty():
		return false
	if undo == null:
		for field: String in changes:
			target.set(field, changes[field])
		return true
	undo.create_action(action, UndoRedo.MERGE_DISABLE, target)
	for field: String in changes:
		undo.add_do_property(target, field, changes[field])
		undo.add_undo_property(target, field, target.get(field))
	undo.commit_action()
	return true


## The first .import of a map: VRAM compressed with mipmaps; the normal one flagged as a normal map. Godot adds the rest.
## `detect_3d/compress_to=0`: a map is 3D already, so the editor finds nothing to detect and never rewrites the file.
static func _write_import(path: String, is_normal: bool) -> void:
	var file := FileAccess.open(path + ".import", FileAccess.WRITE)
	file.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=2\n"
		+ "compress/normal_map=%d\nmipmaps/generate=true\ndetect_3d/compress_to=0\n" % (1 if is_normal else 2))
