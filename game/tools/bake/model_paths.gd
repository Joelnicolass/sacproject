class_name ModelPaths
extends Resource

## Where the files of each skeletal model are, for the bake tools and the audits: the model tag (the
## id that travels on the wire, "eorc") -> the path stem of its files
## ("res://creatures/trogg/model/trogg_model": trogg_model.tscn, trogg_model_clips.tres,
## trogg_model_clips/). A model only one creature wears lives in that creature's folder; a shared
## one (wizards, a model two creatures wear) in scenes/bodies/models/. A tag that is not listed is a
## new creature's: creatures/<tag>/model/<tag>_model.
## Not for the game: a look scene holds its model as a PackedScene and a type holds its clips as an
## AnimationLibrary, so nothing of scenes/ looks a model up by tag. The table (model_paths.tres) is
## regenerated from what is on disk, never by hand.

const TABLE_PATH := "res://tools/bake/model_paths.tres"

static var _shared: ModelPaths

@export var stems: Dictionary[String, String] = {}


## The scene of `model_tag` (<stem>.tscn).
static func scene_path(model_tag: String) -> String:
	return _table().stem_for(model_tag) + ".tscn"


## The library of clips of `model_tag` (role -> Animation).
static func clips_path(model_tag: String) -> String:
	return _table().stem_for(model_tag) + "_clips.tres"


## The folder with one Animation file per clip of `model_tag`.
static func clips_dir(model_tag: String) -> String:
	return _table().stem_for(model_tag) + "_clips/"


## Every model scene on disk, sorted by path.
static func all_scenes() -> PackedStringArray:
	var paths := PackedStringArray()
	for stem: String in _table().stems.values():
		if ResourceLoader.exists(stem + ".tscn"):
			paths.append(stem + ".tscn")
	paths.sort()
	return paths


## True when `model_tag` has a baked scene (a skeletal model with a playable idle clip).
static func exists(model_tag: String) -> bool:
	return not model_tag.is_empty() and ResourceLoader.exists(scene_path(model_tag))


static func _table() -> ModelPaths:
	if _shared == null:
		_shared = load(TABLE_PATH) as ModelPaths
	return _shared


## The path stem of the files of `tag`.
func stem_for(tag: String) -> String:
	return stems.get(tag, "%s%s/model/%s_model" % [GameCatalog.CREATURES_DIR, tag, tag])
