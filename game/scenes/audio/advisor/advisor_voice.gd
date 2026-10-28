@tool
class_name AdvisorVoice
extends Node

## The advisor: one voice channel (the scene's `channel` player, bus of the cue: Voice) with a queue and priorities
## (VoiceQueue): a lower line never cuts a higher one, the same priority waits its turn, a higher one cuts.
## - `say(line)` is the one entry: an AdvisorLine (cue, priority, quiet_s). A line with no stream says nothing, no log entry.
## - Refusals: CommandLog.said(text, cue) carries the Refusal key the command or the server gave (`no_mana`);
##   `refusal_lines` turns it into the line that answers it. Any other message (an order's name, «Mago») says nothing.
## - The game's warnings (the local wizard attacked, a building hit, the altar desecrated...) come from the AdvisorWatch child.
## - `quiet_s` of a line: it is said when its event comes after that many game seconds without it.
## Only for the player of this process: the sources are local (CommandLog) or filtered by MpKit.local_slot(). With the
## AudioGate closed (dedicated, headless) it says nothing. No RPC, nothing written to the simulation, no global
## generator (SoundBus draws the variant).
## Ref: RFC-052 052e (F364).

## The log's event; the log's emitter is the name of the line (`low_mana advice`), as an FX sounds as its name.
const EVENT := SoundEvent.ADVICE

## Emits `said(text, cue)` (CommandLog, %Battle in the match).
@export var command_log: CommandLog
## The player the lines come out of (child of the scene).
@export var channel: AudioStreamPlayer
## Refusal key (Refusal.NO_MANA) -> the line that answers it. A key that is not here says nothing.
@export var refusal_lines: Dictionary[StringName, AdvisorLine] = {}
## Lines waiting at most behind the one speaking.
@export_range(0, 16) var max_queued := 3

var _open := false
var _queue := VoiceQueue.new()
## Line name -> game second until which it stays quiet.
var _quiet_until: Dictionary = {}
## Line name -> the line, for the ones speaking or waiting.
var _lines: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and channel != null
	if not _open:
		set_process(false)
		return
	_queue.max_queued = max_queued
	if command_log != null:
		command_log.said.connect(_on_said)


func _process(_delta: float) -> void:
	if _queue.current.is_empty() or channel.playing:
		return
	var next := _queue.finish()
	if not next.is_empty():
		_speak(_lines[next.key] as AdvisorLine)


## Says `line` now, after the line speaking or never, by its priority and quiet time. True when it reached the channel
## (speaking or waiting).
func say(line: AdvisorLine) -> bool:
	if not _open or line == null:
		return false
	var id := line.id()
	var now := BodySounds.game_seconds()
	var quiet := now < float(_quiet_until.get(id, -INF))
	_quiet_until[id] = now + line.quiet_s
	if quiet or not line.is_audible():
		return false
	_lines[id] = line
	var offer := _queue.offer(id, line.priority)
	if offer == VoiceQueue.Offer.PLAY_NOW:
		_speak(line)
	elif offer == VoiceQueue.Offer.DROPPED:
		SoundBus.log_dropped(id, EVENT, &"queue")
		return false
	return true


## The line of a Refusal key, or null (it says nothing).
func line_for_refusal(key: StringName) -> AdvisorLine:
	var line: AdvisorLine = refusal_lines.get(key)
	return line


## The cue `line` plays now, or null (gate closed, no line, no stream).
func cue_for(line: AdvisorLine) -> SoundCue:
	return line.cue if _open and line != null and line.is_audible() else null


## The name of the line speaking now (&"" when the channel is quiet).
func speaking() -> StringName:
	return _queue.current.get("key", &"")


## The names of the lines waiting, in arrival order.
func waiting() -> Array[StringName]:
	return _queue.waiting()


## Quiet now and forgets the queue and the quiet times (the lab and the cases between steps).
func reset() -> void:
	_queue.clear()
	_quiet_until.clear()
	if channel != null:
		channel.stop()


func _speak(line: AdvisorLine) -> void:
	if not SoundBus.play_on(channel, line.cue, line.id(), EVENT):
		channel.stop()


func _on_said(text: String, _cue: StringName) -> void:
	var line := line_for_refusal(StringName(text))
	if line != null:
		say(line)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if command_log == null:
		out.append("Asigná `command_log` (%Battle): sin él los rechazos no hablan.")
	if channel == null:
		out.append("Asigná `channel` (el AudioStreamPlayer hijo): sin él el consejero no habla.")
	var refusal_script: GDScript = Refusal
	var known: Array = refusal_script.get_script_constant_map().values()
	for key: StringName in refusal_lines:
		if not known.has(key):
			out.append("`refusal_lines` tiene la clave «%s» y no existe en Refusal." % key)
	return out
