class_name MatchSetup
extends RefCounted

## What the one who creates the match chose over the rules (the menu, the flags of this process or a
## room's ticket). SacrificeFlow keeps one; the world applies it on the authority before the seed
## (`apply_to`). It never touches the `.tres`.
## Precedence: menu > flag > rules (`overlaid_by`). It holds Resources, never tags: MatchWire turns
## the text of the network into them.

## Wizard level of both wizards, 1-9. 0 = the rules' wizard_level.
var level := 0
## 1 on, 0 off, -1 = the rules' friendly_fire.
var friendly_fire := -1
## 1 on, 0 off, -1 = the rules' enable_drop_soul (P drops a soul).
var drop_soul := -1
## Blue souls of every wizard at the start; -1 = the rules' starting_souls.
var starting_souls := -1
## The seed of the match; 0 = the rules' `match_seed` (the one who simulates draws it). The room
## server draws it and puts it in the ticket (`--match-ticket-file`); `--match-seed=N` sets it by
## hand. Tests may pass none.
var match_seed := 0
## The map of the match; null = the one of `--map` or the default. It is not a rule of the round:
## `apply_to` and `is_empty` ignore it, and SacrificeFlow hands it to ActiveMatch.
var map: MapDefinition
## The game mode of the match; null = the one of `--mode` or 1v1. Like `map`, it is not a rule of
## the round.
var mode: GameMode
## The land of the match (the god whose look the map wears); null = drawn from the seed. Unlike
## `map` it IS a rule of the round for `apply_to`: the copy of the rules carries it (`biome`) and
## MatchBiome on the authority sends the result to the clients.
var biome: GodType


func copy() -> MatchSetup:
	var other := MatchSetup.new()
	other.level = level
	other.friendly_fire = friendly_fire
	other.drop_soul = drop_soul
	other.starting_souls = starting_souls
	other.match_seed = match_seed
	other.map = map
	other.mode = mode
	other.biome = biome
	return other


func is_empty() -> bool:
	return (
		level == 0
		and friendly_fire < 0
		and drop_soul < 0
		and starting_souls < 0
		and match_seed == 0
		and biome == null
	)


## A copy of this setup where every field `over` sets wins (boot > flag: the boot's setup over the
## flags' one).
func overlaid_by(over: MatchSetup) -> MatchSetup:
	var merged := copy()
	if over == null:
		return merged
	if over.level > 0:
		merged.level = over.level
	if over.friendly_fire >= 0:
		merged.friendly_fire = over.friendly_fire
	if over.drop_soul >= 0:
		merged.drop_soul = over.drop_soul
	if over.starting_souls >= 0:
		merged.starting_souls = over.starting_souls
	if over.match_seed > 0:
		merged.match_seed = over.match_seed
	if over.map != null:
		merged.map = over.map
	if over.mode != null:
		merged.mode = over.mode
	if over.biome != null:
		merged.biome = over.biome
	return merged


## A copy of `rules` with the overrides of this setup. Without overrides (a test, a run with no
## flags) it returns `rules` itself, so nothing that reads the world's rules changes. `rules` that
## are not MatchRules pass through.
func apply_to(rules: Variant) -> Variant:
	if not rules is MatchRules or is_empty():
		return rules
	var copy := (rules as MatchRules).duplicate() as MatchRules
	if level > 0:
		copy.wizard_level = level
	if friendly_fire >= 0:
		copy.friendly_fire = friendly_fire == 1
	if drop_soul >= 0:
		copy.enable_drop_soul = drop_soul == 1
	if starting_souls >= 0:
		copy.starting_souls = starting_souls
	if match_seed > 0:
		copy.match_seed = match_seed
	if biome != null:
		copy.biome = biome
	return copy
