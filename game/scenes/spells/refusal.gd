class_name Refusal
extends RefCounted

## Why a command did not start. A key, never the words a player reads: the server answers with
## it, `CueSet.refusals` maps it to a cue and the text on screen is `Refusal.text(key)` (translated, RFC-045b).
## Nobody compares display text; compare these keys.
## Ref: RFC-045a

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
## Every fount near the click already has a tower (own or someone else's): founts belong to nobody until a tower takes one.
const FOUNT_TAKEN := &"fount_taken"
const FAR_FROM_BUILDING := &"far_from_building"
const NO_ALTAR := &"no_altar"
const FAR_FROM_ALTAR := &"far_from_altar"
const NO_TARGET := &"no_target"
const NO_GROUND := &"no_ground"
const NO_ABILITY := &"no_ability"
const NOBODY := &"nobody"
const NO_WIZARD := &"no_wizard"
const CREATURE_LIMIT := &"creature_limit"


## The words a player reads for `key`: the `REFUSAL_<KEY>` row of data/i18n/strings.csv, translated. "" when the csv has no row.
static func text(key: StringName) -> String:
	var msg := "REFUSAL_" + String(key).to_upper()
	var words := TranslationServer.translate(msg)
	return "" if words == msg else String(words)
