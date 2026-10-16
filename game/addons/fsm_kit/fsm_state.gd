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


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func transition(state_name: StringName) -> void:
	if machine == null:
		push_warning("FsmState '%s' has no machine" % name)
		return
	machine.transition(state_name)
