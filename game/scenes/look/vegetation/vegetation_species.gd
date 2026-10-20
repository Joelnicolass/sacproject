@tool
class_name VegetationSpecies
extends Resource

## RFC-054 054c (F382): how one species of a vegetation layer looks. The mesh and its material are the prop's
## (BodyCatalog.mesh(model), shared by every instance); this only says which model, how big and how far it shows.
## A type template: never mutated at runtime.

## The density tag it answers (MAP_TAGS: a widget tag of the original, CAH1, PYA2...). Empty: `model`.
@export var tag := ""
## The prop it draws (assets/original/props/<model>.glb). Empty: `tag` (the original draws the prop with the tag's name).
@export var model := ""
## MAP_TAG layers only: how often this species is picked against the others.
@export_range(0.0, 10.0, 0.05) var weight := 1.0
## Uniform scale of an instance, picked per instance by FloraPlacement between x and y.
@export var scale_range := Vector2(0.9, 1.1)
## Off by default (RFC-054 §14.6): plants cast no shadow. A preset can also turn every shadow of a layer off.
@export var cast_shadow := false
## Camera distance where this species is gone (it dithers out over the layer's `fade_m` before). 0 = the layer's radius.
@export_range(0.0, 400.0, 1.0, "suffix:m") var visibility_end_m := 0.0


## The density tag this entry answers.
func density_tag() -> String:
	return tag if not tag.is_empty() else model


## The prop drawn for density tag `for_tag`.
func model_for(for_tag: String) -> String:
	return model if not model.is_empty() else (tag if not tag.is_empty() else for_tag)
