extends RefCounted

## Test helper (055s): makes a body that is not in the tree wear a look that only carries `sounds`, the way BodyMount gives a real body
## the sounds of its appearance. UnitSounds, WizardSounds and CommandVoice read the set from `body.mount.sounds()`.


## Gives `body` (a UnitBody or WizardBody) a mount whose look has `sounds`. The mount is a child of the body, so it goes with it.
static func give(body: Node, sounds: SoundSet) -> BodyMount:
	var mount := BodyMount.new()
	var look := BodyLook.new()
	look.sounds = sounds
	mount.add_child(look)
	mount.look = look
	body.add_child(mount)
	body.set("mount", mount)
	return mount
