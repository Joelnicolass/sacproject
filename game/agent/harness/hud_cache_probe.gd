extends Node

## Playtest helper for RFC-025b «respaldo sin caché»: points HudIcons at an empty folder and swaps
## the roster for a fresh copy of its own scene, as on a clone without assets/original/ui. The product has
## no reload API: the copy is built from `scene_file_path` after the folders changed.
##
##   hide_cache()    HudIcons.icon_dir / hud_dir -> a folder with nothing; new roster.
##   restore_cache() the real folders again; new roster.
##   silence_roster() hides and freezes the roster (baseline runs of older flows).

const EMPTY := "res://agent/out/_no_assets/"


func hide_cache() -> String:
	HudIcons.icon_dir = EMPTY
	HudIcons.hud_dir = EMPTY
	HudIcons.cursor_dir = EMPTY
	HudIcons.xmenu_dir = EMPTY
	return _swap()


func restore_cache() -> String:
	HudIcons.icon_dir = HudIcons.ICON_DIR
	HudIcons.hud_dir = HudIcons.HUD_DIR
	HudIcons.cursor_dir = HudIcons.CURSOR_DIR
	HudIcons.xmenu_dir = HudIcons.XMENU_DIR
	return _swap()


func _swap() -> String:
	HudIcons.reset()
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
