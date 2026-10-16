extends Node

## Optional autoload. Idle unless `--agent=` is present. Survives scene changes.

const Cli := preload("res://addons/agent_kit/agent_cli.gd")
const Ops := preload("res://addons/agent_kit/agent_ops.gd")
const Flow := preload("res://addons/agent_kit/agent_flow.gd")
const Fetch := preload("res://addons/agent_kit/agent_fetch.gd")
const Diff := preload("res://addons/agent_kit/agent_diff.gd")
const LogSink := preload("res://addons/agent_kit/agent_log.gd")
const Workspace := preload("res://addons/agent_kit/agent_workspace.gd")

var _exit_code: int = 0
var _sink


func _init() -> void:
	var verb := str(Cli.value("agent")).strip_edges()
	if verb.is_empty():
		return
	_sink = LogSink.new()
	LogSink.active = _sink
	OS.add_logger(_sink)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var cmd: Dictionary = Cli.parse()
	var verb := str(cmd.get("verb", "")).strip_edges()
	if verb.is_empty():
		return
	call_deferred("_run", cmd)


func _run(cmd: Dictionary) -> void:
	Workspace.ensure_dirs()
	var harness_err := Workspace.mount(self)
	if not harness_err.is_empty():
		print("AGENT_FAIL harness ", harness_err)
		_exit_code = 1
		_finish()
		return
	var verb := str(cmd.get("verb", "")).strip_edges().to_lower()
	match verb:
		"help", "h":
			print(Cli.help_text())
			_exit_code = 0
		"info":
			_exit_code = _info()
		"capture":
			_exit_code = await _capture(cmd)
		"flow":
			_exit_code = await _flow(cmd)
		"fetch":
			_exit_code = await _fetch(cmd)
		"inspect":
			_exit_code = await _inspect(cmd)
		"diff":
			_exit_code = _diff(cmd)
		_:
			push_error("AgentKit: unknown --agent=%s" % verb)
			print("AGENT_FAIL unknown_verb ", verb)
			_exit_code = 2
	_finish()


func _finish() -> void:
	if Engine.is_editor_hint():
		return
	_dump_errors()
	if _sink != null:
		OS.remove_logger(_sink)
		LogSink.active = null
	get_tree().quit(_exit_code)


func _dump_errors() -> void:
	if _sink == null:
		return
	print("AGENT_ERRORS ", JSON.stringify(_sink.snapshot()))


func _ok(verb: String, detail: String = "") -> int:
	if detail.is_empty():
		print("AGENT_OK ", verb)
	else:
		print("AGENT_OK ", verb, " ", detail)
	return 0


func _fail(verb: String, reason: String) -> int:
	print("AGENT_FAIL ", verb, " ", reason)
	return 1


func _info() -> int:
	var payload := {
		"godot": Engine.get_version_info(),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"viewport": DisplayServer.window_get_size(),
		"headless": Ops.is_headless(),
		"scene": get_tree().current_scene.name if get_tree().current_scene else "",
		"os": OS.get_name(),
		"actions": Ops.input_action_names(),
		"workspace": Workspace.ROOT,
		"flows": Workspace.FLOWS,
		"harness": Workspace.list_harness_names(),
	}
	print("AGENT_JSON ", JSON.stringify(payload))
	return _ok("info")


func _goto_scene(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if not ResourceLoader.exists(trimmed):
		return "missing scene %s" % trimmed
	var err := get_tree().change_scene_to_file(trimmed)
	if err != OK:
		return "change_scene failed (%d)" % err
	return ""


func _settle(wait_s: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if wait_s > 0.0:
		await get_tree().create_timer(wait_s).timeout
	await get_tree().process_frame
	if not Ops.is_headless():
		await RenderingServer.frame_post_draw


func _capture(cmd: Dictionary) -> int:
	if Ops.is_headless():
		return _fail("capture", "need a window (do not pass --headless)")
	var err := _goto_scene(str(cmd.get("scene", "")))
	if not err.is_empty():
		return _fail("capture", err)
	await _settle(Cli.wait_seconds(cmd))
	var out := str(cmd.get("out", "")).strip_edges()
	if out.is_empty():
		out = Workspace.OUT.path_join("capture.png")
	var shot_err: String = Ops.screenshot(get_tree(), out)
	if not shot_err.is_empty():
		return _fail("capture", shot_err)
	if bool(cmd.get("fail_on_error", false)) and _sink != null and _sink.has_failures():
		return _fail("capture", "engine errors during capture")
	return _ok("capture", Ops.fs_path(out))


func _flow(cmd: Dictionary) -> int:
	if Ops.is_headless():
		return _fail("flow", "need a window (do not pass --headless)")
	var flow_path := str(cmd.get("flow", "")).strip_edges()
	if flow_path.is_empty():
		return _fail("flow", "missing --flow=")
	var fs: String = Workspace.resolve_flow_path(flow_path)
	if fs.is_empty() or not FileAccess.file_exists(fs):
		return _fail("flow", "missing file %s (expected res://agent/flows/)" % flow_path)
	var raw := FileAccess.get_file_as_string(fs)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("flow", "JSON root must be an object")
	var out := str(cmd.get("out", "")).strip_edges()
	if out.is_empty():
		out = Workspace.OUT
	var runner: RefCounted = Flow.new()
	var fail: String = await runner.run(
		get_tree(), parsed, out, bool(cmd.get("fail_on_error", false))
	)
	if not fail.is_empty():
		return _fail("flow", fail)
	if bool(cmd.get("fail_on_error", false)) and _sink != null and _sink.has_failures():
		return _fail("flow", "engine errors during flow")
	var shown := out
	if out.begins_with("res://") or out.begins_with("user://"):
		shown = ProjectSettings.globalize_path(out)
	return _ok("flow", shown)


func _fetch(cmd: Dictionary) -> int:
	var fail: String = await Fetch.request(
		self,
		str(cmd.get("url", "")),
		str(cmd.get("out", "")),
		str(cmd.get("method", "GET")),
		str(cmd.get("ua", Cli.DEFAULT_UA))
	)
	if not fail.is_empty():
		return _fail("fetch", fail)
	return _ok("fetch", Ops.fs_path(str(cmd.get("out", ""))))


func _inspect(cmd: Dictionary) -> int:
	var err := _goto_scene(str(cmd.get("scene", "")))
	if not err.is_empty():
		return _fail("inspect", err)
	await _settle(Cli.wait_seconds(cmd))
	var scene := get_tree().current_scene
	if scene == null:
		return _fail("inspect", "no current scene")
	var focus := scene
	var node_spec := str(cmd.get("node", "")).strip_edges()
	if not node_spec.is_empty():
		focus = Ops.resolve(scene, node_spec)
		if focus == null:
			return _fail("inspect", "missing node %s" % node_spec)
	if cmd.get("unique", false):
		for line in Ops.dump_unique(focus):
			print("AGENT_UNIQUE ", line)
		print("AGENT_JSON ", JSON.stringify({"unique": Ops.unique_records(focus)}))
	else:
		for line in Ops.dump_tree(focus):
			print("AGENT_TREE ", line)
	return _ok("inspect", focus.name)


func _diff(cmd: Dictionary) -> int:
	var fail: String = Diff.compare(
		str(cmd.get("a", "")),
		str(cmd.get("b", "")),
		str(cmd.get("out", "")),
		Cli.threshold(cmd)
	)
	if not fail.is_empty():
		return _fail("diff", fail)
	return _ok("diff", Ops.fs_path(str(cmd.get("out", ""))))
