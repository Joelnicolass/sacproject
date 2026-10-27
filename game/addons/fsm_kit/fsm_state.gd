@tool
class_name FsmState
extends Node

## One state under an [FsmMachine]. Override enter/exit/update. No score.

signal entered
signal exited

var machine: FsmMachine


var actor: Node:
	get:
		return machine.actor if machine != null else null


func enter() -> void:
	entered.emit()


func exit() -> void:
	exited.emit()


## Same state again with a new payload. Does not exit/enter.
func apply_payload(_next_payload: Variant) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


## Ask the machine for `state_name`: a request, through FsmMachine._request_transition() (allowed by default).
func transition(state_name: StringName, next_payload: Variant = null) -> void:
	if machine == null:
		push_warning("FsmState '%s' has no machine" % name)
		return
	machine.request(state_name, next_payload)
