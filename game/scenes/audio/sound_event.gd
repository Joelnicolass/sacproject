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
## A wizard rises as a ghost (GhostForm RISING).
const GHOST := &"ghost"
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
	SELECTED, ACK, SWING, SHOOT, DAMAGED, DEATH, SUMMON, INCANTATION, GHOST, FOOT,
	CAST, FX, LOOP, ADVICE, CLICK, SACRIFICE_ROUND, SACRIFICE_END, SOUL,
]

## The original's SSET type codes that have an event (data/audio/README.md has the table). tools/bake/bake_sound_sets.gd
## writes these as the keys of the baked sets; a code that is not here keeps its code as the key (`Xhit`, `Xcat`, `TNT1`...).
## Creature, wizard and melee sets.
const CREATURE_CODES := {
	"Xcnt": SELECTED,   # clicked / selected
	"Xcnf": ACK,        # order acknowledged (move)
	"Xatt": SWING,      # melee swing
	"Xdam": DAMAGED,
	"Xdie": DEATH,
	"Xinc": INCANTATION,
}
## The `spel` set (world.tres).
const WORLD_CODES := {
	"Xsac": SACRIFICE_ROUND,
	"Xgib": SACRIFICE_END,
	"spir": SOUL,
	"SUMN": SUMMON,
}
## The `ifac` set (ui.tres).
const UI_CODES := {
	"clik": CLICK,
}
