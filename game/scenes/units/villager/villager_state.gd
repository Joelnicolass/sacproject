class_name VillagerState
extends FsmState

## One thing a villager is doing: Idle (before its first look), Work (calm, near a shelter), Flee (running from a scare) or Cower (no shelter
## near). This one is Idle and does nothing; the others override `act`, which the Brain calls each time it thinks.
## Not: deciding which state comes next (VillagerBrain).

var body: UnitBody:
	get: return actor as UnitBody


func act() -> void:
	pass
