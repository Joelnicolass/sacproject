class_name SoundLibrary
extends RefCounted

## RFC-052 052a (F360): resolves a sound tag to its .tres and caches it. The one place that loads audio sets.
## - Looks in data/audio/ first (the sets made by hand or baked from assets/custom/, versioned; they win), then in
##   data/audio/original/ (baked from the original's import; not versioned, may be missing). A tag in neither is null
##   and silent: no warning, the game runs without the original.
## - With the AudioGate closed (dedicated, room server, headless) it returns null and loads nothing.
## - `rel` is the path under a root without the extension: "creatures/zomb", "wizards/cwa0", "ui", "music/james".
## Later cuts add MusicSet and AmbienceSet through `find`; nothing here knows the game's tags.

const DEFAULT_ROOTS: PackedStringArray = ["res://data/audio/", "res://data/audio/original/"]

## Where `find` looks, in order. The cases point it at a fixture folder and reset it.
static var roots: PackedStringArray = DEFAULT_ROOTS
## path tried -> Resource (or null when it does not exist).
static var _cache: Dictionary = {}


## The resource of `rel` in the first root that has it, or null (gate closed, or no root has it).
static func find(rel: String) -> Resource:
	if not AudioGate.is_open() or rel.is_empty():
		return null
	for root in roots:
		var path := root.path_join(rel + ".tres")
		if not _cache.has(path):
			_cache[path] = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
		if _cache[path] != null:
			return _cache[path]
	return null


## The SoundSet of `rel` ("creatures/zomb"), or null.
static func sound_set(rel: String) -> SoundSet:
	return find(rel) as SoundSet


static func creature(tag: StringName) -> SoundSet:
	return sound_set("creatures/%s" % tag)


static func wizard(tag: StringName) -> SoundSet:
	return sound_set("wizards/%s" % tag)


## Forgets what was loaded (a bake wrote new sets; the cases change `roots`).
static func clear_cache() -> void:
	_cache.clear()


static func reset_roots() -> void:
	roots = DEFAULT_ROOTS
	clear_cache()
