class_name AfflictionGlows
extends RefCounted

## Gives each state of a body the light its type asks for (`AfflictionType.glow`): the light becomes a child of the state, dark until the
## state is on, and fades in and out with the state's `shown_changed`. It does not decide when a state is on (Afflictions) nor what the
## light looks like (the glow scene). Presentation only: a headless or dedicated process makes none.


static func attach(afflictions: Afflictions) -> void:
	if LookRig.is_presentationless():
		return
	for child in afflictions.get_children():
		var state := child as Affliction
		if state == null or state.type == null or state.type.glow == null:
			continue
		var light := state.type.glow.instantiate() as StateLight
		state.add_child(light)
		state.shown_changed.connect(light.show_lit)
		light.show_lit(state.is_on())
