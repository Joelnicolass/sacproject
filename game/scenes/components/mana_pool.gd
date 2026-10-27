class_name ManaPool
extends Node

## Mana of a body. No passive regeneration: sources (manafount, altar) call add().
## Server-authoritative; clients get `current` and `maximum` by sync.

signal changed(current: float, maximum: float)
## add() was called: `amount` is what the source gave, before the clamp to maximum
## (a ghost heals by it even with a full pool).
## Ref: sacengine giveMana, state.d:8828-8832.
signal given(amount: float)
## add() said where the mana came from (`source`: fount, altar, manalith, manahoar; empty = nobody said).
## The AI's audit adds these up to show that all the mana of a side comes from sources (RFC-024 024c).
signal fed(amount: float, source: StringName)

## Only read by setup(): MatchRules.start_mana, if not negative, replaces a full pool.
@export var rules: MatchRules
@export var maximum: float = 0.0:
	set(value):
		maximum = maxf(value, 0.0)
		changed.emit(current, maximum)
@export var current: float = 0.0:
	set(value):
		current = value
		changed.emit(current, maximum)
## The body's poison (Poisoning). While a dose blocks the mana, add() gives nothing.
## Optional: empty = never blocked.
## Ref: F122; sacengine giveMana, state.d:8829.
@export var poisoning: Poisoning


## The ManaPool child of `node` (a body), or null.
static func of(node: Node) -> ManaPool:
	for child in node.get_children() if node else []:
		if child is ManaPool:
			return child
	return null


func setup(full: float) -> void:
	maximum = full
	current = full
	if rules and rules.start_mana >= 0.0:
		current = minf(rules.start_mana, full)


func spend(amount: float) -> bool:
	if not is_multiplayer_authority() or amount < 0.0 or current < amount:
		return false
	current -= amount
	return true


func add(amount: float, source: StringName = &"") -> void:
	if not is_multiplayer_authority() or amount <= 0.0:
		return
	if poisoning and poisoning.mana_blocked():
		return
	current = minf(current + amount, maximum)
	given.emit(amount)
	fed.emit(amount, source)



## Mana − amount, never under 0. Poison does not block it (F123: the
## Tickferno's heat ray). Returns what it took.
## Ref: sacengine drainMana, state.d:8822-8825.
func drain(amount: float) -> float:
	if not is_multiplayer_authority() or amount <= 0.0:
		return 0.0
	var before := current
	current = maxf(0.0, current - amount)
	return before - current
