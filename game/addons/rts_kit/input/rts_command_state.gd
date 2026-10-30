class_name RtsCommandState
extends Node

## What the local command input is doing, as state and not as words: nothing here is drawn. `armed`
## says what waits for its target (&"" = nothing; &"attack", &"guard", &"move" for order icons; any
## other word a game arms, a spell, a building) and `armed_icon` its picture. The cursor, the cue and
## the HUD draw from the signals.

## Something was armed (`kind` &"" = disarmed).
signal armed_changed(kind: StringName, icon: Texture2D)
## A message for the player: a refusal key (RtsRefusal, a game's) or a name (an order given). `cue` is
## the cue the RtsCueSet gives it (&"refused" for a refusal, &"" for none).
signal said(text: String, cue: StringName)
## The live answer for the armed thing at the pointer changed: `status` &"" = it would start, else a
## refusal key; `site` = where it would land (or null). Only an RtsArmedPreview writes it.
signal aim_changed(status: StringName, site: Node)

## Words -> cue. Without it every message is only text.
@export var cues: RtsCueSet

var armed: StringName = &""
var armed_icon: Texture2D
## Target classes (RtsTargetProbe) the armed thing can land on; empty = any.
var armed_accepts := PackedStringArray()
## What a click at the pointer would answer now (RtsArmedPreview): &"" = it would start.
var aim_status: StringName = &""
## Where that click would land, or null.
var aim_site: Node


func is_armed() -> bool:
	return armed != &""


## Something waits for its target.
func arm(kind: StringName, icon: Texture2D, accepts := PackedStringArray()) -> void:
	armed = kind
	armed_icon = icon
	armed_accepts = accepts
	armed_changed.emit(kind, icon)


func disarm() -> void:
	if armed == &"" and armed_icon == null:
		return
	armed = &""
	armed_icon = null
	armed_accepts = PackedStringArray()
	show_aim(&"", null)
	armed_changed.emit(&"", null)


## The preview's answer for the armed thing at the pointer. Nothing happens when it did not change.
func show_aim(status: StringName, site: Node) -> void:
	if status == aim_status and site == aim_site:
		return
	aim_status = status
	aim_site = site
	aim_changed.emit(status, site)


## True when `message` is a refusal key, not the name of what started.
func is_reason(message: String) -> bool:
	return cues != null and cues.has_reason(message)


## A message for the player. A refusal also becomes a cue (the command cue flashes).
func say(message: String) -> void:
	said.emit(message, cues.cue_for(message) if cues else &"")
