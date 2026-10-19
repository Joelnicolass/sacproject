class_name Refusal
extends RefCounted

## Why a command did not start (RFC-045a). A key, never the words a player reads: the server answers with
## it, `CueSet.refusals` maps it to a cue and the text on screen is `Refusal.text(key)` (translated, RFC-045b).
## Nobody compares display text; compare these keys.

const NO_MANA := &"no_mana"
const COOLING := &"cooling"
const OUT_OF_RANGE := &"out_of_range"
const BAD_TARGET := &"bad_target"
const NOT_IMPLEMENTED := &"not_implemented"
## The spot is taken (a Manalith asked on top of something, or a creature with no room to appear).
const OCCUPIED := &"occupied"
const CASTING := &"casting"
const NO_SOULS := &"no_souls"
const NO_FOUNT := &"no_fount"
const FAR_FROM_BUILDING := &"far_from_building"
const NO_ALTAR := &"no_altar"
const FAR_FROM_ALTAR := &"far_from_altar"
const NO_TARGET := &"no_target"
const NO_GROUND := &"no_ground"
const NO_ABILITY := &"no_ability"
const NOBODY := &"nobody"
const NO_WIZARD := &"no_wizard"
const CREATURE_LIMIT := &"creature_limit"
