@tool
class_name VegetationSpecies
extends Resource

## How one species of plant looks: which prop, how big, how far it shows. A FloraLayer or a VegetationPatch holds one
## (data/vegetation/species/<name>.tres). The mesh and its material are the prop's (BodyCatalog.mesh(model), shared by
## every instance). A type template: never mutated at runtime.

## The original's plant tag (CAH1, PYA2...). FloraPlacement hashes it, so it decides where the plants of a cell stand:
## do not rename it on a species a map already uses.
@export var tag := ""
## The prop it draws (assets/original/props/<model>.glb). Empty: `tag` (the original draws the prop with the tag's name).
@export var model := ""
## Uniform scale of an instance, picked per instance by FloraPlacement between x and y.
@export var scale_range := Vector2(0.9, 1.1)
## Off by default (RFC-054 §14.6): plants cast no shadow. A preset can also turn every shadow of a layer off.
@export var cast_shadow := false
## Camera distance where this species is gone (it dithers out over the layer's `fade_m` before). 0 = the layer's radius.
@export_range(0.0, 400.0, 1.0, "suffix:m") var visibility_end_m := 0.0


## The tag FloraPlacement hashes: `tag`, or `model` for a species made by hand without one.
func density_tag() -> String:
	return tag if not tag.is_empty() else model


## The prop drawn: `model`, or the tag.
func prop() -> String:
	return model if not model.is_empty() else tag
