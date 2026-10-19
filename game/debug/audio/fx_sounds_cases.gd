extends RefCounted

## RFC-052 052d (F363): the FX sounds and the SoundEmitter3D.
## Open gate (--audio-probe):
## - fx_map_lookup: FxSoundMap answers a burst, a beam and a scene by its file name; a puff, a missing key and a silent
##   cue are null.
## - fx_bridge: FxBus.play("blood") leaves a played entry (emitter blood, event fx); a puff and an FX with no key leave none.
## - fx_custom_wins: with two roots, the first answers its keys and the second the rest (key by key).
## - loop_budget: three loops held, then 200 requests in one frame: the 3D voices (pool + loops) stay <= pool_3d_size and
##   the loops are still held; past max_loops_3d a claim is refused (loops_full).
## - emitter_one_shot: a SoundEmitter3D with play_on_ready plays its cue once on entering the tree.
## Closed gate (plain headless, --dedicated, --room-server):
## - emitter_closed: a SoundEmitter3D (one-shot and loop) enters the tree, and neither its table nor a stream is loaded.

const FIXTURE_ROOT := "res://debug/audio/fixtures/lab/"
const FIXTURE_MAP := "res://debug/audio/fixtures/lab/fx_sounds.tres"
const EMITTER_SCENE := "res://scenes/audio/sound_emitter_3d.tscn"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["emitter_closed"] = await _emitter_closed(host)
		return results
	if not SoundBus.is_active():
		results["fx_sounds_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["fx_map_lookup"] = _map_lookup()
	results["fx_bridge"] = await _bridge(host)
	results["fx_custom_wins"] = _custom_wins()
	results["loop_budget"] = await _loop_budget(host)
	results["emitter_one_shot"] = await _emitter_one_shot(host)
	SoundBus.stop_all()
	SoundLibrary.reset_roots()
	return results


func _cue(streams: Array[AudioStream]) -> SoundCue:
	var cue := SoundCue.new()
	cue.streams = streams
	cue.max_voices = 0
	return cue


func _beep() -> AudioStream:
	return load("res://debug/audio/fixtures/beep_a.tres")


func _map_lookup() -> Dictionary:
	var map := FxSoundMap.new()
	var cue := _cue([_beep()])
	map.cues = {&"blood": cue, &"lightning": cue, &"spike_field": cue, &"mute": SoundCue.new()}
	var burst := map.fx_cue(FxBus.KIND_BURST, "blood") == cue
	var beam := map.fx_cue(FxBus.KIND_BEAM, "lightning") == cue
	var scene := map.fx_cue(FxBus.KIND_SCENE, "res://scenes/fx/spike_field.tscn") == cue
	var puff := map.fx_cue(FxBus.KIND_PUFF, "blood") == null
	var missing := map.fx_cue(FxBus.KIND_BURST, "dirt") == null
	var silent := map.fx_cue(FxBus.KIND_BURST, "mute") == null
	return {"ok": burst and beam and scene and puff and missing and silent, "burst": burst, "beam": beam, "scene": scene,
		"puff": puff, "missing": missing, "silent": silent}


func _bridge(host: Node) -> Dictionary:
	SoundBus.stop_all()
	SoundLibrary.roots = PackedStringArray([FIXTURE_ROOT, EMPTY_ROOT])
	SoundLibrary.clear_cache()
	await host.get_tree().process_frame
	SoundBus.sound_log.clear()
	var before := SoundBus.sound_log.size()
	FxBus.play("blood", Vector3(1, 0, 0))
	var last: Dictionary = SoundBus.sound_log.last()
	var blood: bool = SoundBus.sound_log.size() == before + 1 and last.get("emitter") == &"blood" \
		and last.get("event") == SoundEvent.FX and bool(last.get("played"))
	var after_blood := SoundBus.sound_log.size()
	FxBus.play_puff("blood", Vector3(2, 0, 0))
	FxBus.play("dirt", Vector3(3, 0, 0))
	var quiet := SoundBus.sound_log.size() == after_blood
	FxBus.play_beam("lightning", Vector3(0, 4, 0), Vector3.ZERO)
	var beam: bool = SoundBus.sound_log.last().get("emitter") == &"lightning"
	SoundLibrary.reset_roots()
	return {"ok": blood and quiet and beam, "blood": blood, "puff_and_missing_quiet": quiet, "beam": beam}


## A custom root first: its keys win, the rest comes from the next root.
func _custom_wins() -> Dictionary:
	SoundLibrary.roots = PackedStringArray(["res://debug/audio/fixtures/fx_custom/", FIXTURE_ROOT])
	SoundLibrary.clear_cache()
	var custom := SoundBus.fx_cue(FxBus.KIND_BURST, "blood")
	var fallback := SoundBus.fx_cue(FxBus.KIND_BEAM, "lightning")
	var fixture := load(FIXTURE_MAP) as FxSoundMap
	var ok: bool = custom != null and fixture != null and custom != fixture.cues.get(&"blood") \
		and fallback == fixture.cues.get(&"lightning")
	SoundLibrary.reset_roots()
	return {"ok": ok, "custom": custom != null, "fallback": fallback != null}


func _loop_budget(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var loop_cue := _cue([_beep()])
	loop_cue.priority = 100
	var players: Array[AudioStreamPlayer3D] = []
	for i in SoundBus.max_loops_3d + 1:
		var player := AudioStreamPlayer3D.new()
		host.add_child(player)
		players.append(player)
	var held := 0
	for i in 3:
		if SoundBus.claim_loop(players[i], loop_cue, &"case_loop"):
			held += 1
	var cues := []
	for i in 10:
		var cue := _cue([_beep()])
		cue.priority = i * 10
		cues.append(cue)
	for i in 200:
		SoundBus.play_3d(cues[i % cues.size()], Vector3(i, 0, 0), &"case", SoundEvent.FX)
	var active := SoundBus.active_voices(true)
	var loops_kept := SoundBus.active_loops() == 3
	for i in range(3, SoundBus.max_loops_3d):
		SoundBus.claim_loop(players[i], loop_cue, &"case_loop")
	var refused: bool = not SoundBus.claim_loop(players[SoundBus.max_loops_3d], loop_cue, &"case_loop") \
		and SoundBus.sound_log.last().get("reason") == &"loops_full"
	var capped := SoundBus.active_voices(true) <= SoundBus.pool_size(true)
	for player in players:
		SoundBus.release_loop(player)
		player.queue_free()
	var released := SoundBus.active_loops() == 0
	var ok: bool = held == 3 and active <= SoundBus.pool_size(true) and active > 3 and loops_kept and refused and capped and released
	return {"ok": ok, "held": held, "active": active, "pool": SoundBus.pool_size(true), "loops_kept": loops_kept,
		"refused": refused, "capped": capped, "released": released}


func _emitter_one_shot(host: Node) -> Dictionary:
	SoundBus.stop_all()
	SoundLibrary.roots = PackedStringArray([FIXTURE_ROOT, EMPTY_ROOT])
	SoundLibrary.clear_cache()
	await host.get_tree().process_frame
	var holder := Node3D.new()
	holder.name = "CaseProjectile"
	var emitter := (load(EMITTER_SCENE) as PackedScene).instantiate() as SoundEmitter3D
	emitter.cue = &"fireball_cast"
	holder.add_child(emitter)
	SoundBus.sound_log.clear()
	var before := SoundBus.sound_log.size()
	host.add_child(holder)
	var last: Dictionary = SoundBus.sound_log.last()
	var played: bool = SoundBus.sound_log.size() == before + 1 and last.get("emitter") == &"CaseProjectile" \
		and last.get("event") == SoundEvent.CAST and bool(last.get("played"))
	holder.queue_free()
	var missing := (load(EMITTER_SCENE) as PackedScene).instantiate() as SoundEmitter3D
	missing.cue = &"no_such_key"
	var count := SoundBus.sound_log.size()
	host.add_child(missing)
	var quiet := SoundBus.sound_log.size() == count
	missing.queue_free()
	SoundLibrary.reset_roots()
	return {"ok": played and quiet, "played": played, "missing_quiet": quiet}


func _emitter_closed(host: Node) -> Dictionary:
	var packed := load(EMITTER_SCENE) as PackedScene
	var one_shot := packed.instantiate() as SoundEmitter3D
	one_shot.cue = &"fireball_cast"
	var looped := packed.instantiate() as SoundEmitter3D
	looped.cue = &"fountain_loop"
	looped.loop = true
	host.add_child(one_shot)
	host.add_child(looped)
	for i in 3:
		await host.get_tree().process_frame
	var nothing := one_shot.stream == null and looped.stream == null and not looped.playing \
		and one_shot.resolved_cue() == null and looped.resolved_cue() == null
	var not_cached := not ResourceLoader.has_cached(FIXTURE_MAP) and not ResourceLoader.has_cached("res://data/audio/fx_sounds.tres") \
		and not ResourceLoader.has_cached("res://debug/audio/fixtures/beep_a.tres")
	one_shot.queue_free()
	looped.queue_free()
	return {"ok": nothing and not_cached, "nothing": nothing, "not_cached": not_cached}
