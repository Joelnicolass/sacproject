class_name VoicePool
extends RefCounted

## A fixed set of audio players and what each one is playing right now. SoundBus keeps one pool for the world (3D), one for
## the UI and the voices (2D) and one for the loops of the emitters. It only counts and chooses: it never starts a sound.
## When every voice is busy, the one of the lowest priority (the oldest among equals) is the one to take over, unless it
## is above the newcomer.

class Voice:
	var player: Node
	var cue: SoundCue
	var started := 0.0

	func is_playing() -> bool:
		return cue != null and is_instance_valid(player) and player.playing


var voices: Array[Voice] = []


func add(player: Node, cue: SoundCue = null, started := 0.0) -> Voice:
	var voice := Voice.new()
	voice.player = player
	voice.cue = cue
	voice.started = started
	voices.append(voice)
	return voice


func size() -> int:
	return voices.size()


func holds(player: Node) -> bool:
	for voice in voices:
		if voice.player == player:
			return true
	return false


## Voices playing now, of `cue` or of any cue when null.
func active(cue: SoundCue = null) -> int:
	var count := 0
	for voice in voices:
		if voice.is_playing() and (cue == null or voice.cue == cue):
			count += 1
	return count


## An idle voice while fewer than `budget` play, else the playing one of the lowest priority (oldest among equals) when it
## is not above `priority`, else null.
func pick(priority: int, budget: int) -> Voice:
	var victim: Voice = null
	var idle: Voice = null
	var playing := 0
	for voice in voices:
		if not voice.is_playing():
			if idle == null:
				idle = voice
			continue
		playing += 1
		if victim == null or voice.cue.priority < victim.cue.priority \
				or (voice.cue.priority == victim.cue.priority and voice.started < victim.started):
			victim = voice
	if idle != null and playing < budget:
		return idle
	if victim != null and victim.cue.priority <= priority:
		return victim
	return null


## Lets go of the voice of `player` and stops it (a loop that ended).
func release(player: Node) -> void:
	for i in range(voices.size() - 1, -1, -1):
		if voices[i].player == player:
			voices.remove_at(i)
	if is_instance_valid(player):
		player.stop()


## Stops every voice. A pool of loops (`forget`) also lets go of them.
func stop_all(forget := false) -> void:
	for voice in voices:
		if is_instance_valid(voice.player):
			voice.player.stop()
		voice.cue = null
	if forget:
		voices.clear()
