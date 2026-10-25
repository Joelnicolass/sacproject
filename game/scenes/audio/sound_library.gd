class_name SoundLibrary
extends RefCounted

## Finds the sets that are not a body's (world, UI, advisor, music, ambience) by their path under data/audio/ and caches them.
## - Looks in data/audio/custom/ first (baked from assets/custom/sounds/ or made by hand; they win), then in data/audio/
##   (baked from the original's import in assets/original/audio/). A tag in neither is null and silent: no warning.
## - A set whose streams are missing (the original's audio not imported or not pulled) is skipped without loading it, so
##   the loader prints nothing; the next root is tried. The game runs silent without the original.
## - With the AudioGate closed (dedicated, room server, headless) it returns null and loads nothing.
## - `rel` is the path under a root without the extension: "ui", "world", "advisor", "music/james".
## Creatures and wizards do not come through here: their set is `CreatureType.sounds` / `WizardType.sounds`. It goes away when
## 055o-c and 055o-d give the music, the ambience, the advisor and the UI their typed sets.

const DEFAULT_ROOTS: PackedStringArray = ["res://data/audio/custom/", "res://data/audio/"]

## Where `find` looks, in order. The cases point it at a fixture folder and reset it.
static var roots: PackedStringArray = DEFAULT_ROOTS
## path tried -> Resource (or null when it does not exist).
static var _cache: Dictionary = {}


## The resource of `rel` in the first root that has it, or null (gate closed, or no root has it).
static func find(rel: String) -> Resource:
	if not AudioGate.is_open() or rel.is_empty():
		return null
	for root in roots:
		var found := _at(root, rel)
		if found != null:
			return found
	return null


## Every root's resource of `rel`, in root order (empty when the gate is closed or no root has it). A table looked up
## key by key takes the first root that answers the key, so a custom one overrides only what it names.
static func find_all(rel: String) -> Array[Resource]:
	var out: Array[Resource] = []
	if not AudioGate.is_open() or rel.is_empty():
		return out
	for root in roots:
		var found := _at(root, rel)
		if found != null:
			out.append(found)
	return out


## The resource of `rel` under `root` (cached), or null when it does not exist or names a missing file.
static func _at(root: String, rel: String) -> Resource:
	var path := root.path_join(rel + ".tres")
	if not _cache.has(path):
		_cache[path] = ResourceLoader.load(path) if ResourceLoader.exists(path) and has_dependencies(path) else null
	return _cache[path]


## True when every file `path` depends on exists (read from the file, nothing is loaded; ResourceDeps).
static func has_dependencies(path: String) -> bool:
	return ResourceDeps.all_exist(path)


## The res:// paths `path` depends on (ResourceDeps.paths).
static func dependency_paths(path: String) -> PackedStringArray:
	return ResourceDeps.paths(path)


## The SoundSet of `rel` ("world"), or null.
static func sound_set(rel: String) -> SoundSet:
	return find(rel) as SoundSet


## Forgets what was loaded (a bake wrote new sets; the cases change `roots`).
static func clear_cache() -> void:
	_cache.clear()


static func reset_roots() -> void:
	roots = DEFAULT_ROOTS
	clear_cache()
