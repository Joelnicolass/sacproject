@tool
extends RefCounted

## One material (or ground role) through the generator: which maps a recipe makes, baking and writing the missing ones
## (all of them with `overwrite`) and finding the ones on disk. Shared by the inspector section and the batch dialog, so
## both decide the same way. Not: the pixels (ReliefBaker), the files and the assigning (MapWriter), the UI.


## The maps a recipe makes: always the normal, the ORM only when the recipe asks for it.
static func keys(recipe: ReliefRecipe) -> PackedStringArray:
	return PackedStringArray(["normal", "orm"]) if recipe.orm else PackedStringArray(["normal"])


## True when every map of the recipe is already on disk for the target's albedo.
static func complete(target: Resource, recipe: ReliefRecipe) -> bool:
	var on_disk := MapWriter.existing(target)
	for key in keys(recipe):
		if not on_disk.has(key):
			return false
	return true


## Bakes the target's albedo and writes its maps; an existing PNG stays unless `overwrite`. Returns the paths written.
static func write_maps(target: Resource, recipe: ReliefRecipe, overwrite: bool) -> PackedStringArray:
	if complete(target, recipe) and not overwrite:
		return PackedStringArray()
	var image := MapWriter.albedo_image(target)
	if image == null:
		return PackedStringArray()
	return MapWriter.write(target, ReliefBaker.bake(image, recipe), overwrite)


## The recipe's maps that are on disk: {"normal": path, "orm": path}, only those that exist.
static func on_disk(target: Resource, recipe: ReliefRecipe) -> Dictionary:
	var out := {}
	var found := MapWriter.existing(target)
	for key in keys(recipe):
		if found.has(key):
			out[key] = found[key]
	return out


## True when the target's albedo is a picture file the generator can read (not an embedded or generated texture).
static func has_source(target: Resource) -> bool:
	var albedo := MapWriter.albedo_of(target)
	return albedo != null and not albedo.resource_path.is_empty() and not albedo.resource_path.contains("::")
