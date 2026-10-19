class_name AudioGate
extends RefCounted

## RFC-052 052a (F360): does this process have audio? The one rule every audio piece asks before it loads or creates
## anything (SoundLibrary, SoundBus and, later, the Sounds/Voice/Director nodes).
## - Closed in the dedicated server (`--dedicated` or the export feature), in the room server (`--room-server`) and in
##   any headless process, so the simulation, the benches and the servers never load an AudioStream.
## - `--audio-probe` opens it in a headless process (the audio cases and the lab), never in a server.
## The answer is fixed for the life of the process (the flags do not change), so it is computed once.

const PROBE_FLAG := "--audio-probe"

static var _cached := -1


## True when this process plays sound.
static func is_open() -> bool:
	if _cached < 0:
		var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
		_cached = 1 if decide(args, DisplayServer.get_name() == "headless", MpBoot.is_dedicated_process()) else 0
	return _cached == 1


## The rule itself, pure (the cases try every combination): `args` are the process flags, `headless` its display server
## and `dedicated` MpBoot's answer (it also reads the export features).
static func decide(args: PackedStringArray, headless: bool, dedicated: bool) -> bool:
	if dedicated or _has_flag(args, "--dedicated") or _has_flag(args, "--room-server"):
		return false
	if headless:
		return _has_flag(args, PROBE_FLAG)
	return true


static func _has_flag(args: PackedStringArray, flag: String) -> bool:
	for arg in args:
		if arg == flag or arg.begins_with(flag + "="):
			return true
	return false
