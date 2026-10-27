class_name SoulPurse
extends Node

## Blue souls carried by a wizard. Starts at MatchRules.starting_souls on the server (or solo). `rules` is the world's
## (WizardSpawner injects it), so the match setup (boot, --souls) reaches it; the scene default is only for F6.

signal changed(count: int)

@export var rules: MatchRules
@export var count: int = 0:
	set(value):
		count = maxi(value, 0)
		changed.emit(count)


func _ready() -> void:
	if is_multiplayer_authority() and rules:
		count = rules.starting_souls


func add(amount: int = 1) -> void:
	if not is_multiplayer_authority() or amount <= 0:
		return
	count += amount


func take(amount: int = 1) -> bool:
	if not is_multiplayer_authority() or amount < 0 or count < amount:
		return false
	count -= amount
	return true


## Summons pay here: the souls go when the cast ends.
## Ref: sacengine updateCreatureCasting.
func spend(amount: int = 1) -> bool:
	return take(amount)
