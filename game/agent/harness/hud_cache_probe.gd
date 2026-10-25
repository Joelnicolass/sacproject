extends Node

## Playtest helper for the fallback of the HUD when pictures are missing (RFC-025b): empties the `icon` of every creature, spell and
## ability type and the pictures of the CueSet (cursors, order icons, refusal icon) in memory, and swaps the roster for a fresh copy of
## its own scene, as if the types had no icon assigned. The files are not touched; `restore_cache` puts the pictures back. The product has
## no reload API: the copy is built from `scene_file_path` after the icons changed.
##
##   hide_cache()    every type icon and every CueSet picture -> null; new roster.
##   restore_cache() the real pictures again; new roster.
##   silence_roster() hides and freezes the roster (baseline runs of older flows).

var _icons: Dictionary = {}
var _aim: Dictionary = {}
var _refused: Texture2D
var _free: Dictionary = {}
var _target: Dictionary = {}
var _hud_cursor: Texture2D
var _hidden := false


func hide_cache() -> String:
	if not _hidden:
		_hidden = true
		var catalog := GameCatalog.shared()
		for list: Array in [catalog.creatures, catalog.spells, catalog.abilities]:
			for type: Resource in list:
				_icons[type] = type.get("icon")
				type.set("icon", null)
		var cues := _cues()
		if cues != null:
			_aim = cues.aim_icons.duplicate()
			_refused = cues.refused_icon
			_free = cues.free_cursors.duplicate()
			_target = cues.target_cursors.duplicate()
			_hud_cursor = cues.hud_cursor
			cues.aim_icons.clear()
			cues.refused_icon = null
			cues.free_cursors.clear()
			cues.target_cursors.clear()
			cues.hud_cursor = null
	return _swap()


func restore_cache() -> String:
	if _hidden:
		_hidden = false
		for type: Resource in _icons:
			type.set("icon", _icons[type])
		_icons.clear()
		var cues := _cues()
		if cues != null:
			cues.aim_icons.assign(_aim)
			cues.refused_icon = _refused
			cues.free_cursors.assign(_free)
			cues.target_cursors.assign(_target)
			cues.hud_cursor = _hud_cursor
	return _swap()


func _cues() -> CueSet:
	var battle := get_tree().current_scene.find_child("Battle", true, false) as CommandLog
	return battle.cues if battle else null


func _swap() -> String:
	var old := get_tree().current_scene.find_child("SelectionRoster", true, false) as SelectionRoster
	if old == null:
		return "no roster"
	var parent := old.get_parent()
	var fresh := (load(old.scene_file_path) as PackedScene).instantiate() as SelectionRoster
	fresh.selection = old.selection
	var owner_node := old.owner
	parent.remove_child(old)
	old.queue_free()
	fresh.name = "SelectionRoster"
	parent.add_child(fresh)
	fresh.owner = owner_node
	fresh.unique_name_in_owner = true
	return "ok"


## Takes the roster out of the game without freeing it (no input, no refresh): to tell a failure of
## the panel from an older one in the same flow. The selection keeps feeding its `count`.
func silence_roster() -> String:
	var roster := get_tree().current_scene.find_child("SelectionRoster", true, false) as SelectionRoster
	if roster == null:
		return "no roster"
	roster.visible = false
	roster.process_mode = Node.PROCESS_MODE_DISABLED
	return "ok"
