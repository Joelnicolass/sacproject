extends Node

## Mana of a body. No passive regeneration: sources (manafount, altar) call add().
## Server-authoritative; clients get `current` and `maximum` by sync.

signal changed(current: float, maximum: float)
## add() was called: `amount` is what the source gave, before the clamp to maximum
## (sacengine giveMana heals a ghost by it even with a full pool, state.d:8828-8832).
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
## F122: the body's poison (Poisoning). While a dose blocks the mana, add() gives nothing (sacengine giveMana,
## state.d:8829). Optional: empty = never blocked.
@export var poisoning: Poisoning


func setup(full: float) -> void:
	maximum = full
	current = full
	if rules and rules.start_mana >= 0.0:
		current = minf(rules.start_mana, full)


func spend(amount: float) -> bool:
	if not _has_authority() or amount < 0.0 or current < amount:
		return false
	current -= amount
	return true


func add(amount: float, source: StringName = &"") -> void:
	if not _has_authority() or amount <= 0.0:
		return
	if poisoning and poisoning.mana_blocked():
		return
	current = minf(current + amount, maximum)
	given.emit(amount)
	fed.emit(amount, source)


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()
