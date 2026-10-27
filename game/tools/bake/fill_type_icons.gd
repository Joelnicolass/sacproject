extends SceneTree

## Gives every creature, spell and ability in data/catalog/ its `icon`: the picture the book, the roster, the info box and the
## armed cursor show. It reads the versioned PNGs and needs no original game; without `assets/original/ui/icons/` it says so and writes nothing.
## A creature of your own uses `assets/custom/icons/<tag>.png` (tools/bake/creature_icon.gd draws it); the rest, the PNG of the original.
## A type that already has an icon is kept (it may be yours): `--force` replaces it.
##
##   Godot --headless --path . --script res://tools/bake/fill_type_icons.gd [-- --force]
##
## Ref: the same rule as the file names of tools/import/import_ui.py (`OriginalAssets.icon_file`).

const ICONS_DIR := "res://assets/original/ui/icons/"
const CUSTOM_DIR := "res://assets/custom/icons/"
const FAMILIES := ["creatures", "spells", "abilities"]
const CATALOG := "res://data/catalog/"


func _init() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ICONS_DIR)):
		print("FILL_TYPE_ICONS: %s is missing (the icons come with the project; run tools/import/import_ui.py if you have the original). Nothing written." % ICONS_DIR)
		quit(1)
		return
	var filled := 0
	var kept := 0
	var without := PackedStringArray()
	for family: String in FAMILIES:
		for file in DirAccess.get_files_at(CATALOG + family):
			if not file.ends_with(".tres"):
				continue
			var path := CATALOG + family + "/" + file
			var type := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			var current: Variant = type.get("icon")
			if current != null and not force:
				kept += 1
				continue
			var texture := _icon_for(family, str(type.get("tag")))
			if texture == null:
				without.append("%s/%s" % [family, file])
				continue
			type.set("icon", texture)
			if ResourceSaver.save(type, path) == OK:
				filled += 1
			else:
				push_error("fill_type_icons: cannot save %s" % path)
	print("FILL_TYPE_ICONS: %d filled, %d kept, %d without a picture" % [filled, kept, without.size()])
	for entry in without:
		print("  no icon: ", entry)
	quit(0)


## Yours first (creatures only), then the original's.
func _icon_for(family: String, tag: String) -> Texture2D:
	var candidates: Array[String] = []
	if family == "creatures":
		candidates.append(CUSTOM_DIR + tag + ".png")
	candidates.append(ICONS_DIR + OriginalAssets.icon_file(tag))
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
