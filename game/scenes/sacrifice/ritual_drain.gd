@tool
class_name RitualDrain
extends Node

## What a ritual takes from the wizard whose altar it is: `apply` removes a fraction of a round's life and mana (Shoot calls it with
## the time that passed), and `collapse_altar` starts the fall of his altar, once. Only a type that `drains_target_wizard` takes
## anything. What it does not do: decide when a round is or who wins (Ritual). Take this node out and the wizard is never touched.

@export var ritual: Ritual

## The altar already started to fall (Watch reads it: a falling altar does not cancel the ritual).
var altar_falling := false

var _match: MatchState


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Assign to `ritual` the Ritual it drains.")
	return warnings


## Life and mana of `fraction` of one round, from the wizard (killing credit to the caster).
func apply(fraction: float) -> void:
	if (
		not ritual.type().drains_target_wizard
		or ritual.target_is_gone()
		or fraction <= 0.0
		or ritual.rules == null
	):
		return
	var rules := ritual.rules
	var wizard := ritual.target_wizard
	var health := wizard.health as Health
	health.damage(
		SacrificeMath.desecrate_health(ritual.souls, rules.desecrate_health_per_round) * fraction,
		ritual.caster_slot
	)
	var mana := wizard.mana
	var wanted := (
		SacrificeMath.desecrate_mana(ritual.souls, rules.desecrate_mana_per_round) * fraction
	)
	mana.set("current", maxf(float(mana.get("current")) - wanted, 0.0))


## The wizard counts a desecration on his ghost form while the ritual lasts (begin) and stops counting it (cancelled).
func mark_target(on: bool) -> void:
	var wizard := ritual.target_wizard
	var ghost := wizard.ghost as GhostForm if wizard != null and is_instance_valid(wizard) else null
	if ghost == null or not ritual.type().marks_target_ghost:
		return
	if on:
		ghost.add_desecration()
	else:
		ghost.remove_desecration()


## The wizard's body is dead: his altar starts to fall, once.
func collapse_altar() -> void:
	if altar_falling:
		return
	altar_falling = true
	var match_state := _match_state()
	if match_state != null:
		match_state.begin_altar_collapse(ritual.target_slot, ritual.caster_slot)


func _match_state() -> MatchState:
	if _match == null or not is_instance_valid(_match):
		_match = get_tree().get_first_node_in_group(MatchState.GROUP) as MatchState
	return _match
