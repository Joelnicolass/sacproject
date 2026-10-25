extends Node

## RFC-052 052c (F362). The headless client of agent/runs/run_audio_net.sh: joins a dedicated started by hand (with the debug
## world audio_net_match.tscn), and counts in its own SoundLog the creature sounds of the duel the server sets up. The client
## only receives replicated state (mode, swings, shots, Health), so every entry proves a sound deduced on a remote peer.
## Needs `--audio-probe` (a headless process has no audio otherwise). The creatures sound as their CreatureType says
## (`sounds`: the duel's ycro and plfl, with the original's audio files, which the repo versions in LFS).
## 052d: `fx` counts the FX sounds (FxBus.played of a broadcast FX -> FxSounds; the emitter is the FX name).
## 052e: `advice` counts the advisor's lines. The client asks its wizard's Caster for a spell it does not have (`REFUSED_TAG`),
## once a second until one is heard: the server answers with a Refusal key (bad_target) through the feedback RPC every cast
## already has, CommandLog says it and AdvisorVoice speaks (`invalid_target`: a typed AdvisorLine of advisor.tscn).
## 052f: `battle` (a default event: the run fails without it) counts the music's mood: the duel next to the local wizard,
## held in real time (audio_net_duel `battle_hold_ms`), puts its CombatGauge (match.tscn) over `enter` from the replicated
## modes, and its MusicDirector logs emitter `music`, event `battle`. The music is the one of the god of the land
## (GodType.music, else the match's default_music).
## --audio-net-trace prints every change of the creatures (mode, swings, shots, position) and the gauge (diagnosis).
## Flags: --e2e-name, --mp-port (the kit), --audio-events=summon,swing,damaged,death,fx,advice,battle (each needs a played entry of a
## creature, fx of an FX, advice of the advisor),
## --e2e-timeout-s=N (real seconds, 60 by default), --e2e-linger-s=N (real seconds to keep running after MpKit.leave(); 0 by default).
## Prints `AUDIO_NET <event> <count>` and `AUDIO_NET PASS|FAIL`; exit 0 / 1. Like dedicated_client, the main scene starts a twin
## under `root` (loading the world frees the main scene).

const LOCAL_HOST := "127.0.0.1"
const RUNNER_META := "audio_net_client_runner"
## A spell tag no spellbook has: the server refuses it (Refusal.BAD_TARGET).
const REFUSED_TAG := "zzzz"

var _name := ""
var _seen := {}
var _counts := {}
var _finished := false
var _next_trace := 0
var _last_trace := ""


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
	var wanted := MpBoot.user_value("audio-events", "summon,swing,damaged,death,fx,advice,battle").split(",", false)
	for event in wanted:
		_counts[StringName(event)] = 0
	if SacrificeFlow.join_lan(LOCAL_HOST) != OK:
		_finish(false, "no se pudo unir")
		return
	var end := Time.get_ticks_msec() + int(float(MpBoot.user_value("e2e-timeout-s", "60")) * 1000.0)
	var next_refusal := 0
	while Time.get_ticks_msec() < end:
		if _counts.has(SoundEvent.ADVICE) and _counts[SoundEvent.ADVICE] == 0 and Time.get_ticks_msec() >= next_refusal:
			next_refusal = Time.get_ticks_msec() + 1000
			_ask_refused_cast()
		_collect()
		if MpBoot.user_flag("audio-net-trace") and Time.get_ticks_msec() >= _next_trace:
			_trace()
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


## Asks the local wizard's Caster for a spell nobody has; the server's answer is a refusal (052e).
func _ask_refused_cast() -> void:
	for wizard in get_tree().get_nodes_in_group(&"wizard"):
		if wizard.has_method("is_local") and wizard.call("is_local"):
			var caster := wizard.get_node_or_null("Caster") as Caster
			if caster != null:
				caster.request_cast(REFUSED_TAG, (wizard as Node3D).global_position, null)
			return


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
	SoundBus.shutdown()
	var release_at := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
	MpKit.leave()
	var linger_until := Time.get_ticks_msec() + int(float(MpBoot.user_value("e2e-linger-s", "0")) * 1000.0)
	while Time.get_ticks_msec() < linger_until:
		await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


## `--audio-net-trace`: where the listener, the local wizard and every creature are, and what the gauge measures.
func _trace() -> void:
	var state := ""
	for node in get_tree().get_nodes_in_group(&"unit"):
		var unit := node as UnitBody
		if unit != null:
			state += "|%s %d %d %d %s" % [unit.name, unit.mode, unit.swings, unit.shots, unit.global_position.round()]
	var g := get_tree().root.find_child("CombatGauge", true, false) as CombatGauge
	if g != null:
		state += "|g %.2f" % g.intensity
	if state == _last_trace:
		return
	_last_trace = state
	print("AUDIO_NET trace f=%d ms=%d %s" % [Engine.get_process_frames(), Time.get_ticks_msec(), state])
	if Time.get_ticks_msec() < _next_trace:
		return
	_next_trace = Time.get_ticks_msec() + 2000
	var gauge := get_tree().root.find_child("CombatGauge", true, false) as CombatGauge
	var wiz := "-"
	for wizard in get_tree().get_nodes_in_group(&"wizard"):
		wiz += " %s slot=%s local=%s at=%s" % [wizard.name, wizard.get("owner_slot"), wizard.call("is_local") if wizard.has_method("is_local") else "?", (wizard as Node3D).global_position.round()]
	print("AUDIO_NET trace local_slot=%d listener=%s gauge=%s %s" % [MpKit.local_slot(), SoundBus.listener_position().round(), "%.2f battle=%s" % [gauge.intensity, gauge.is_battle()] if gauge != null else "none", wiz])
	for node in get_tree().get_nodes_in_group(&"unit"):
		var unit := node as UnitBody
		if unit != null:
			print("AUDIO_NET trace   %s slot=%d at=%s mode=%d swings=%d shots=%d" % [unit.name, unit.owner_slot, unit.global_position.round(), unit.mode, unit.swings, unit.shots])
