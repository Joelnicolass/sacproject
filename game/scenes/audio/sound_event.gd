class_name SoundEvent
extends RefCounted

## The vocabulary of sound events: what a Sounds/Voice node says happened (a replicated state or a local signal turned into
## a name). The ones in `BODY` are the fields of SoundSet; the rest name other emitters in the SoundLog.

# Units and wizards.
const SELECTED := &"selected"
const ACK := &"ack"
## The order acknowledged is an attack or an advance (CommandVoice).
const ATTACK_ACK := &"attack_ack"
## Selected again and again (CommandVoice).
const ANNOYED := &"annoyed"
const SWING := &"swing"
const SHOOT := &"shoot"
const DAMAGED := &"damaged"
const DEATH := &"death"
const SUMMON := &"summon"
const INCANTATION := &"incantation"
## A wizard rises as a ghost (GhostForm RISING).
const GHOST := &"ghost"
const FOOT := &"foot"
# Spells and FX.
const CAST := &"cast"
const FX := &"fx"
const LOOP := &"loop"
# Advisor and UI.
const ADVICE := &"advice"
const CLICK := &"click"
## A menu opened / closed on nothing (MenuSounds on the radial X menu).
const MENU_OPEN := &"menu_open"
const MENU_BACK := &"menu_back"
# Sacrifice.
const SACRIFICE_ROUND := &"sacrifice_round"
const SACRIFICE_END := &"sacrifice_end"
const SOUL := &"soul"
# Ambience: the god's bed loop and a one-shot around the listener (emitter `ambience`). The music logs its mood
# (MusicMood: calm, battle...) as the event, emitter `music`.
const BED := &"bed"
const AMBIENT := &"ambient"

## The events a creature or a wizard can sound: the fields of SoundSet, in the order the inspector shows them.
const BODY: Array[StringName] = [
	SELECTED,
	ACK,
	ATTACK_ACK,
	ANNOYED,
	SWING,
	SHOOT,
	DAMAGED,
	DEATH,
	SUMMON,
	INCANTATION,
	GHOST,
]

const ALL: Array[StringName] = [
	SELECTED,
	ACK,
	ATTACK_ACK,
	ANNOYED,
	SWING,
	SHOOT,
	DAMAGED,
	DEATH,
	SUMMON,
	INCANTATION,
	GHOST,
	FOOT,
	CAST,
	FX,
	LOOP,
	ADVICE,
	CLICK,
	MENU_OPEN,
	MENU_BACK,
	SACRIFICE_ROUND,
	SACRIFICE_END,
	SOUL,
	BED,
	AMBIENT,
]
