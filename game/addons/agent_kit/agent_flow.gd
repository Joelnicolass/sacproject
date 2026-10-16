class_name AgentFlow
extends RefCounted

const Ops := preload("res://addons/agent_kit/agent_ops.gd")
const Diff := preload("res://addons/agent_kit/agent_diff.gd")
const LogSink := preload("res://addons/agent_kit/agent_log.gd")

var _fail_on_error: bool = false
var _time_scale_prev: float = 1.0


func run(tree: SceneTree, spec: Dictionary, out_dir: String, fail_on_error: bool = false) -> String:
	_fail_on_error = fail_on_error
	_time_scale_prev = Engine.time_scale
	var result := await _run_body(tree, spec, out_dir)
	Engine.time_scale = _time_scale_prev
	return result


func _run_body(tree: SceneTree, spec: Dictionary, out_dir: String) -> String:
	var scene_path := str(spec.get("scene", "")).strip_edges()
	if not scene_path.is_empty():
		var err := tree.change_scene_to_file(scene_path)
		if err != OK:
			return "change_scene %s failed (%d)" % [scene_path, err]
		await tree.process_frame
		await tree.process_frame
	var wait_first := float(spec.get("wait_first", 0.8))
	if wait_first > 0.0:
		await tree.create_timer(wait_first).timeout
	var dest := out_dir.strip_edges()
	if dest.is_empty():
		dest = "res://agent/out"
	Ops.ensure_parent_dir(dest.path_join("dummy.png"))
	var steps: Variant = spec.get("steps", [])
	if typeof(steps) != TYPE_ARRAY:
		return "flow.steps must be an array"
	var index := 0
	for raw in steps:
		index += 1
		if typeof(raw) != TYPE_DICTIONARY:
			return "step %d is not an object" % index
		var fail := await _step(tree, raw, dest, index)
		if not fail.is_empty():
			return fail
	return ""


func _step(tree: SceneTree, step: Dictionary, dest: String, index: int, allow_skip: bool = false) -> String:
	var mark := 0
	if LogSink.active != null:
		mark = LogSink.active.mark()
	print("AGENT_STEP ", index, " ", _step_label(step))
	var fail := await _dispatch(tree, step, dest, index, allow_skip)
	_trace_errors(index, mark)
	if fail.is_empty() and _fail_on_error and _failures_since(mark):
		return "engine error during step %d" % index
	return fail


func _dispatch(tree: SceneTree, step: Dictionary, dest: String, index: int, allow_skip: bool = false) -> String:
	var scene := Ops.current_scene(tree)
	if step.has("wait"):
		await tree.create_timer(float(step["wait"])).timeout
		return ""
	if step.has("scene"):
		return await _change_scene(tree, str(step["scene"]))
	if step.has("seed") or step.has("time_scale"):
		return "seed and time_scale are not player actions"
	if step.has("shot") or step.has("screenshot"):
		return await _shot(tree, scene, step, dest, index)
	if step.has("click"):
		return await Ops.click(scene, str(step["click"]), false)
	if step.has("press"):
		return await _press(tree, step["press"])
	if step.has("try_click"):
		return await Ops.click(scene, str(step["try_click"]), allow_skip)
	if step.has("repeat"):
		return await _repeat(tree, step["repeat"], dest, index)
	if step.has("type"):
		var spec: Variant = step["type"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "type step must be {node, text}"
		return Ops.type_in(scene, str(spec.get("node", "")), str(spec.get("text", "")))
	if step.has("select"):
		var spec: Variant = step["select"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "select step must be {node, index|text}"
		return Ops.select_item(scene, spec)
	if step.has("range"):
		var spec: Variant = step["range"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "range step must be {node, value}"
		return Ops.set_range_value(scene, spec)
	if step.has("scroll"):
		var spec: Variant = step["scroll"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "scroll step must be {node, vertical?, horizontal?}"
		return Ops.scroll_to(scene, spec)
	if step.has("drag"):
		var spec: Variant = step["drag"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "drag step must be {node, from_x, from_y, to_x, to_y}"
		return Ops.drag_control(scene, spec)
	if step.has("call"):
		var spec: Variant = step["call"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "call step must be {node, method, args?}"
		return Ops.call_method(scene, spec)
	if step.has("diff"):
		return _diff_step(dest, step["diff"])
	if step.has("print"):
		var spec: Variant = step["print"]
		if typeof(spec) != TYPE_DICTIONARY:
			return "print step must be {node, prop}"
		var node := Ops.resolve(scene, str(spec.get("node", "")))
		if node == null:
			return "print missing %s" % str(spec.get("node", ""))
		var value := Ops.read_prop(node, str(spec.get("prop", "name")))
		print(
			"AGENT_PRINT node=%s prop=%s value=%s"
			% [spec.get("node", ""), spec.get("prop", ""), Ops.stringify_variant(value)]
		)
		return ""
	if step.has("assert"):
		return _assert(scene, step["assert"], index)
	if step.has("wait_until"):
		return await _wait_until(tree, scene, step["wait_until"])
	return "unknown step keys in %d: %s" % [index, str(step.keys())]


func _step_label(step: Dictionary) -> String:
	var keys: Array = step.keys()
	if keys.is_empty():
		return "empty"
	return str(keys[0])


func _trace_errors(index: int, mark: int) -> void:
	if LogSink.active == null:
		return
	for rec in LogSink.active.since(mark):
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		if not LogSink.is_failure(rec):
			continue
		print("AGENT_STEP_ERROR ", index, " ", rec.get("text", ""))


func _failures_since(mark: int) -> bool:
	if LogSink.active == null:
		return false
	for rec in LogSink.active.since(mark):
		if typeof(rec) == TYPE_DICTIONARY and LogSink.is_failure(rec):
			return true
	return false


func _change_scene(tree: SceneTree, path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return "scene step missing path"
	if not ResourceLoader.exists(trimmed):
		return "missing scene %s" % trimmed
	var err := tree.change_scene_to_file(trimmed)
	if err != OK:
		return "change_scene %s failed (%d)" % [trimmed, err]
	await tree.process_frame
	await tree.process_frame
	print("AGENT_SCENE ", trimmed)
	return ""


func _shot(tree: SceneTree, scene: Node, step: Dictionary, dest: String, index: int) -> String:
	var raw: Variant = step.get("shot", step.get("screenshot", ""))
	var name := ""
	var focus: Node = null
	if typeof(raw) == TYPE_DICTIONARY:
		name = str(raw.get("name", raw.get("shot", "")))
		var node_spec := str(raw.get("node", "")).strip_edges()
		if not node_spec.is_empty():
			focus = Ops.resolve(scene, node_spec)
			if focus == null:
				return "shot missing %s" % node_spec
	else:
		name = str(raw)
	if name.is_empty():
		name = "%02d.png" % index
	if not name.ends_with(".png"):
		name += ".png"
	var path := dest.path_join(name)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var shot_err := Ops.screenshot(tree, path, focus)
	if not shot_err.is_empty():
		return "shot %s: %s" % [name, shot_err]
	print("AGENT_SHOT=", Ops.fs_path(path))
	return ""


func _press(tree: SceneTree, spec: Variant) -> String:
	if typeof(spec) == TYPE_STRING:
		return Ops.press_action(str(spec))
	if typeof(spec) != TYPE_DICTIONARY:
		return "press step must be a StringName or {name, pressed, hold}"
	var name := str(spec.get("name", ""))
	var hold := float(spec.get("hold", 0.0))
	if hold > 0.0:
		var down := Ops.press_action(name, true)
		if not down.is_empty():
			return down
		var left := hold
		while left > 0.0:
			await tree.physics_frame
			left -= tree.root.get_physics_process_delta_time()
			if left > 0.0:
				Ops.sustain_action(name)
		return Ops.press_action(name, false)
	return Ops.press_action(name, bool(spec.get("pressed", true)))


func _diff_step(dest: String, spec: Variant) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "diff step must be {a, b, out?, threshold?, max_percent?}"
	var path_a := _resolve_shot_path(dest, str(spec.get("a", "")))
	var path_b := _resolve_shot_path(dest, str(spec.get("b", "")))
	var out := str(spec.get("out", "diff.png"))
	if not out.is_absolute_path() and not out.begins_with("res://") and not out.begins_with("user://"):
		out = dest.path_join(out)
	var stats := {}
	var fail: String = Diff.compare(path_a, path_b, out, float(spec.get("threshold", 0.02)), stats)
	if not fail.is_empty():
		return fail
	var max_percent := float(spec.get("max_percent", 0.0))
	var percent := float(stats.get("percent", 0.0))
	if percent > max_percent:
		return "diff percent=%.3f > max_percent=%.3f" % [percent, max_percent]
	return ""


func _resolve_shot_path(dest: String, name: String) -> String:
	var trimmed := name.strip_edges()
	if trimmed.is_empty():
		return ""
	if (
		trimmed.begins_with("/")
		or trimmed.begins_with("res://")
		or trimmed.begins_with("user://")
	):
		return Ops.fs_path(trimmed)
	return dest.path_join(trimmed)


func _contains_try_click(steps: Variant) -> bool:
	if typeof(steps) != TYPE_ARRAY:
		return false
	for raw in steps:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if (raw as Dictionary).has("try_click"):
			return true
		if (raw as Dictionary).has("repeat"):
			var nested: Variant = (raw as Dictionary)["repeat"]
			if typeof(nested) == TYPE_DICTIONARY and _contains_try_click(nested.get("steps", [])):
				return true
	return false


func _repeat(tree: SceneTree, spec: Variant, dest: String, index: int) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "repeat %d must be an object" % index
	var times := maxi(1, int(spec.get("times", 1)))
	var until: Variant = spec.get("until", {})
	var has_until := typeof(until) == TYPE_DICTIONARY and not (until as Dictionary).is_empty()
	var inner: Variant = spec.get("steps", [])
	if typeof(inner) != TYPE_ARRAY:
		return "repeat.steps must be an array"
	if _contains_try_click(inner) and not has_until:
		return "try_click inside repeat requires until"
	var last := ""
	var scene: Node = null
	for i in times:
		scene = Ops.current_scene(tree)
		if has_until:
			last = _assert(scene, until, index)
			if last.is_empty():
				print("AGENT_REPEAT done iter=%d" % i)
				return ""
		for raw in inner:
			if typeof(raw) != TYPE_DICTIONARY:
				return "repeat step is not an object"
			var fail := await _step(tree, raw, dest, index, has_until)
			if not fail.is_empty():
				return fail
	scene = Ops.current_scene(tree)
	if typeof(until) == TYPE_DICTIONARY and not (until as Dictionary).is_empty():
		last = _assert(scene, until, index)
		if last.is_empty():
			print("AGENT_REPEAT done iter=%d" % times)
			return ""
		return "repeat exhausted: %s" % last
	return ""


func _assert_expects_absent(spec: Dictionary) -> bool:
	var saw_absence := false
	for key in spec.keys():
		var name := str(key)
		if name == "node":
			continue
		if (name == "visible_in_tree" or name == "visible") and not bool(spec[key]):
			saw_absence = true
			continue
		return false
	return saw_absence


func _assert(scene: Node, spec: Variant, index: int) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "assert %d must be an object" % index
	var node := Ops.resolve(scene, str(spec.get("node", "")))
	if node == null:
		if _assert_expects_absent(spec):
			print("AGENT_ASSERT ok step=%d node=%s" % [index, spec.get("node", "")])
			return ""
		return "assert missing %s" % str(spec.get("node", ""))
	if spec.has("disabled"):
		if not (node is BaseButton):
			return "assert disabled: %s is not a button" % node.name
		var want := bool(spec["disabled"])
		if (node as BaseButton).disabled != want:
			return "assert disabled want=%s got=%s" % [want, (node as BaseButton).disabled]
	if spec.has("visible"):
		if node is CanvasItem:
			var want_vis := bool(spec["visible"])
			if (node as CanvasItem).visible != want_vis:
				return "assert visible want=%s got=%s" % [want_vis, (node as CanvasItem).visible]
	if spec.has("visible_in_tree"):
		if not (node is Node):
			return "assert visible_in_tree: missing node"
		var want_tree := bool(spec["visible_in_tree"])
		var in_tree := false
		if node is CanvasItem:
			in_tree = (node as CanvasItem).is_visible_in_tree()
		else:
			in_tree = node.is_inside_tree()
		if in_tree != want_tree:
			return "assert visible_in_tree want=%s got=%s" % [want_tree, in_tree]
	if spec.has("text_contains"):
		var text := _node_text(node)
		var needle := str(spec["text_contains"])
		if not text.contains(needle):
			return "assert text_contains %s not in %s" % [needle, text]
	if spec.has("text_equals"):
		var text := _node_text(node)
		var want := str(spec["text_equals"])
		if text != want:
			return "assert text_equals want=%s got=%s" % [want, text]
	if spec.has("prop"):
		var prop_fail := _assert_prop(node, spec)
		if not prop_fail.is_empty():
			return prop_fail
	if spec.has("texture_path_contains"):
		var tex_path := ""
		if node is TextureRect and (node as TextureRect).texture != null:
			tex_path = (node as TextureRect).texture.resource_path
		var needle := str(spec["texture_path_contains"])
		if not tex_path.contains(needle):
			return "assert texture_path_contains %s not in %s" % [needle, tex_path]
	print("AGENT_ASSERT ok step=%d node=%s" % [index, spec.get("node", "")])
	return ""


## Generic property assert: {node, prop, equals|gte|lte|contains}. `prop` may be dotted.
func _assert_prop(node: Node, spec: Dictionary) -> String:
	var prop := str(spec["prop"])
	var value: Variant = Ops.read_prop(node, prop)
	var checked := false
	if spec.has("equals"):
		checked = true
		var want: Variant = spec["equals"]
		var same := false
		if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and (typeof(want) == TYPE_INT or typeof(want) == TYPE_FLOAT):
			same = is_equal_approx(float(value), float(want))
		else:
			same = str(value) == str(want)
		if not same:
			return "assert prop %s equals want=%s got=%s" % [prop, str(want), str(value)]
	if spec.has("gte"):
		checked = true
		if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) or float(value) < float(spec["gte"]):
			return "assert prop %s gte want=%s got=%s" % [prop, str(spec["gte"]), str(value)]
	if spec.has("lte"):
		checked = true
		if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) or float(value) > float(spec["lte"]):
			return "assert prop %s lte want=%s got=%s" % [prop, str(spec["lte"]), str(value)]
	if spec.has("contains"):
		checked = true
		if not str(value).contains(str(spec["contains"])):
			return "assert prop %s contains %s not in %s" % [prop, str(spec["contains"]), str(value)]
	if not checked:
		return "assert prop %s needs equals, gte, lte or contains" % prop
	return ""


func _wait_until(tree: SceneTree, scene: Node, spec: Variant) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "wait_until must be an object"
	if spec.has("signal"):
		return await _wait_signal(tree, scene, spec)
	var timeout := float(spec.get("timeout", 5.0))
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	var probe: Dictionary = spec.duplicate()
	if probe.has("contains") and not probe.has("text_contains") and not probe.has("prop"):
		probe["text_contains"] = probe["contains"]
	probe.erase("timeout")
	var last := ""
	while Time.get_ticks_msec() < deadline:
		last = _assert(scene, probe, 0)
		if last.is_empty():
			return ""
		await tree.process_frame
		scene = Ops.current_scene(tree)
	return "wait_until timeout: %s" % last


func _wait_signal(tree: SceneTree, scene: Node, spec: Dictionary) -> String:
	var node := Ops.resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "wait_until missing %s" % str(spec.get("node", ""))
	var sig := StringName(str(spec.get("signal", "")).strip_edges())
	if String(sig).is_empty():
		return "wait_until signal missing name"
	if not node.has_signal(sig):
		return "wait_until missing signal %s on %s" % [sig, spec.get("node", "")]
	var timeout := float(spec.get("timeout", 5.0))
	var holder := [false]
	var cb := Callable(self, "_mark_holder").bind(holder)
	var err := node.connect(sig, cb, CONNECT_ONE_SHOT)
	if err != OK:
		return "wait_until connect %s failed (%d)" % [sig, err]
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if holder[0]:
			return ""
		await tree.process_frame
	if holder[0]:
		return ""
	if node.is_connected(sig, cb):
		node.disconnect(sig, cb)
	return "wait_until signal timeout: %s" % sig


func _mark_holder(
	holder: Array,
	_a: Variant = null,
	_b: Variant = null,
	_c: Variant = null,
	_d: Variant = null,
	_e: Variant = null,
	_f: Variant = null
) -> void:
	holder[0] = true


func _node_text(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	if node is RichTextLabel:
		return (node as RichTextLabel).get_parsed_text()
	if node is LineEdit:
		return (node as LineEdit).text
	if node is Button:
		return (node as Button).text
	return str(node.get("text"))
