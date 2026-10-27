class_name UnitStates
extends FsmMachine

## The machine of a UnitBody: one UnitState per mode. It finds the state of a `mode` value and follows `UnitBody.mode`; it never processes
## by itself (the body calls the current state in its own physics step, in its own order).
## Not: what a mode does (each UnitState) nor who changes the mode (UnitBody.mode is the only writer).

var _by_mode := {}


## Once, from UnitBody._ready: maps the modes and takes the state of the mode the body was born in. The machine began in Idle; a body
## born in another mode (a late join, a summon) takes its state without the enter.
func begin(mode: UnitBody.Mode) -> void:
	for state: UnitState in get_children():
		_by_mode[state.mode] = state
	set_physics_process(false)
	set_process(false)
	set_process_unhandled_input(false)
	if _by_mode.has(mode):
		current = _by_mode[mode]
		(current as UnitState).present(false)


## The mode changed: the machine moves to its state (enter and exit run on every peer).
func follow(mode: UnitBody.Mode) -> void:
	var next: UnitState = _by_mode.get(mode)
	if next != null:
		transition_to(next)


## A state asked for another (UnitState.transition): UnitBody.mode is the only writer, so the request writes it and its setter
## moves the machine through follow().
func _request_transition(next: FsmState, _next_payload: Variant) -> bool:
	(actor as UnitBody).mode = (next as UnitState).mode
	return false
