class_name RitualType
extends Resource

## What tells one class of ritual from another: Desecrate drains the wizard whose altar it is and ends when he dies; Convert drains
## nobody, lasts as many rounds as the creature has health for and pays its souls to the caster. A `.tres` per class, assigned in
## `Ritual.types`; the ritual and its parts read these fields instead of asking which kind it is. What it does not do: hold balance
## numbers (MatchRules does) or know the phases (Ritual does).

## How a ritual knows its last round.
enum Ending {
	TARGET_WIZARD_GONE,  ## the wizard whose altar it is died or left
	CREATURE_HEALTH_ROUNDS,  ## int(max health of the creature / convert_health_per_round) + 1 rounds
}

## Network id of the class (what a client reads from the spawn data).
@export var kind := Ritual.Kind.DESECRATE
@export var ending := Ending.TARGET_WIZARD_GONE
## Every shooting round takes life and mana from the wizard whose altar it is.
@export var drains_target_wizard := true
## When that wizard is dead his altar starts to fall.
@export var collapses_target_altar := true
## The wizard counts a desecration on his ghost form while the ritual lasts.
@export var marks_target_ghost := true
## A finished ritual announces the conversion of the creature's souls.
@export var counts_as_conversion := false

static var _inert: RitualType


## A ritual with no type for its kind: it drains, collapses, marks and announces nothing.
static func inert() -> RitualType:
	if _inert == null:
		_inert = RitualType.new()
		_inert.drains_target_wizard = false
		_inert.collapses_target_altar = false
		_inert.marks_target_ghost = false
	return _inert


## The round that just ended was the last one (rounds count from 0). Convert: `round == int(max health / convert_health_per_round)`.
func is_last_round(ritual: Ritual) -> bool:
	if ending == Ending.CREATURE_HEALTH_ROUNDS:
		if not is_instance_valid(ritual.creature):
			return true
		var health := ritual.creature.get_node_or_null("Health") as Health
		var per_round := ritual.rules.convert_health_per_round if ritual.rules else 550.0
		return ritual.round_index >= SacrificeMath.convert_rounds(health.maximum if health else 0.0, per_round) - 1
	return ritual.target_is_gone()
