extends Node

## RFC-052 052c (F362). The headless client of agent/runs/run_audio_net.sh: joins a dedicated started by hand (with the debug
## world audio_net_match.tscn), and counts in its own SoundLog the creature sounds of the duel the server sets up. The client
## only receives replicated state (mode, swings, shots, Health), so every entry proves a sound deduced on a remote peer.
## Needs `--audio-probe` (a headless process has no audio otherwise). The sets come from the fixtures first
## (debug/audio/fixtures/lab/: the duel's ycro and plfl sound without the original); `--audio-no-original` leaves only them.
## Flags: --e2e-name, --mp-port (the kit), --audio-events=summon,swing,damaged,death (each needs a played entry of a creature),
## --e2e-timeout-s=N (real seconds, 60 by default).
## Prints `AUDIO_NET <event> <count>` and `AUDIO_NET PASS|FAIL`; exit 0 / 1. Like dedicated_client, the main scene starts a twin
## under `root` (loading the world frees the main scene).

const LOCAL_HOST := "127.0.0.1"
const RUNNER_META := "audio_net_client_runner"
const FIXTURE_ROOT := "res://debug/audio/fixtures/lab/"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"

var _name := ""
var _seen := {}
var _counts := {}
var _finished := false


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "AudioNetClientRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_name = MpBoot.user_value("e2e-name", "cliente")
	_run.call_deferred()


func _run() -> void:
	if not SoundBus.is_active():
		_finish(false, "sin audio: falta --audio-probe")
		return
	var roots := PackedStringArray([FIXTURE_ROOT])
	if MpBoot.user_flag("audio-no-original"):
		roots.append(EMPTY_ROOT)
	else:
		roots.append_array(SoundLibrary.DEFAULT_ROOTS)
	SoundLibrary.roots = roots
	SoundLibrary.clear_cache()
	var wanted := MpBoot.user_value("audio-events", "summon,swing,damaged,death").split(",", false)
	for event in wanted:
		_counts[StringName(event)] = 0
	if SacrificeFlow.join_lan(LOCAL_HOST) != OK:
		_finish(false, "no se pudo unir")
		return
	var end := Time.get_ticks_msec() + int(float(MpBoot.user_value("e2e-timeout-s", "60")) * 1000.0)
	while Time.get_ticks_msec() < end:
		_collect()
		if _counts.values().all(func(n: int) -> bool: return n > 0):
			break
		await get_tree().process_frame
	_collect()
	for event in _counts:
		print("AUDIO_NET %s %d" % [event, _counts[event]])
	var extra := {}
	for key in _seen:
		var event: StringName = _seen[key]
		extra[event] = int(extra.get(event, 0)) + 1
	print("AUDIO_NET todos %s" % extra)
	_finish(_counts.values().all(func(n: int) -> bool: return n > 0), "faltan eventos" if not _counts.values().all(func(n: int) -> bool: return n > 0) else "")


## Played entries of a creature (not the wizard) since the last look; the ring holds 64, the look is every frame.
func _collect() -> void:
	if SoundBus.sound_log == null:
		return
	for entry: Dictionary in SoundBus.sound_log.entries():
		if not bool(entry.played) or String(entry.emitter).begins_with("Wizard"):
			continue
		var key := "%d|%s|%s|%s" % [entry.tick, entry.emitter, entry.event, entry.stream]
		if _seen.has(key):
			continue
		_seen[key] = entry.event
		if _counts.has(entry.event):
			_counts[entry.event] += 1


func _finish(ok: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	print("AUDIO_NET %s %s%s" % [_name, "PASS" if ok else "FAIL", "" if reason.is_empty() else " " + reason])
	SoundBus.stop_all()
	var release_at := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
	MpKit.leave()
	get_tree().quit(0 if ok else 1)
