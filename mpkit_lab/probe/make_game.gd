extends SceneTree

## Lab tool: writes a fresh game with the setup wizard into res://generated (deleted first), as the editor's
## "MpKit: Setup game..." would. `-- --wizard-3d` for 3D. Prints the plan and WIZARD OK / WIZARD FAIL.
## The kit is loaded after the first frame (like the test runner): its scripts name the MpKit autoload.


func _initialize() -> void:
	await process_frame
	var folder := "res://generated"
	var dir := ProjectSettings.globalize_path(folder)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
	var wizard: Object = (load("res://addons/mp_kit/editor/mp_setup_wizard.gd") as GDScript).new()
	wizard.set("folder", folder)
	wizard.set("dimension_3d", OS.get_cmdline_user_args().has("--wizard-3d"))
	wizard.set("max_players", 4)
	print(wizard.call("plan_text"))
	var err: int = wizard.call("write")
	print("WIZARD OK" if err == OK else "WIZARD FAIL %s" % error_string(err))
	quit(0 if err == OK else 1)
