@tool
class_name SoundSet
extends Resource

## What a creature or a wizard sounds like: one cue per thing that happens to it (voice when you
## pick it, swing, hurt, death...). A type template (a creature's <name>_sounds.tres, or a .tres in
## wizards/<name>/, never written at runtime) assigned to the `sounds` of a look
## (`creatures/<name>/<name>_look.tscn` or `scenes/wizards/bodies/<name>_look.tscn`). An empty field
## is silence for that event unless the `fallback` set has it (the melee set many creatures share).
## It does not play anything: UnitSounds, WizardSounds and CommandVoice ask it which cue answers an
## event.

const MAX_HOPS := 8

@export_group("Voice")
## You select it.
@export var selected: SoundCue
## You order it to move or to guard.
@export var ack: SoundCue
## You order it to attack or to advance.
@export var attack_ack: SoundCue
## You select the same one again and again.
@export var annoyed: SoundCue
@export_group("Body")
## A melee hit lands.
@export var swing: SoundCue
## It shoots.
@export var shoot: SoundCue
## It takes damage and survives.
@export var damaged: SoundCue
@export var death: SoundCue
## It is summoned. Empty: the cue of UnitSounds.summon, the same for every creature.
@export var summon: SoundCue
@export_group("Wizard")
## A spell starts to cast.
@export var incantation: SoundCue
## The wizard rises as a ghost.
@export var ghost: SoundCue
@export_group("")
## Asked when this set has no cue for an event (the melee set of a creature that has no sound of its
## own for a swing).
@export var fallback: SoundSet


## The cue of `event` here or in the fallback chain; null when nobody has one.
func cue(event: StringName) -> SoundCue:
	var current := self
	var hops := 0
	while current != null and hops < MAX_HOPS:
		var found := current.own_cue(event)
		if found != null:
			return found
		current = current.fallback
		hops += 1
	return null


## The cue of `event` in this set only (no fallback); null when the field is empty.
func own_cue(event: StringName) -> SoundCue:
	match event:
		SoundEvent.SELECTED:
			return selected
		SoundEvent.ACK:
			return ack
		SoundEvent.ATTACK_ACK:
			return attack_ack
		SoundEvent.ANNOYED:
			return annoyed
		SoundEvent.SWING:
			return swing
		SoundEvent.SHOOT:
			return shoot
		SoundEvent.DAMAGED:
			return damaged
		SoundEvent.DEATH:
			return death
		SoundEvent.SUMMON:
			return summon
		SoundEvent.INCANTATION:
			return incantation
		SoundEvent.GHOST:
			return ghost
	# max-returns: one return per sound event in the match.
	# gdlint: ignore=max-returns
	return null
