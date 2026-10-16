class_name AgentOps
extends RefCounted

const Workspace := preload("res://addons/agent_kit/agent_workspace.gd")
# Underscore methods are callable (GDScript "_" is a convention, not runtime privacy).
const _BLOCKED_METHODS := ["free", "queue_free", "replace_by", "set_script"]


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func fs_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if (
		trimmed.begins_with("res://")
		or trimmed.begins_with("user://")
	):
		return ProjectSettings.globalize_path(trimmed)
	return trimmed


static func ensure_parent_dir(path: String) -> void:
	var abs_path := fs_path(path)
	var dir_path := abs_path.get_base_dir()
	if dir_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir_path)


static func current_scene(tree: SceneTree) -> Node:
	return tree.current_scene


static func resolve(from: Node, spec: String) -> Node:
	if from == null:
		return null
	var trimmed := spec.strip_edges()
	if trimmed.is_empty() or trimmed == ".":
		return from
	if trimmed.begins_with("/"):
		var tree := from.get_tree()
		if tree == null:
			return null
		return tree.root.get_node_or_null(NodePath(trimmed))
	if trimmed == "AgentKit" or trimmed.begins_with("AgentKit/"):
		var tree := from.get_tree()
		if tree == null:
			return null
		return tree.root.get_node_or_null(NodePath("/root/%s" % trimmed))
	var node := from
	for part in trimmed.split("/"):
		if part.is_empty():
			continue
		var next := node.get_node_or_null(NodePath(part))
		if next == null and part.begins_with("%"):
			next = find_unique(node, part.substr(1))
		if next == null:
			return null
		node = next
	return node


static func find_unique(from: Node, unique: String) -> Node:
	if from == null or unique.strip_edges().is_empty():
		return null
	if from.is_unique_name_in_owner() and from.name == unique:
		return from
	for child in from.get_children():
		var found := find_unique(child, unique)
		if found != null:
			return found
	return null


static func read_prop(object: Object, dotted: String) -> Variant:
	if object == null:
		return null
	var current: Variant = object
	for key in dotted.split("."):
		if current == null:
			return null
		if current is Object:
			current = (current as Object).get(key)
		else:
			return null
	return current


static func screenshot(tree: SceneTree, path: String, focus: Node = null) -> String:
	if is_headless():
		return "headless (need a window for pixels)"
	if path.strip_edges().is_empty():
		return "missing --out="
	ensure_parent_dir(path)
	var img := tree.root.get_viewport().get_texture().get_image()
	if img == null:
		return "viewport image is null"
	if focus is Control:
		var cropped := _crop_control(img, focus as Control)
		if cropped != null:
			img = cropped
	var err := img.save_png(fs_path(path))
	if err != OK:
		return "save_png failed (%d)" % err
	return ""


static func click(scene: Node, spec: String, allow_skip: bool = false) -> String:
	var node := resolve(scene, spec)
	if node != null and not (node is BaseButton):
		return "%s is %s, not a BaseButton" % [spec, node.get_class()]
	var button := node as BaseButton
	if button == null or button.disabled or not button.is_visible_in_tree():
		if allow_skip:
			print("AGENT_SKIP try_click ", spec)
			return ""
		return "click not ready %s" % spec
	return await _pointer_click(button, spec)


static func _pointer_click(button: BaseButton, spec: String) -> String:
	var rect := button.get_global_rect()
	if rect.size == Vector2.ZERO:
		return "click missed %s (control has no size)" % spec
	var tree := button.get_tree()
	if tree == null:
		return "click missed %s (control is not in the tree)" % spec
	var center := rect.get_center()
	var state := {"ok": false}
	var on_pressed := func() -> void:
		state["ok"] = true
	button.pressed.connect(on_pressed, CONNECT_ONE_SHOT)
	_push_mouse(button, center, true)
	await tree.process_frame
	if is_instance_valid(button):
		_push_mouse(button, center, false)
	await tree.process_frame
	if is_instance_valid(button) and button.pressed.is_connected(on_pressed):
		button.pressed.disconnect(on_pressed)
	if not bool(state["ok"]):
		return "click missed %s (pointer did not hit the control)" % spec
	print("AGENT_CLICK ", spec)
	return ""


static func _push_mouse(node: Node, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	var viewport := node.get_viewport()
	if viewport != null:
		viewport.push_input(ev)


static func type_in(scene: Node, spec: String, text: String) -> String:
	var node := resolve(scene, spec)
	if node == null:
		return "missing node %s" % spec
	if node is LineEdit:
		var edit := node as LineEdit
		edit.text = text
		edit.text_changed.emit(text)
		edit.text_submitted.emit(text)
		return ""
	if node is TextEdit:
		(node as TextEdit).text = text
		return ""
	return "%s is %s, not LineEdit/TextEdit" % [spec, node.get_class()]


static func dump_tree(node: Node, indent: int = 0) -> PackedStringArray:
	var lines := PackedStringArray()
	if node == null:
		return lines
	var mark := "%" if node.is_unique_name_in_owner() else ""
	lines.append("%s%s%s (%s)" % ["  ".repeat(indent), mark, node.name, node.get_class()])
	for child in node.get_children():
		lines.append_array(dump_tree(child, indent + 1))
	return lines


static func dump_unique(node: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	_collect_unique(node, lines)
	return lines


static func unique_records(node: Node) -> Array:
	var out: Array = []
	_collect_unique_records(node, out)
	return out


static func input_action_names() -> Array:
	var names: Array = []
	for action in InputMap.get_actions():
		names.append(String(action))
	names.sort()
	return names


static func press_action(action: String, pressed: bool = true, announce: bool = true) -> String:
	var name := action.strip_edges()
	var err := _check_action(name)
	if not err.is_empty():
		return err
	_emit_action_event(name, pressed)
	if pressed:
		Input.action_press(name)
	else:
		Input.action_release(name)
	if announce:
		print("AGENT_PRESS ", name, " pressed=", pressed)
	return ""


static func sustain_action(action: String) -> String:
	var name := action.strip_edges()
	var err := _check_action(name)
	if not err.is_empty():
		return err
	Input.action_press(name)
	return ""


static func _check_action(name: String) -> String:
	if name.is_empty():
		return "unmapped input: empty action (product bug; do not send keycodes)"
	if _looks_like_keycode(name):
		return "unmapped input: %s is a keycode, not an InputMap action (product bug)" % name
	if not InputMap.has_action(name):
		return "unmapped input: InputMap has no action '%s' (product bug; do not invent keys)" % name
	return ""


static func _emit_action_event(name: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = StringName(name)
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


static func _looks_like_keycode(name: String) -> bool:
	if name.begins_with("KEY_") or name.to_lower().begins_with("keycode"):
		return true
	return name.is_valid_int()


static func _collect_unique(node: Node, lines: PackedStringArray) -> void:
	if node == null:
		return
	if node.is_unique_name_in_owner():
		lines.append("%%%s\t%s\t%s" % [node.name, node.get_class(), str(node.get_path())])
	for child in node.get_children():
		_collect_unique(child, lines)


static func _collect_unique_records(node: Node, out: Array) -> void:
	if node == null:
		return
	if node.is_unique_name_in_owner():
		out.append({
			"unique": "%" + node.name,
			"class": node.get_class(),
			"path": str(node.get_path()),
			"click": node is BaseButton,
			"type": node is LineEdit or node is TextEdit,
			"select": node is ItemList or node is OptionButton,
			"range": node is Range,
			"scroll": node is ScrollContainer,
		})
	for child in node.get_children():
		_collect_unique_records(child, out)


static func stringify_variant(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Resource:
		var path := (value as Resource).resource_path
		if not path.is_empty():
			return path
	return str(value)


static func _crop_control(img: Image, control: Control) -> Image:
	var rect := control.get_global_rect()
	var crop := Rect2i(
		int(rect.position.x),
		int(rect.position.y),
		maxi(1, int(rect.size.x)),
		maxi(1, int(rect.size.y))
	)
	var bounds := Rect2i(0, 0, img.get_width(), img.get_height())
	crop = crop.intersection(bounds)
	if crop.size.x <= 0 or crop.size.y <= 0:
		return img
	return img.get_region(crop)


static func select_item(scene: Node, spec: Dictionary) -> String:
	var node := resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "missing node %s" % str(spec.get("node", ""))
	if node is ItemList:
		var list := node as ItemList
		var idx := _list_index(list, spec)
		if idx < 0:
			return "select: no matching item on %s" % spec.get("node", "")
		list.select(idx)
		list.item_selected.emit(idx)
		print("AGENT_SELECT ", spec.get("node", ""), " index=", idx)
		return ""
	if node is OptionButton:
		var opt := node as OptionButton
		var idx := _option_index(opt, spec)
		if idx < 0:
			return "select: no matching item on %s" % spec.get("node", "")
		opt.select(idx)
		opt.item_selected.emit(idx)
		print("AGENT_SELECT ", spec.get("node", ""), " index=", idx)
		return ""
	return "%s is %s, not ItemList/OptionButton" % [spec.get("node", ""), node.get_class()]


static func _list_index(list: ItemList, spec: Dictionary) -> int:
	if spec.has("index"):
		var idx := int(spec["index"])
		if idx >= 0 and idx < list.item_count:
			return idx
		return -1
	var needle := str(spec.get("text", "")).strip_edges()
	if needle.is_empty():
		return -1
	for i in list.item_count:
		if list.get_item_text(i) == needle:
			return i
	return -1


static func _option_index(opt: OptionButton, spec: Dictionary) -> int:
	if spec.has("index"):
		var idx := int(spec["index"])
		if idx >= 0 and idx < opt.item_count:
			return idx
		return -1
	var needle := str(spec.get("text", "")).strip_edges()
	if needle.is_empty():
		return -1
	for i in opt.item_count:
		if opt.get_item_text(i) == needle:
			return i
	return -1


static func set_range_value(scene: Node, spec: Dictionary) -> String:
	var node := resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "missing node %s" % str(spec.get("node", ""))
	if not (node is Range):
		return "%s is %s, not Range" % [spec.get("node", ""), node.get_class()]
	var slider := node as Range
	var value := float(spec.get("value", 0.0))
	slider.value = value
	slider.value_changed.emit(value)
	print("AGENT_RANGE ", spec.get("node", ""), " value=", value)
	return ""


static func scroll_to(scene: Node, spec: Dictionary) -> String:
	var node := resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "missing node %s" % str(spec.get("node", ""))
	if not (node is ScrollContainer):
		return "%s is %s, not ScrollContainer" % [spec.get("node", ""), node.get_class()]
	var sc := node as ScrollContainer
	if spec.has("vertical"):
		sc.scroll_vertical = int(spec["vertical"])
	if spec.has("horizontal"):
		sc.scroll_horizontal = int(spec["horizontal"])
	print("AGENT_SCROLL ", spec.get("node", ""))
	return ""


static func drag_control(scene: Node, spec: Dictionary) -> String:
	var node := resolve(scene, str(spec.get("node", "")))
	if node == null:
		return "missing node %s" % str(spec.get("node", ""))
	if not (node is Control):
		return "%s is %s, not Control" % [spec.get("node", ""), node.get_class()]
	var control := node as Control
	var from := Vector2(float(spec.get("from_x", 8.0)), float(spec.get("from_y", 8.0)))
	var to := Vector2(
		float(spec.get("to_x", from.x + 40.0)),
		float(spec.get("to_y", from.y))
	)
	var g0 := control.get_global_transform_with_canvas() * from
	var g1 := control.get_global_transform_with_canvas() * to
	var shift := bool(spec.get("shift", false))
	var ctrl := bool(spec.get("ctrl", false))
	_mouse_button(g0, true, shift, ctrl)
	_mouse_motion(g0, g1, shift, ctrl)
	_mouse_button(g1, false, shift, ctrl)
	print("AGENT_DRAG ", spec.get("node", ""))
	return ""


static func _mouse_button(pos: Vector2, pressed: bool, shift := false, ctrl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


static func _mouse_motion(from: Vector2, to: Vector2, shift := false, ctrl := false) -> void:
	var steps := 6
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		var ev := InputEventMouseMotion.new()
		ev.shift_pressed = shift
		ev.ctrl_pressed = ctrl
		ev.position = pos
		ev.global_position = pos
		ev.relative = (to - from) / float(steps)
		Input.parse_input_event(ev)


static func call_method(scene: Node, spec: Dictionary) -> String:
	var label := ""
	var node: Node = null
	if not spec.has("harness"):
		return "call on a product node is not a player action; use click or press"
	label = str(spec.get("harness", "")).strip_edges()
	var tree: SceneTree = scene.get_tree() if scene else null
	node = Workspace.harness_node(tree, label)
	if node == null:
		return "missing harness %s" % label
	var method := str(spec.get("method", "")).strip_edges()
	if method.is_empty():
		return "call missing method"
	if method in _BLOCKED_METHODS:
		return "call blocked method %s" % method
	if not node.has_method(method):
		return "%s has no method %s" % [label, method]
	var args: Array = spec.get("args", [])
	if typeof(args) != TYPE_ARRAY:
		return "call.args must be an array"
	var result: Variant = node.callv(method, args)
	print("AGENT_CALL ", label, ".", method, " result=", stringify_variant(result))
	return ""
