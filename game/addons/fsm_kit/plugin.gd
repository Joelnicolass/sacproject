@tool
extends EditorPlugin

const MACHINE := preload("res://addons/fsm_kit/fsm_machine.gd")
const STATE := preload("res://addons/fsm_kit/fsm_state.gd")


func _enter_tree() -> void:
	add_custom_type("FsmMachine", "Node", MACHINE, null)
	add_custom_type("FsmState", "Node", STATE, null)
	add_tool_menu_item("FsmKit: Add machine under selection", _on_add_machine)


func _exit_tree() -> void:
	remove_tool_menu_item("FsmKit: Add machine under selection")
	remove_custom_type("FsmMachine")
	remove_custom_type("FsmState")


func _on_add_machine() -> void:
	var edited := EditorInterface.get_edited_scene_root()
	if edited == null:
		push_warning("FsmKit: open a scene first")
		return
	var selected := EditorInterface.get_selection().get_selected_nodes()
	var parent: Node = edited if selected.is_empty() else selected[0]
	if parent.get_node_or_null("States") != null:
		push_warning("FsmKit: %s already has a States child" % parent.name)
		return
	var ur := get_undo_redo()
	ur.create_action("FsmKit: add machine")
	var machine := Node.new()
	machine.name = "States"
	machine.set_script(MACHINE)
	ur.add_do_method(parent, "add_child", machine)
	ur.add_do_method(machine, "set_owner", edited)
	ur.add_undo_method(parent, "remove_child", machine)
	ur.add_do_reference(machine)
	for state_name in ["Idle", "Move"]:
		var state := Node.new()
		state.name = state_name
		state.set_script(STATE)
		ur.add_do_method(machine, "add_child", state)
		ur.add_do_method(state, "set_owner", edited)
		ur.add_do_reference(state)
	ur.commit_action()
	if machine.has_method("set"):
		machine.set("actor", parent)
		var idle := machine.get_node_or_null("Idle")
		if idle:
			machine.set("initial_state", idle)
