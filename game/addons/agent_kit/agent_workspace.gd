class_name AgentWorkspace
extends RefCounted

## Host-project workspace. Not the addon. Never put playtest hooks in src/.

const ROOT := "res://agent"
const FLOWS := "res://agent/flows"
const HARNESS := "res://agent/harness"
const FIXTURES := "res://agent/fixtures"
const OUT := "res://agent/out"
const _FORCE_TOKENS: PackedStringArray = [
	"global_position",
	"velocity",
	"InputEventKey",
	"parse_input_event",
	"time_scale",
	".call(",
	"callv(",
	"translate(",
]


static func ensure_dirs() -> void:
	for res_dir in [ROOT, FLOWS, HARNESS, FIXTURES, OUT]:
		var abs_path := ProjectSettings.globalize_path(res_dir)
		DirAccess.make_dir_recursive_absolute(abs_path)


static func resolve_flow_path(flow_path: String) -> String:
	var trimmed := flow_path.strip_edges()
	if trimmed.is_empty():
		return ""
	var direct := _existing_fs(trimmed)
	if not direct.is_empty():
		return direct
	var name := trimmed.get_file()
	if name.is_empty():
		name = trimmed
	if not name.ends_with(".json"):
		name += ".json"
	return _existing_fs(FLOWS.path_join(name))


static func _existing_fs(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		var glob := ProjectSettings.globalize_path(trimmed)
		if FileAccess.file_exists(glob):
			return glob
		return ""
	if FileAccess.file_exists(trimmed):
		return trimmed
	return ""


static func list_harness_names() -> PackedStringArray:
	var names := PackedStringArray()
	var abs_path := ProjectSettings.globalize_path(HARNESS)
	if not DirAccess.dir_exists_absolute(abs_path):
		return names
	var dir := DirAccess.open(HARNESS)
	if dir == null:
		return names
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and file.ends_with(".gd"):
			names.append(file.get_basename())
		file = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


static func mount(host: Node) -> String:
	if host == null:
		return ""
	ensure_dirs()
	var abs_path := ProjectSettings.globalize_path(HARNESS)
	if not DirAccess.dir_exists_absolute(abs_path):
		return ""
	var dir := DirAccess.open(HARNESS)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and file.ends_with(".gd"):
			var violation := _harness_violation(HARNESS.path_join(file))
			if not violation.is_empty():
				dir.list_dir_end()
				return violation
			_mount_script(host, file)
		file = dir.get_next()
	dir.list_dir_end()
	return ""


static func _harness_violation(res_path: String) -> String:
	var text := FileAccess.get_file_as_string(res_path)
	for token in _FORCE_TOKENS:
		if text.contains(token):
			return "harness %s forces play (%s); use click or InputMap press" % [res_path, token]
	return ""


static func _mount_script(host: Node, file: String) -> void:
	var res_path := HARNESS.path_join(file)
	var script: Variant = load(res_path)
	if not (script is GDScript):
		print("AGENT_HARNESS skip ", res_path, " not GDScript")
		return
	var inst: Variant = (script as GDScript).new()
	if not (inst is Node):
		print("AGENT_HARNESS skip ", res_path, " must extend Node")
		return
	var node := inst as Node
	node.name = file.get_basename()
	host.add_child(node)
	print("AGENT_HARNESS ", node.name, " ", res_path)


static func harness_node(tree: SceneTree, name: String) -> Node:
	if tree == null:
		return null
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return null
	var kit := tree.root.get_node_or_null("AgentKit")
	if kit == null:
		return null
	return kit.get_node_or_null(NodePath(trimmed))
