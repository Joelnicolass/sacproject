@tool
extends EditorPlugin

const AUTOLOAD_NAME := "MpKit"
const AUTOLOAD_PATH := "res://addons/mp_kit/mp_kit.gd"
const SNIPPETS_SRC := "res://addons/mp_kit/editor/mpkit.code-snippets"
const TEMPLATES_SRC := "res://addons/mp_kit/script_templates"
const Scaffold := preload("res://addons/mp_kit/mp_feature_scaffold.gd")

var _dialog: AcceptDialog
var _name_edit: LineEdit
var _folder_edit: LineEdit
var _base_option: OptionButton
var _pipe_check: CheckBox
var _flow_dialog: AcceptDialog
var _flow_autoload: LineEdit
var _flow_path: LineEdit
var _flow_boot: LineEdit
var _flow_world: LineEdit
var _flow_start: OptionButton


func _enter_tree() -> void:
	add_tool_menu_item("MpKit: Wire replication on selection", _on_wire_replication)
	add_tool_menu_item("MpKit: New replicated feature...", _on_new_feature)
	add_tool_menu_item("MpKit: New session flow...", _on_new_flow)
	add_tool_menu_item("MpKit: Install Cursor/VS Code snippets", _on_install_snippets)
	_ensure_script_templates()


func _exit_tree() -> void:
	remove_tool_menu_item("MpKit: Wire replication on selection")
	remove_tool_menu_item("MpKit: New replicated feature...")
	remove_tool_menu_item("MpKit: New session flow...")
	remove_tool_menu_item("MpKit: Install Cursor/VS Code snippets")
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	if _flow_dialog:
		_flow_dialog.queue_free()
		_flow_dialog = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _on_wire_replication() -> void:
	var edited := EditorInterface.get_edited_scene_root()
	if edited == null:
		push_warning("MpKit: open a scene first")
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		push_warning("MpKit: select the actor node")
		return
	var ur := get_undo_redo()
	ur.create_action("MpKit: wire replication")
	for node in selected:
		if node.get_node_or_null("MpReplicate") != null:
			continue
		var replicate := Node.new()
		replicate.name = "MpReplicate"
		replicate.set_script(load("res://addons/mp_kit/mp_replicate.gd"))
		ur.add_do_method(node, "add_child", replicate)
		ur.add_do_method(replicate, "set_owner", edited)
		ur.add_undo_method(node, "remove_child", replicate)
		ur.add_do_reference(replicate)
		if node.get_node_or_null("MultiplayerSynchronizer") == null:
			var sync := MultiplayerSynchronizer.new()
			sync.name = "MultiplayerSynchronizer"
			sync.replication_config = _default_replication(replicate)
			ur.add_do_method(node, "add_child", sync)
			ur.add_do_method(sync, "set_owner", edited)
			ur.add_undo_method(node, "remove_child", sync)
			ur.add_do_reference(sync)
	ur.commit_action()


## MpReplicate.sync_properties as spawn + always, like the README table.
func _default_replication(replicate: Node) -> SceneReplicationConfig:
	var cfg := SceneReplicationConfig.new()
	for property in replicate.get("sync_properties"):
		var path := NodePath(property)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return cfg


func _on_new_feature() -> void:
	if _dialog == null:
		_build_dialog()
	_dialog.popup_centered()


func _build_dialog() -> void:
	_dialog = AcceptDialog.new()
	_dialog.title = "MpKit: new replicated feature"
	_dialog.ok_button_text = "Create"
	var box := VBoxContainer.new()
	box.add_child(_label("Feature id (snake_case)"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "dash_attack"
	box.add_child(_name_edit)
	box.add_child(_label("Folder (res://)"))
	_folder_edit = LineEdit.new()
	_folder_edit.text = "res://features"
	box.add_child(_folder_edit)
	box.add_child(_label("Root node"))
	_base_option = OptionButton.new()
	_base_option.add_item("CharacterBody2D")
	_base_option.add_item("CharacterBody3D")
	_base_option.add_item("Node2D")
	_base_option.add_item("Node3D")
	box.add_child(_base_option)
	_pipe_check = CheckBox.new()
	_pipe_check.text = "Include MpCustomPipe (Dictionary tunnel)"
	box.add_child(_pipe_check)
	_dialog.add_child(box)
	_dialog.confirmed.connect(_on_dialog_confirmed)
	add_child(_dialog)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_dialog_confirmed() -> void:
	var id := Scaffold.sanitize_id(_name_edit.text)
	if id.is_empty():
		push_warning("MpKit: invalid feature id")
		return
	var folder := _folder_edit.text.strip_edges()
	if folder.is_empty():
		folder = "res://features"
	if not folder.begins_with("res://"):
		folder = "res://".path_join(folder)
	var res_dir := folder.path_join(id)
	var base := _base_option.get_item_text(_base_option.selected)
	var err := Scaffold.write_feature(res_dir, id, base, _pipe_check.button_pressed)
	if err != OK:
		push_error("MpKit: could not write feature (%s)" % err)
		return
	var fs := EditorInterface.get_resource_filesystem()
	var gd_path := res_dir.path_join("%s.gd" % id)
	var tscn := res_dir.path_join("%s.tscn" % id)
	if fs.has_method("update_file"):
		fs.call("update_file", gd_path)
		fs.call("update_file", tscn)
	else:
		fs.scan()
	EditorInterface.open_scene_from_path(tscn)


func _on_new_flow() -> void:
	if _flow_dialog == null:
		_build_flow_dialog()
	_flow_dialog.popup_centered()


func _build_flow_dialog() -> void:
	_flow_dialog = AcceptDialog.new()
	_flow_dialog.title = "MpKit: new session flow"
	_flow_dialog.ok_button_text = "Create"
	var box := VBoxContainer.new()
	box.add_child(_label("Autoload name"))
	_flow_autoload = LineEdit.new()
	_flow_autoload.text = "MpFlow"
	box.add_child(_flow_autoload)
	box.add_child(_label("Scene (res://)"))
	_flow_path = LineEdit.new()
	_flow_path.text = "res://glue/session_flow.tscn"
	box.add_child(_flow_path)
	box.add_child(_label("Boot scene path"))
	_flow_boot = LineEdit.new()
	_flow_boot.placeholder_text = "res://scenes/ui/boot.tscn"
	box.add_child(_flow_boot)
	box.add_child(_label("World scene path"))
	_flow_world = LineEdit.new()
	_flow_world.placeholder_text = "res://scenes/world/match.tscn"
	box.add_child(_flow_world)
	box.add_child(_label("Dedicated start"))
	_flow_start = OptionButton.new()
	_flow_start.add_item("Listen host enters world now")
	_flow_start.add_item("Dedicated starts on first client")
	_flow_start.selected = 1
	box.add_child(_flow_start)
	_flow_dialog.add_child(box)
	_flow_dialog.confirmed.connect(_on_flow_confirmed)
	add_child(_flow_dialog)


func _on_flow_confirmed() -> void:
	var autoload_name := _flow_autoload.text.strip_edges()
	if autoload_name.is_empty():
		autoload_name = "MpFlow"
	var tscn := _flow_path.text.strip_edges()
	if tscn.is_empty():
		tscn = "res://glue/session_flow.tscn"
	if not tscn.begins_with("res://"):
		tscn = "res://".path_join(tscn)
	if not tscn.ends_with(".tscn"):
		tscn += ".tscn"
	var start_when := 1 if _flow_start.selected >= 1 else 0
	var err := Scaffold.write_flow(
		tscn,
		_flow_boot.text.strip_edges(),
		_flow_world.text.strip_edges(),
		start_when
	)
	if err != OK:
		push_error("MpKit: could not write session flow (%s)" % err)
		return
	if ProjectSettings.has_setting("autoload/%s" % autoload_name):
		push_warning("MpKit: autoload '%s' already exists — assign boot/world on %s" % [autoload_name, tscn])
	else:
		add_autoload_singleton(autoload_name, tscn)
	var fs := EditorInterface.get_resource_filesystem()
	var gd_path := tscn.get_basename() + ".gd"
	if fs.has_method("update_file"):
		fs.call("update_file", gd_path)
		fs.call("update_file", tscn)
	else:
		fs.scan()
	EditorInterface.open_scene_from_path(tscn)


func _on_install_snippets() -> void:
	var dest_dir := ProjectSettings.globalize_path("res://.vscode")
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var src := ProjectSettings.globalize_path(SNIPPETS_SRC)
	var dest := dest_dir.path_join("mpkit.code-snippets")
	var err := DirAccess.copy_absolute(src, dest)
	if err != OK:
		push_error("MpKit: snippet copy failed (%s)" % err)
		return
	print("MpKit: wrote %s — reload the Cursor/VS Code window" % dest)


func _ensure_script_templates() -> void:
	var dest_root := ProjectSettings.globalize_path("res://script_templates")
	var src_root := ProjectSettings.globalize_path(TEMPLATES_SRC)
	if not DirAccess.dir_exists_absolute(src_root):
		return
	_copy_dir(src_root, dest_root)
	var ignore := dest_root.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f:
			f.store_string("")
			f.close()


func _copy_dir(src: String, dest: String) -> void:
	DirAccess.make_dir_recursive_absolute(dest)
	var dir := DirAccess.open(src)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var from_path := src.path_join(name)
		var to_path := dest.path_join(name)
		if dir.current_is_dir():
			_copy_dir(from_path, to_path)
		elif not FileAccess.file_exists(to_path):
			DirAccess.copy_absolute(from_path, to_path)
		name = dir.get_next()
	dir.list_dir_end()
