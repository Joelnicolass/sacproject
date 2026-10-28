class_name OriginalAssets
extends RefCounted

## Tells the import tools where the original's files live (res://assets/original/) and how an icon tag becomes a file name.
## Only the tools in tools/ use it; the game never reads the original's formats.
##

const ROOT := "res://assets/original/"


## The file name of an icon tag in `ui/icons/`: every capital letter is written as `_` + lower case (`HSba` -> `_h_sba.png`,
## `hsba` -> `hsba.png`, `!nur` -> `!nur.png`). The original has tags that differ only in case (Life Shield `hsba`, Protector
## `HSba`) and macOS and Windows see them as one file. tools/import/import_ui.py `icon_file` is the same function; the importer fails
## on a clash and tools/audit/check_icon_files.gd compares both on every tag.
static func icon_file(tag: String) -> String:
	var name := ""
	for i in tag.length():
		var letter := tag[i]
		name += "_" + letter.to_lower() if letter != letter.to_lower() else letter
	return name + ".png"
