class_name RitualStep
extends FsmState

## One phase of a ritual (RFC-020): Setup, Walk, Shoot, Wait. Server only: the Phases machine does not
## run on clients, they get `phase` replicated. Off and Ended are plain FsmStates.

var ritual: Ritual:
	get:
		return actor as Ritual

## Seconds in this phase.
var time := 0.0


func enter() -> void:
	super.enter()
	time = 0.0


func physics_update(delta: float) -> void:
	time += delta
