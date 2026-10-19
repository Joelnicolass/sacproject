extends RitualStep

## Preparation (rules.ritual_setup_s, 5 s): the four doctors stand on the ring and the creature rises
## over the site (Ritual moves it). sacengine setupTime (state.d:2713).


func enter() -> void:
	super.enter()
	ritual.phase = Ritual.Phase.SETUP


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if time >= ritual.rules.ritual_setup_s:
		transition(&"Walk")
