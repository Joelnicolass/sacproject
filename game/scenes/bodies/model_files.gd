class_name ModelFiles
extends Resource

## Which file of scenes/bodies/models/ holds each skeletal model: the model tag (the id that travels on the wire, "eorc") -> the stem
## of its files ("trogg_model": trogg_model.tscn, trogg_model_clips.tres, trogg_model_clips/). A tag that is not listed is its own stem
## (a custom model keeps the name of its .glb). Written by tools/migrate/rename_body_models.py, never by hand.
@export var stems: Dictionary[String, String] = {}

var _tags: Dictionary[String, String] = {}


## The stem of the files of `tag`.
func stem_of(tag: String) -> String:
	return stems.get(tag, tag)


## The tag of the model whose files start with `stem` (the inverse of `stem_of`).
func tag_of(stem: String) -> String:
	if _tags.is_empty() and not stems.is_empty():
		for tag in stems:
			_tags[stems[tag]] = tag
	return _tags.get(stem, stem)
