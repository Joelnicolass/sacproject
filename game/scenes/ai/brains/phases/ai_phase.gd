class_name AiPhase
extends Node

## A phase of the wizard's replan: attack, support, convert, summon. The brain runs the
## phases that are its children, in order, every 16 ticks; each puts entries in the wizard's cast queue. Take a phase out and
## the wizard no longer does that: without AttackPhase he is a pacifist.
## Ref: RFC-024 §3.1; shiny.d:3333-3340.

@export var brain: AiWizardBrain


## `wizard` the AI's wizard track, `w3` the weights of attack, support and convert (weightTriple), `record` the record
## that leads him when it is a capture one (else null).
func run(_wizard: AiTrack, _w3: Array[float], _record: AiRecord) -> void:
	pass


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is AiWizardBrain:
		warnings.append("Una fase cuelga de un AiWizardBrain.")
	return warnings
