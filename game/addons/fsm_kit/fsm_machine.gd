@tool
class_name FsmMachine
extends Node

## Parent of [FsmState] children. Transition by child node name. Actor is a socket.
## payload is generic data for the transition (a hitbox, a target). The kit does not interpret it.
## Who changes the state: the owner calls transition() / transition_to() (direct); a state calls its own
## FsmState.transition(), a request that goes through _request_transition() first (allowed by default).
## Starting: by itself once a state and the actor exist (autostart), or when the owner calls start().

signal state_changed(from: StringName, to: StringName)
## Fires on every transition, including a repeat of the current state when only the payload changes.
signal transitioned(from_name: StringName, to_name: StringName, next_payload: Variant)

@export var initial_state: FsmState
@export var actor: Node
## Start by itself in _ready (once a state and the actor exist). Off: nothing runs until start() is called (an
## actor that sets itself up later, a peer that joins mid-match and starts in the state the network says).
@export var autostart: bool = true
@export var run_process: bool = true
@export var run_physics: bool = true
@export var run_unhandled_input: bool = true

var current: FsmState
var payload: Variant = null
var _started: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for child in get_children():
		_bind(child)
	child_entered_tree.connect(_bind)
	if actor == null:
		actor = get_parent()
	if autostart:
		start()


## Call after assigning actor if _ready ran before the actor existed (with autostart, it starts then).
func notify_actor_ready() -> void:
	if actor == null:
		actor = get_parent()
	if autostart:
		start()


## Start now in `state` (initial_state, else the first FsmState child) with `start_payload` (e.g. "do not animate
## in"). Once: after that, change state with transition_to(). False when there is no state or no actor yet.
func start(state: FsmState = null, start_payload: Variant = null) -> bool:
	if _started or actor == null or Engine.is_editor_hint():
		return false
	var first := state if state != null else initial_state
	if first == null:
		for child in get_children():
			if child is FsmState:
				first = child
				break
	if first == null or first.get_parent() != self:
		return false
	_started = true
	payload = start_payload
	_enter(first)
	return true


## True once the machine has entered its first state.
func is_started() -> bool:
	return _started


## The current state's name (empty before it starts).
func current_name() -> StringName:
	return StringName(current.name) if current != null else StringName()


## True when the current state is `state_name`.
func is_in(state_name: StringName) -> bool:
	return current != null and StringName(current.name) == state_name


## Run the current state's physics_update now. The machine calls it itself with run_physics on; with it off, an
## actor that ticks in its own order calls it.
func step_physics(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


## Run the current state's update now (as step_physics, for run_process).
func step_process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not run_process:
		return
	step_process(delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not run_physics:
		return
	step_physics(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not run_unhandled_input or current == null:
		return
	current.handle_input(event)


## The owner: go to `state_name` now.
func transition(state_name: StringName, next_payload: Variant = null) -> void:
	var next := _state_named(state_name)
	if next != null:
		transition_to(next, next_payload)


## A state's request (FsmState.transition): goes to `state_name` only if _request_transition() allows it.
func request(state_name: StringName, next_payload: Variant = null) -> void:
	var next := _state_named(state_name)
	if next != null and _request_transition(next, next_payload):
		transition_to(next, next_payload)


## Override (extends FsmMachine) when someone else owns the state: e.g. a value the network replicates. Write that
## value here and return false; its setter then calls transition_to(). Default: every request goes through.
func _request_transition(_next: FsmState, _next_payload: Variant) -> bool:
	return true


func _state_named(state_name: StringName) -> FsmState:
	var next := get_node_or_null(NodePath(str(state_name))) as FsmState
	if next == null:
		push_warning("FsmMachine: no state '%s'" % state_name)
	return next


func transition_to(next: FsmState, next_payload: Variant = null) -> void:
	if next == null:
		return
	if next.get_parent() != self:
		push_warning("FsmMachine: state '%s' is not a child" % next.name)
		return
	payload = next_payload
	if next == current:
		var same := StringName(next.name)
		transitioned.emit(same, same, payload)
		next.apply_payload(payload)
		return
	_enter(next)


## A state added after _ready (a late child) gets its machine too.
func _bind(child: Node) -> void:
	if child is FsmState and child.get_parent() == self:
		(child as FsmState).machine = self


func _enter(next: FsmState) -> void:
	var from_name := StringName()
	if current != null:
		from_name = current.name
		current.exit()
	current = next
	next.machine = self
	next.enter()
	var to_name := StringName(next.name)
	transitioned.emit(from_name, to_name, payload)
	state_changed.emit(from_name, to_name)


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
	if initial_state == null and autostart:
		out.append("Assign initial_state, or the first FsmState child is used at runtime.")
	return out
