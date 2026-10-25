extends RefCounted

## The sets made from the original's audio load, and their streams are what the importer wrote:
## - with the import (assets/original/audio/index.json): the `sounds` of the creature CREATURE resolve; the swing of its melee
##   fallback (fist) is an AudioStreamWAV at 22050 Hz, 16 bit or QOA mono, whose length is the file's PCM; its `selected`
##   voice is a non-empty stream on the Voice bus.
## - without it (the folder moved aside): the world set gives null, silently.
## Runs only with the gate open (`--audio-probe`).

const INDEX := "res://assets/original/audio/index.json"
const CREATURE := &"plfl"   # Gnome (gnom voice set, fist melee set): both kinds of stream
const RATE := 22050
const WAV_HEADER := 44


func run(_host: Node) -> Dictionary:
	SoundLibrary.reset_roots()
	var imported := FileAccess.file_exists(INDEX)
	var type: CreatureType = GameData.creature(String(CREATURE))
	var sound_set: SoundSet = type.sounds if type != null else null
	if not imported:
		return {"original_sets_absent": {"ok": SoundLibrary.sound_set("world") == null,
			"note": "sin import del original: silencio", "set_found": sound_set != null}}
	var results := {}
	results["original_sets_creature"] = _creature(sound_set)
	results["original_sets_world"] = _named("world", [&"sacrifice_round", &"sacrifice_end", &"soul"])
	results["original_sets_ui"] = _named("ui", [&"click"])
	SoundLibrary.clear_cache()
	return results


func _creature(sound_set: SoundSet) -> Dictionary:
	if sound_set == null:
		return {"ok": false, "reason": "no set for %s" % CREATURE}
	## The WAV kind comes from the melee fallback (fist): the gnome's own `swing` is a voice (OGG), as it sounded before.
	var swing: SoundCue = sound_set.fallback.cue(SoundEvent.SWING) if sound_set.fallback != null else null
	var voice := sound_set.cue(SoundEvent.SELECTED)
	var info := {"has_swing": swing != null, "has_voice": voice != null, "fallback": sound_set.fallback != null}
	if swing == null or voice == null or swing.streams.is_empty() or voice.streams.is_empty():
		info["ok"] = false
		return info
	var wav := swing.streams[0] as AudioStreamWAV
	info["swing_class"] = swing.streams[0].get_class()
	if wav != null:
		var bytes := FileAccess.get_file_as_bytes(wav.resource_path).size()
		var expected := float(bytes - WAV_HEADER) / 2.0 / RATE
		info["swing_path"] = wav.resource_path
		info["mix_rate"] = wav.mix_rate
		# The importer's default compression (QOA in Godot 4.3+) or plain 16 bit: both keep every sample (the length).
		info["format"] = {AudioStreamWAV.FORMAT_16_BITS: "16 bit", AudioStreamWAV.FORMAT_QOA: "QOA"}.get(wav.format, str(wav.format))
		info["stereo"] = wav.stereo
		info["length_s"] = snappedf(wav.get_length(), 0.0001)
		info["expected_s"] = snappedf(expected, 0.0001)
		info["swing_bus"] = swing.bus
	var voice_stream := voice.streams[0]
	info["voice_class"] = voice_stream.get_class()
	info["voice_length_s"] = snappedf(voice_stream.get_length(), 0.001)
	info["voice_bus"] = voice.bus
	info["ok"] = wav != null and wav.mix_rate == RATE and wav.format in [AudioStreamWAV.FORMAT_16_BITS, AudioStreamWAV.FORMAT_QOA] and not wav.stereo \
		and absf(wav.get_length() - info.expected_s) < 0.001 and wav.get_length() > 0.0 \
		and voice_stream.get_length() > 0.0 and voice_stream.get_length() < 30.0 \
		and voice.bus == &"Voice" and swing.bus == &"SFX"
	return info


func _named(rel: String, events: Array) -> Dictionary:
	var sound_set := SoundLibrary.sound_set(rel)
	if sound_set == null:
		return {"ok": false, "reason": "no %s.tres" % rel}
	var missing := events.filter(func(event: StringName) -> bool:
		var cue := sound_set.cue(event)
		return cue == null or cue.is_silent())
	return {"ok": missing.is_empty(), "missing": missing, "cues": sound_set.cues.size()}
