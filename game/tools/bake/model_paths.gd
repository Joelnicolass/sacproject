class_name ModelPaths
extends Resource

## Where the files of each skeletal model of scenes/bodies/models/ are, for the bake tools and the debug checks: the model tag
## (the id that travels on the wire, "eorc") -> the stem of its files ("trogg_model": trogg_model.tscn, trogg_model_clips.tres,
## trogg_model_clips/). A tag that is not listed is its own stem (a custom model keeps the name of its .glb).
## Not for the game: a look scene holds its model as a PackedScene and a type holds its clips as an AnimationLibrary, so nothing
## of scenes/ looks a model up by tag. The table (model_paths.tres) is written by tools/migrate/rename_body_models.py, never by hand.

const SCENE_DIR := "res://scenes/bodies/models/"
const TABLE_PATH := "res://tools/bake/model_paths.tres"

@export var stems: Dictionary[String, String] = {}

static var _shared: ModelPaths
var _tags: Dictionary[String, String] = {}


## The scene of `model_tag` (scenes/bodies/models/<stem>.tscn).
static func scene_path(model_tag: String) -> String:
	return SCENE_DIR + _table().stem_for(model_tag) + ".tscn"


## The library of clips of `model_tag` (role -> Animation).
static func clips_path(model_tag: String) -> String:
	return SCENE_DIR + _table().stem_for(model_tag) + "_clips.tres"


## The folder with one Animation file per clip of `model_tag`.
static func clips_dir(model_tag: String) -> String:
	return SCENE_DIR + _table().stem_for(model_tag) + "_clips/"


## The model tag of a file of SCENE_DIR (`trogg_model.tscn` or `trogg_model_clips.tres` -> "eorc").
static func tag_of_file(file: String) -> String:
	return _table().tag_for(file.get_basename().trim_suffix("_clips"))


## True when `model_tag` has a baked scene (a skeletal model with a playable idle clip).
static func exists(model_tag: String) -> bool:
	return not model_tag.is_empty() and ResourceLoader.exists(scene_path(model_tag))


static func _table() -> ModelPaths:
	if _shared == null:
		_shared = load(TABLE_PATH) as ModelPaths
	return _shared


## The stem of the files of `tag`.
func stem_for(tag: String) -> String:
	return stems.get(tag, tag)


## The tag of the model whose files start with `stem` (the inverse of `stem_for`).
func tag_for(stem: String) -> String:
	if _tags.is_empty() and not stems.is_empty():
		for tag in stems:
			_tags[stems[tag]] = tag
	return _tags.get(stem, stem)
