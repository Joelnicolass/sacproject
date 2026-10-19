class_name CommandLog
extends Node

## What the local command is doing, as state and not as words (RFC-025c). It replaces the Label
## that used to draw «Elegí el blanco», «N unidades», the refusals and so on: nothing here is drawn.
## `armed` says which icon waits for its target (`""`, `spell`, `structure`, `ability`, `attack`,
## `guard`, `move`), `armed_icon` the tag of its image in the local cache and `text` the last
## message, kept for the flows and the log. CommandCue and CursorSkin draw from the signals.
## The name stays `Battle` in the scenes so the flows that read `%Battle` keep working.

signal armed_changed(kind: String, icon_tag: String)
signal said(text: String, cue: StringName)

## Words -> cue («Sin maná» is a refusal). Without it every message is only text.
@export var cues: CueSet

var armed := ""
var armed_icon := ""
## Classes of target (TargetProbe) the armed icon can land on; empty = any.
var armed_accepts := PackedStringArray()
var text := ""


## Something waits for its target. `prompt` is the old line, kept in `text` and not drawn.
func arm(kind: String, icon_tag: String, prompt := "", accepts := PackedStringArray()) -> void:
	armed = kind
	armed_icon = icon_tag
	armed_accepts = accepts
	if not prompt.is_empty():
		text = prompt
	armed_changed.emit(kind, icon_tag)


func disarm() -> void:
	if armed.is_empty() and armed_icon.is_empty():
		return
	armed = ""
	armed_icon = ""
	armed_accepts = PackedStringArray()
	armed_changed.emit("", "")


## True when `message` is a refusal key (a reason the server gave), not the name of what started.
func is_reason(message: String) -> bool:
	return cues != null and cues.has_reason(message)


## A message for the log. A refusal also becomes a cue (CommandCue flashes `ncst`).
func say(message: String) -> void:
	text = message
	said.emit(message, cues.cue_for(message) if cues else &"")
