class_name UnitStates
extends FsmMachine

## The machine of a UnitBody: one UnitState per mode. It finds the state of a `mode` value and
## follows `UnitBody.mode`; it never processes by itself (the body calls the current state in its
## own physics step, in its own order).
## Not: what a mode does (each UnitState) nor who changes the mode (UnitBody.mode is the only
## writer).

var _by_mode := {}


## Maps the modes. autostart is off (unit.tscn): UnitBody._ready starts it in the state of the mode
## the body was born in, with UnitState.JOINED (a late join, a summon: its look without the
## animation).
func _ready() -> void:
	super._ready()
	for state: UnitState in get_children():
		_by_mode[state.mode] = state
	set_physics_process(false)
	set_process(false)
	set_process_unhandled_input(false)


## The state that stands for `mode` (null when none does: start() then takes initial_state).
func state_of(mode: UnitBody.Mode) -> UnitState:
	return _by_mode.get(mode)


## The mode changed: the machine moves to its state (enter and exit run on every peer).
func follow(mode: UnitBody.Mode) -> void:
	var next := state_of(mode)
	if next != null:
		transition_to(next)


## A state asked for another (UnitState.transition): UnitBody.mode is the only writer, so the
## request writes it and its setter moves the machine through follow().
func _request_transition(next: FsmState, _next_payload: Variant) -> bool:
	(actor as UnitBody).mode = (next as UnitState).mode
	return false
