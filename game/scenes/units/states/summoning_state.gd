class_name SummoningState
extends UnitState

## SUMMONING: translucent, no orders, no aggro and not a target until the wizard's cast ends
## (UnitBody.finish_summon). Leaving it emits `summoned`.

## The alpha is 0.36 while the summon is cast.
const SUMMONING_ALPHA := 0.36


func present(_animate: bool) -> void:
	_fade(1.0 - SUMMONING_ALPHA)


func exit() -> void:
	_fade(0.0)
	body.summoned.emit()
	super.exit()


func rests_on_floor() -> bool:
	return true


func _fade(amount: float) -> void:
	var visual := body.get_node_or_null("Tilt/Mesh") as BodyVisual
	if visual:
		visual.set_fade(amount)
