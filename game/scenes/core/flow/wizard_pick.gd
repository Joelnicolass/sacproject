class_name WizardPick
extends Resource

## What one player chose in the menu: a wizard and the god whose book he casts. Plain data, no
## rules: whoever stores a pick replaces it, nobody edits one. It does not know the network;
## `MatchWire` is the only place that turns it into ids and back.

@export var wizard: WizardType
@export var god: GodType


## True when both halves are set.
func is_complete() -> bool:
	return wizard != null and god != null
