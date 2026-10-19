class_name SoundEvent
extends RefCounted

## RFC-052 052a (F360): the vocabulary of sound events, the keys of SoundSet.cues. A Sounds/Voice node turns a
## replicated state or a local signal into one of these; the set of the emitter says which cue (if any) answers it.
## A set may hold keys that are not here (a custom creature's own event); these are the ones the game emits.

# Units and wizards (052c).
const SELECTED := &"selected"
const ACK := &"ack"
## The order acknowledged is an attack or an advance (052e: CommandVoice; the original's `Xcat`).
const ATTACK_ACK := &"attack_ack"
## Selected again and again (052e: CommandVoice; the original's `Xann`).
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
# Spells and FX (052d).
const CAST := &"cast"
const FX := &"fx"
const LOOP := &"loop"
# Advisor and UI (052e, 052h).
const ADVICE := &"advice"
const CLICK := &"click"
## A menu opened / closed on nothing (052h: MenuSounds on the radial X menu).
const MENU_OPEN := &"menu_open"
const MENU_BACK := &"menu_back"
# Sacrifice (052h).
const SACRIFICE_ROUND := &"sacrifice_round"
const SACRIFICE_END := &"sacrifice_end"
const SOUL := &"soul"
# Ambience (052g): the god's bed loop and a one-shot around the listener (emitter `ambience`). The music logs its mood
# (MusicMood: calm, battle...) as the event, emitter `music` (052f).
const BED := &"bed"
const AMBIENT := &"ambient"

const ALL: Array[StringName] = [
	SELECTED, ACK, ATTACK_ACK, ANNOYED, SWING, SHOOT, DAMAGED, DEATH, SUMMON, INCANTATION, GHOST, FOOT,
	CAST, FX, LOOP, ADVICE, CLICK, MENU_OPEN, MENU_BACK, SACRIFICE_ROUND, SACRIFICE_END, SOUL, BED, AMBIENT,
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
