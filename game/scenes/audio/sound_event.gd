class_name SoundEvent
extends RefCounted

## RFC-052 052a (F360): the vocabulary of sound events, the keys of SoundSet.cues. A Sounds/Voice node turns a
## replicated state or a local signal into one of these; the set of the emitter says which cue (if any) answers it.
## A set may hold keys that are not here (a custom creature's own event); these are the ones the game emits.

# Units and wizards (052c).
const SELECTED := &"selected"
const ACK := &"ack"
const SWING := &"swing"
const SHOOT := &"shoot"
const DAMAGED := &"damaged"
const DEATH := &"death"
const SUMMON := &"summon"
const INCANTATION := &"incantation"
const FOOT := &"foot"
# Spells and FX (052d).
const CAST := &"cast"
const FX := &"fx"
const LOOP := &"loop"
# Advisor and UI (052e, 052h).
const ADVICE := &"advice"
const CLICK := &"click"
# Sacrifice (052h).
const SACRIFICE_ROUND := &"sacrifice_round"
const SACRIFICE_END := &"sacrifice_end"
const SOUL := &"soul"

const ALL: Array[StringName] = [
	SELECTED, ACK, SWING, SHOOT, DAMAGED, DEATH, SUMMON, INCANTATION, FOOT,
	CAST, FX, LOOP, ADVICE, CLICK, SACRIFICE_ROUND, SACRIFICE_END, SOUL,
]
