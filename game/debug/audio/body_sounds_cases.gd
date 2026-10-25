extends RefCounted

## 055o-b: how a body finds its cue, with sets made here (no audio file, no original).
## - A creature's own field wins; an empty field asks the `fallback` set (the melee set); nothing: silence.
## - `summon` of the set wins over UnitSounds.summon; a creature with no set still has the summon sound; a silent cue is silence.
## - A wizard has no summon: its set or nothing.
## - CommandVoice reads the same set (the look's `sounds`) of the creature it hears.
## Runs only with the gate open (`--audio-probe`).

const _LOOK := preload("res://debug/audio/sound_look.gd")


func run(host: Node) -> Dictionary:
	var results := {}
	var melee_swing := _cue()
	var own_death := _cue()
	var own_swing := _cue()
	var melee := SoundSet.new()
	melee.swing = melee_swing
	var own := SoundSet.new()
	own.death = own_death
	own.fallback = melee
	var summon := _cue()
	var set_summon := _cue()

	var unit := _unit(host, own, summon)
	results["body_sounds_fields"] = {
		"ok": unit.cue_for(SoundEvent.DEATH) == own_death and unit.cue_for(SoundEvent.SWING) == melee_swing \
			and unit.cue_for(SoundEvent.SHOOT) == null and unit.cue_for(SoundEvent.DAMAGED) == null,
	}
	own.swing = own_swing
	own.summon = set_summon
	results["body_sounds_own_wins"] = {"ok": unit.cue_for(SoundEvent.SWING) == own_swing and unit.cue_for(SoundEvent.SUMMON) == set_summon}
	own.summon = null
	results["body_sounds_summon_default"] = {"ok": unit.cue_for(SoundEvent.SUMMON) == summon}
	own.summon = SoundCue.new()
	results["body_sounds_silent_cue"] = {"ok": unit.cue_for(SoundEvent.SUMMON) == null}
	_free(unit)

	var bare := _unit(host, null, summon)
	results["body_sounds_no_set"] = {"ok": bare.cue_for(SoundEvent.SUMMON) == summon and bare.cue_for(SoundEvent.DEATH) == null}
	_free(bare)

	var wizard_set := SoundSet.new()
	wizard_set.incantation = _cue()
	results["body_sounds_wizard"] = {"ok": BodySounds.resolve(wizard_set, SoundEvent.INCANTATION) == wizard_set.incantation \
		and BodySounds.resolve(wizard_set, SoundEvent.SUMMON) == null and BodySounds.resolve(null, SoundEvent.DEATH) == null}

	var voice := CommandVoice.new()
	voice.channel = AudioStreamPlayer.new()
	voice.add_child(voice.channel)
	host.add_child(voice)
	var speaker := UnitBody.new()
	speaker.type = CreatureType.new()
	_LOOK.give(speaker, own)
	var selected := _cue()
	own.selected = selected
	results["body_sounds_command_voice"] = {"ok": voice.cue_for(speaker, SoundEvent.SELECTED) == selected \
		and voice.cue_for(speaker, SoundEvent.ANNOYED) == null}
	speaker.free()
	voice.queue_free()
	return results


## A cue with one stream made here (not loaded from a file).
func _cue() -> SoundCue:
	var stream := AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 40, 0, 216])
	var cue := SoundCue.new()
	cue.streams = [stream]
	return cue


## A UnitSounds on a creature that is not in the tree, with `sounds` in its look and `summon` as the shared summon cue.
func _unit(host: Node, sounds: SoundSet, summon: SoundCue) -> UnitSounds:
	var body := UnitBody.new()
	body.type = CreatureType.new()
	_LOOK.give(body, sounds)
	var sounds_node := UnitSounds.new()
	sounds_node.body = body
	sounds_node.health = Health.new()
	sounds_node.summon = summon
	host.add_child(sounds_node)
	return sounds_node


func _free(sounds_node: UnitSounds) -> void:
	sounds_node.body.free()
	sounds_node.health.free()
	sounds_node.queue_free()
