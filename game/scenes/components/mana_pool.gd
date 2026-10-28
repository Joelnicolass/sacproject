class_name ManaPool
extends Node

## Mana of a body. No passive regeneration: sources (manafount, altar) call add().
## Server-authoritative; clients get `current` and `maximum` by sync.

signal changed(current: float, maximum: float)
## add() was called: `amount` is what the source gave, before the clamp to maximum
## (a ghost heals by it even with a full pool).
signal given(amount: float)

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


func add(amount: float) -> void:
	if not is_multiplayer_authority() or amount <= 0.0:
		return
	if poisoning and poisoning.mana_blocked():
		return
	current = minf(current + amount, maximum)
	given.emit(amount)


## Mana − amount, never under 0. Poison does not block it (the
## Tickferno's heat ray). Returns what it took.
func drain(amount: float) -> float:
	if not is_multiplayer_authority() or amount <= 0.0:
		return 0.0
	var before := current
	current = maxf(0.0, current - amount)
	return before - current
