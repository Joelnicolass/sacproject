class_name RtsRefusal
extends RefCounted

## The keys of the refusals the kit's input says (RtsCommandState.say). A key is never the words on
## screen: RtsCueSet maps it to a cue and RtsRefusalReason to words (translated with `tr`). A game adds
## its own keys the same way.

## An order aimed at the sky, off the map.
const NO_GROUND := &"rts_no_ground"
## An order with nothing selected.
const NOBODY := &"rts_nobody"
## A retreat with no anchor to go to.
const NO_ANCHOR := &"rts_no_anchor"
## A command that only aims at bodies was clicked where there is none.
const NO_TARGET := &"rts_no_target"
## The order was not taken by any unit (none accepts it).
const NOT_TAKEN := &"rts_not_taken"
