extends RefCounted

## RFC-052 052d (F363), typed in 055o-a: the FX sounds and the SoundEmitter3D.
## Open gate (--audio-probe):
## - fx_type_sound: FxSounds answers a burst with the `sound` of its ParticleType and a beam with the one of its BeamType;
##   a puff, a scene, a type with no sound and a name with no type are null.
## - fx_bridge: FxBus.play(blood) leaves a played entry (emitter blood, event fx); a puff and an FX with no sound leave none.
## - loop_budget: three loops held, then 200 requests in one frame: the 3D voices (pool + loops) stay <= pool_3d_size and
##   the loops are still held; past max_loops_3d a claim is refused (loops_full).
## - emitter_one_shot: a SoundEmitter3D with play_on_ready plays its cue once on entering the tree; one with no cue is silent.
## Closed gate (plain headless, --dedicated, --room-server):
## - emitter_closed: a SoundEmitter3D (one-shot and loop) with its cue enters the tree and nothing plays nor is claimed.

const EMITTER_SCENE := "res://scenes/audio/sound_emitter_3d.tscn"
const BLOOD := "res://data/fx/blood.tres"
const LIGHTNING := "res://data/fx/beams/lightning.tres"
const DIRT := "res://data/fx/dirt.tres"
const FIREBALL_CAST := "res://data/audio/cues/fireball_cast.tres"
const FOUNTAIN_LOOP := "res://data/audio/cues/fountain_loop.tres"


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["emitter_closed"] = await _emitter_closed(host)
		return results
	if not SoundBus.is_active():
		results["fx_sounds_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["fx_type_sound"] = _type_sound()
	results["fx_bridge"] = await _bridge(host)
	results["loop_budget"] = await _loop_budget(host)
	results["emitter_one_shot"] = await _emitter_one_shot(host)
	SoundBus.stop_all()
	return results


func _cue(streams: Array[AudioStream]) -> SoundCue:
	var cue := SoundCue.new()
	cue.streams = streams
	cue.max_voices = 0
	return cue


func _beep() -> AudioStream:
	return load("res://debug/audio/fixtures/beep_a.tres")


func _type_sound() -> Dictionary:
	var fx: FxSounds = SoundBus.fx_sounds
	var blood := load(BLOOD) as ParticleType
	var lightning := load(LIGHTNING) as BeamType
	var burst := blood != null and blood.sound != null and fx.cue_of(FxBus.KIND_BURST, blood) == blood.sound
	var beam := lightning != null and lightning.sound != null and fx.cue_of(FxBus.KIND_BEAM, lightning) == lightning.sound
	var puff := fx.cue_of(FxBus.KIND_PUFF, blood) == null
	var scene := fx.cue_of(FxBus.KIND_SCENE, load("res://scenes/fx/spike_field.tscn") as PackedScene) == null
	var no_sound := fx.cue_of(FxBus.KIND_BURST, load(DIRT) as ParticleType) == null
	var no_type := fx.cue_of(FxBus.KIND_BURST, null) == null
	return {"ok": burst and beam and puff and scene and no_sound and no_type, "burst": burst, "beam": beam, "puff": puff,
		"scene": scene, "no_sound": no_sound, "no_type": no_type}


func _bridge(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	SoundBus.sound_log.clear()
	var before: int = SoundBus.sound_log.size()
	var blood_type := load(BLOOD) as ParticleType
	FxBus.play(blood_type, Vector3(1, 0, 0))
	var last: Dictionary = SoundBus.sound_log.last()
	var blood: bool = SoundBus.sound_log.size() == before + 1 and last.get("emitter") == &"blood" \
		and last.get("event") == SoundEvent.FX and bool(last.get("played"))
	var after_blood: int = SoundBus.sound_log.size()
	FxBus.puff(blood_type, Vector3(2, 0, 0))
	FxBus.play(load(DIRT) as ParticleType, Vector3(3, 0, 0))
	var quiet: bool = SoundBus.sound_log.size() == after_blood
	FxBus.play_beam(load(LIGHTNING) as BeamType, Vector3(0, 4, 0), Vector3.ZERO)
	var beam: bool = SoundBus.sound_log.last().get("emitter") == &"lightning"
	return {"ok": blood and quiet and beam, "blood": blood, "puff_and_missing_quiet": quiet, "beam": beam}


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
	var active: int = SoundBus.active_voices(true)
	var loops_kept: bool = SoundBus.active_loops() == 3
	for i in range(3, SoundBus.max_loops_3d):
		SoundBus.claim_loop(players[i], loop_cue, &"case_loop")
	var refused: bool = not SoundBus.claim_loop(players[SoundBus.max_loops_3d], loop_cue, &"case_loop") \
		and SoundBus.sound_log.last().get("reason") == &"loops_full"
	var capped: bool = SoundBus.active_voices(true) <= SoundBus.pool_size(true)
	for player in players:
		SoundBus.release_loop(player)
		player.queue_free()
	var released: bool = SoundBus.active_loops() == 0
	var ok: bool = held == 3 and active <= SoundBus.pool_size(true) and active > 3 and loops_kept and refused and capped and released
	return {"ok": ok, "held": held, "active": active, "pool": SoundBus.pool_size(true), "loops_kept": loops_kept,
		"refused": refused, "capped": capped, "released": released}


func _emitter_one_shot(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var holder := Node3D.new()
	holder.name = "CaseProjectile"
	var emitter := (load(EMITTER_SCENE) as PackedScene).instantiate() as SoundEmitter3D
	emitter.cue = _cue([_beep()])
	holder.add_child(emitter)
	SoundBus.sound_log.clear()
	var before: int = SoundBus.sound_log.size()
	host.add_child(holder)
	var last: Dictionary = SoundBus.sound_log.last()
	var played: bool = SoundBus.sound_log.size() == before + 1 and last.get("emitter") == &"CaseProjectile" \
		and last.get("event") == SoundEvent.CAST and bool(last.get("played"))
	holder.queue_free()
	var no_cue := (load(EMITTER_SCENE) as PackedScene).instantiate() as SoundEmitter3D
	var count: int = SoundBus.sound_log.size()
	host.add_child(no_cue)
	var quiet: bool = SoundBus.sound_log.size() == count
	no_cue.queue_free()
	return {"ok": played and quiet, "played": played, "no_cue_quiet": quiet}


func _emitter_closed(host: Node) -> Dictionary:
	var packed := load(EMITTER_SCENE) as PackedScene
	var one_shot := packed.instantiate() as SoundEmitter3D
	one_shot.cue = load(FIREBALL_CAST) as SoundCue
	var looped := packed.instantiate() as SoundEmitter3D
	looped.cue = load(FOUNTAIN_LOOP) as SoundCue
	looped.loop = true
	host.add_child(one_shot)
	host.add_child(looped)
	for i in 3:
		await host.get_tree().process_frame
	var nothing := one_shot.stream == null and looped.stream == null and not one_shot.playing and not looped.playing \
		and not one_shot.play_once() and not looped.is_looping() and not SoundBus.is_active()
	one_shot.queue_free()
	looped.queue_free()
	return {"ok": nothing, "nothing": nothing}
