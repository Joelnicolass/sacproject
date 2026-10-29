class_name ScreenGate
extends RefCounted

## Does this process draw? The one rule every presentation piece asks (camera shake, damage
## numbers): closed in any headless process and in the dedicated server, so the simulation and the
## servers never build screen-only nodes.
## Not: who looks at the screen (MpLocalSeat) nor whether sound plays (AudioGate).


## True when this process shows a window.
static func is_open() -> bool:
	return DisplayServer.get_name() != "headless" and not MpBoot.is_dedicated_process()
