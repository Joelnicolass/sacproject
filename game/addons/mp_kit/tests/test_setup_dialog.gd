extends "res://addons/mp_kit/tests/mp_test.gd"

## The Setup game dialog: its choices reach the wizard, and Create stays off when it would overwrite.


func test_choices_and_guard() -> void:
	var dialog: AcceptDialog = (load("res://addons/mp_kit/editor/mp_setup_dialog.gd") as GDScript).new()
	tree.root.add_child(dialog)
	var w: MpSetupWizard = dialog.call("wizard")
	check(w.folder == "res://game" and not w.dimension_3d and w.max_players == 4 and w.online_rooms, "the defaults")
	dialog.get("_dimension").select(1)
	dialog.get("_transport").select(1)
	dialog.get("_players").value = 8
	dialog.get("_rooms").button_pressed = false
	w = dialog.call("wizard")
	check(w.dimension_3d and w.transport == "ws" and w.max_players == 8 and not w.online_rooms, "the choices reach the wizard")
	dialog.get("_folder").text = "user://not_a_project_folder"
	dialog.call("_show_plan")
	check(dialog.get_ok_button().disabled, "Create is off outside res://")
	dialog.get("_folder").text = "res://addons/mp_kit/examples/arena_2d"
	dialog.call("_show_plan")
	check(String(dialog.get("_files").text).contains("[~]") and dialog.get_ok_button().disabled, "Create is off when a file exists")
	dialog.free()
