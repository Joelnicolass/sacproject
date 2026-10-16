@tool
class_name FsmMachine
extends Node

## Parent of [FsmState] children. Transition by child node name. Actor is a socket.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: FsmState
@export var actor: Node
@export var run_process: bool = true
@export var run_physics: bool = true
@export var run_unhandled_input: bool = true

var current: FsmState


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for child in get_children():
		if child is FsmState:
			(child as FsmState).machine = self
	var start := initial_state
	if start == null:
		for child in get_children():
			if child is FsmState:
				start = child
				break
	if start != null:
		_enter(start, true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not run_process or current == null:
		return
	current.update(delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not run_physics or current == null:
		return
	current.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not run_unhandled_input or current == null:
		return
	current.handle_input(event)


func transition(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as FsmState
	if next == null:
		push_warning("FsmMachine: no state '%s'" % state_name)
		return
	transition_to(next)


func transition_to(next: FsmState) -> void:
	if next == null or next == current:
		return
	if next.get_parent() != self:
		push_warning("FsmMachine: state '%s' is not a child" % next.name)
		return
	_enter(next, false)


func _enter(next: FsmState, first: bool) -> void:
	var from_name := StringName()
	if current != null:
		from_name = current.name
		current.exit()
	current = next
	next.machine = self
	next.enter()
	if not first:
		state_changed.emit(from_name, StringName(next.name))
	else:
		state_changed.emit(StringName(), StringName(next.name))


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if actor == null:
		out.append("Assign actor (the container this machine drives).")
	var has_state := false
	for child in get_children():
		if child is FsmState:
			has_state = true
			break
	if not has_state:
		out.append("Add FsmState children (Idle, Move, …).")
	if initial_state == null:
		out.append("Assign initial_state, or the first FsmState child is used at runtime.")
	return out
