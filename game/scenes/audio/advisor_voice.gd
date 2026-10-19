@tool
class_name AdvisorVoice
extends Node

## RFC-052 052e (F364): the advisor, one voice channel (its own AudioStreamPlayer, bus of the cue: Voice) with a queue and
## priorities (VoiceQueue): a lower line never cuts a higher one, the same priority waits its turn, a higher one cuts.
## - `say(code)` is the one entry: `code` is a key of the advisor set (data/audio/advisor.tres, the original's `advi` codes:
##   `lowm`, `watt`, `dese`...; data/audio/README.md has the table). No set or no cue for it: silence, no log entry.
## - Refusals: CommandLog.said(text, cue) carries the Refusal key the command or the server gave (`no_mana`); `refusal_events`
##   turns it into a code (`lowm`). Any other message (an order's name, «Mago») says nothing.
## - The game's warnings (the local wizard attacked, a building hit, the altar desecrated...) come from the AdvisorWatch child.
## - `cooldowns`: a code is said when its event comes after that many game seconds without it (each event pushes the quiet
##   on, as the original's advisor cooldowns do): a fight that goes on says «under attack» once.
## Only for the player of this process: the sources are local (CommandLog) or filtered by MpKit.local_slot(). With the
## AudioGate closed (dedicated, room server, headless) it creates nothing and says nothing. No RPC, nothing written to the
## simulation, no global generator (SoundBus draws the variant).

enum Priority { ANNOY, IMPORTANT, CRUCIAL }

## The emitter's log event; the log's emitter is the code (`lowm advice`), as an FX sounds as its name.
const EVENT := SoundEvent.ADVICE

## Emits `said(text, cue)` (CommandLog, %Battle in the match).
@export var command_log: CommandLog
## SoundLibrary path of the advisor's set.
@export var set_path := "advisor"
## Refusal key (Refusal, &"no_mana") -> advisor code. A key that is not here says nothing.
@export var refusal_events: Dictionary[StringName, StringName] = {
	&"no_mana": &"lowm",
	&"cooling": &"nred",
	&"out_of_range": &"orng",
	&"bad_target": &"invl",
	&"no_target": &"invl",
	&"no_souls": &"spir",
	&"far_from_altar": &"ealt",
}
## Code -> Priority. A code that is not here has `default_priority` (the refusals: ANNOY).
@export var priorities: Dictionary[StringName, int] = {
	&"dese": Priority.CRUCIAL,
	&"bdam": Priority.CRUCIAL,
	&"whlt": Priority.CRUCIAL,
	&"watt": Priority.IMPORTANT,
	&"uatt": Priority.IMPORTANT,
	&"bdst": Priority.IMPORTANT,
	&"cdie": Priority.IMPORTANT,
	&"sacc": Priority.IMPORTANT,
}
@export var default_priority: Priority = Priority.ANNOY
## Code -> game seconds of quiet before it is said again (the original's advisor cooldowns). Not here: `default_cooldown_s`.
@export var cooldowns: Dictionary[StringName, float] = {
	&"watt": 15.0,
	&"uatt": 15.0,
	&"bdam": 5.0,
	&"whlt": 5.0,
	&"cdie": 5.0,
	&"lowm": 5.0,
	&"dese": 5.0,
	&"bdst": 1.0,
}
@export_range(0.0, 60.0, 0.1, "suffix:s") var default_cooldown_s := 2.0
## Lines waiting at most behind the one speaking.
@export_range(0, 16) var max_queued := 3

var _open := false
var _player: AudioStreamPlayer
var _queue := VoiceQueue.new()
## Code -> game second until which it stays quiet.
var _quiet_until: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open()
	if not _open:
		set_process(false)
		return
	_queue.max_queued = max_queued
	_player = AudioStreamPlayer.new()
	_player.name = "Channel"
	add_child(_player)
	if command_log != null:
		command_log.said.connect(_on_said)


func _process(_delta: float) -> void:
	if _queue.current.is_empty() or _player.playing:
		return
	var next := _queue.finish()
	if not next.is_empty():
		_speak(next.key)


## Says `code` now, after the line speaking or never, by its priority and cooldown. True when it reached the channel
## (speaking or waiting).
func say(code: StringName) -> bool:
	if not _open or code.is_empty():
		return false
	var now := BodySounds.game_seconds()
	var quiet := now < float(_quiet_until.get(code, -INF))
	_quiet_until[code] = now + cooldown_of(code)
	if quiet or cue_for(code) == null:
		return false
	var offer := _queue.offer(code, priority_of(code))
	if offer == VoiceQueue.Offer.PLAY_NOW:
		_speak(code)
	elif offer == VoiceQueue.Offer.DROPPED:
		SoundBus.log_dropped(code, EVENT, &"queue")
		return false
	return true


## The line of a Refusal key, or &"" (it says nothing).
func code_for_refusal(key: StringName) -> StringName:
	return refusal_events.get(key, &"")


func priority_of(code: StringName) -> int:
	return int(priorities.get(code, default_priority))


func cooldown_of(code: StringName) -> float:
	return float(cooldowns.get(code, default_cooldown_s))


## The cue of `code` in the advisor's set, or null (no set, no cue: silence).
func cue_for(code: StringName) -> SoundCue:
	if not _open:
		return null
	var advisor := SoundLibrary.sound_set(set_path)
	var cue := advisor.cue(code) if advisor != null else null
	return cue if cue != null and not cue.is_silent() else null


## The code speaking now (&"" when the channel is quiet).
func speaking() -> StringName:
	return _queue.current.get("key", &"")


## The codes waiting, in arrival order.
func waiting() -> Array[StringName]:
	return _queue.waiting()


## Quiet now and forgets the queue and the cooldowns (the lab and the cases between steps).
func reset() -> void:
	_queue.clear()
	_quiet_until.clear()
	if _player != null:
		_player.stop()


func _speak(code: StringName) -> void:
	if not SoundBus.play_on(_player, cue_for(code), code, EVENT):
		_player.stop()


func _on_said(text: String, _cue: StringName) -> void:
	var code := code_for_refusal(StringName(text))
	if not code.is_empty():
		say(code)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if command_log != null else PackedStringArray(["Asigná `command_log` (%Battle): sin él los rechazos no hablan."])
