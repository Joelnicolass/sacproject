extends RefCounted

## RFC-052 052a (F360): SoundBus with the gate open (--audio-probe): the per-cue voice limit, the cooldown, the priority
## steal when a pool is full, the 3D pool cap under 200 requests in one frame, its own generator (same seed, same
## variants) and the global generator left alone. Also measures whether an AudioStreamRandomizer draws from the global
## generator (the reason RFC-052 §8 forbids it): the finding is printed, the case passes either way.

## Loaded when the cases run (not preloaded): the closed-gate runs must not have them in the cache.
var STREAM_A: AudioStream
var STREAM_B: AudioStream


func run(host: Node) -> Dictionary:
	var results := {}
	STREAM_A = load("res://debug/audio/fixtures/beep_a.tres")
	STREAM_B = load("res://debug/audio/fixtures/beep_b.tres")
	if not SoundBus.is_active():
		results["sound_bus_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["sound_bus_voice_limit"] = await _voice_limit(host)
	results["sound_bus_cooldown"] = await _cooldown(host)
	results["sound_bus_priority"] = await _priority(host)
	results["sound_bus_pool_cap"] = await _pool_cap(host)
	results["sound_bus_own_rng"] = await _own_rng(host)
	results["sound_bus_global_rng"] = await _global_rng(host)
	results["audio_randomizer_global_rng"] = await _randomizer(host)
	SoundBus.stop_all()
	return results


func _cue(max_voices := 0, cooldown := 0.0, priority := 50, jitter := 0.0) -> SoundCue:
	var cue := SoundCue.new()
	cue.streams = [STREAM_A, STREAM_B]
	cue.max_voices = max_voices
	cue.cooldown_s = cooldown
	cue.priority = priority
	cue.pitch_jitter = jitter
	return cue


func _voice_limit(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var cue := _cue(2)
	var played := 0
	for i in 5:
		if SoundBus.play_3d(cue, Vector3(i, 0, 0), &"case", SoundEvent.SWING):
			played += 1
	var active := SoundBus.active_voices(true, cue)
	var last: Dictionary = SoundBus.sound_log.last()
	return {"ok": played == 2 and active == 2 and last.get("reason") == &"max_voices", "played": played, "active": active}


func _cooldown(host: Node) -> Dictionary:
	SoundBus.stop_all()
	var cue := _cue(0, 0.1)
	var first := SoundBus.play_2d(cue, &"case", SoundEvent.DAMAGED)
	var again := SoundBus.play_2d(cue, &"case", SoundEvent.DAMAGED)
	var reason: StringName = SoundBus.sound_log.last().get("reason", &"")
	await host.get_tree().create_timer(0.15, true).timeout
	var later := SoundBus.play_2d(cue, &"case", SoundEvent.DAMAGED)
	return {"ok": first and not again and reason == &"cooldown" and later, "first": first, "again": again, "later": later}


func _priority(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var low := _cue(0, 0.0, 10)
	var lower := _cue(0, 0.0, 5)
	var high := _cue(0, 0.0, 90)
	var size := SoundBus.pool_size(false)
	for i in size:
		SoundBus.play_2d(low, &"case", SoundEvent.CLICK)
	var full := SoundBus.active_voices(false) == size
	var lower_played := SoundBus.play_2d(lower, &"case", SoundEvent.CLICK)
	var lower_reason: StringName = SoundBus.sound_log.last().get("reason", &"")
	var high_played := SoundBus.play_2d(high, &"case", SoundEvent.ADVICE)
	var ok := full and not lower_played and lower_reason == &"pool_full" and high_played \
		and SoundBus.active_voices(false, low) == size - 1 and SoundBus.active_voices(false, high) == 1
	return {"ok": ok, "full": full, "lower_played": lower_played, "high_played": high_played}


func _pool_cap(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var cues := []
	for i in 10:
		cues.append(_cue(0, 0.0, i * 10))
	for i in 200:
		SoundBus.play_3d(cues[i % cues.size()], Vector3(i, 0, 0), &"case", SoundEvent.FX)
	var active := SoundBus.active_voices(true)
	return {"ok": active <= SoundBus.pool_size(true) and active > 0, "active": active, "pool": SoundBus.pool_size(true)}


## Same seed, same variants.
func _own_rng(host: Node) -> Dictionary:
	var runs := []
	for attempt in 2:
		SoundBus.stop_all()
		await host.get_tree().process_frame
		SoundBus.reseed(42)
		var cue := _cue(0, 0.0, 50, 0.2)
		var picks := []
		for i in 8:
			SoundBus.play_2d(cue, &"case", SoundEvent.SELECTED)
			picks.append(SoundBus.sound_log.last().get("stream", ""))
		runs.append(picks)
	var both_variants: bool = runs[0].has(STREAM_A.resource_path) and runs[0].has(STREAM_B.resource_path)
	return {"ok": runs[0] == runs[1] and both_variants, "picks": runs[0]}


## Seed the global generator, play cues with jitter and variants through SoundBus, compare the next randi().
func _global_rng(host: Node) -> Dictionary:
	SoundBus.stop_all()
	await host.get_tree().process_frame
	seed(777)
	var expected := randi()
	seed(777)
	var cue := _cue(0, 0.0, 50, 0.3)
	for i in 6:
		SoundBus.play_3d(cue, Vector3(i, 0, 0), &"case", SoundEvent.DEATH)
	var right_after := randi()
	seed(777)
	for i in 6:
		SoundBus.play_2d(cue, &"case", SoundEvent.DEATH)
	for i in 5:
		await host.get_tree().process_frame
	var after_frames := randi()
	return {"ok": right_after == expected and after_frames == expected, "expected": expected,
		"right_after": right_after, "after_frames": after_frames}


## The finding of RFC-052 §8: does playing an AudioStreamRandomizer draw from the global generator?
## Control: a plain AudioStreamPlayer with a WAV, same seed.
func _randomizer(host: Node) -> Dictionary:
	SoundBus.stop_all()
	var plain := AudioStreamPlayer.new()
	plain.stream = STREAM_A
	var player := AudioStreamPlayer.new()
	var randomizer := AudioStreamRandomizer.new()
	randomizer.add_stream(0, STREAM_A)
	randomizer.add_stream(1, STREAM_B)
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM
	randomizer.random_pitch = 1.2
	randomizer.random_volume_offset_db = 2.0
	player.stream = randomizer
	host.add_child(plain)
	host.add_child(player)
	seed(4242)
	var expected := randi()
	seed(4242)
	plain.play()
	var plain_after := randi()
	seed(4242)
	player.play()
	var randomizer_after := randi()
	seed(4242)
	for i in 3:
		player.stop()
		player.play()
	for i in 5:
		await host.get_tree().process_frame
	var randomizer_after_frames := randi()
	player.queue_free()
	plain.queue_free()
	var touched := randomizer_after != expected or randomizer_after_frames != expected
	print("AUDIO_RNG_FINDING AudioStreamRandomizer %s el generador global (plain %s)" % [
		"TOCA" if touched else "NO toca", "toca" if plain_after != expected else "no toca"])
	return {"ok": plain_after == expected, "randomizer_touches_global": touched, "plain_touches_global": plain_after != expected}
