class_name MatchSetup
extends RefCounted

## RFC-031 031a2 (F140): what the one who creates the match chose over the rules (boot, or the flags of this process).
## SacrificeFlow keeps one; HighNoon applies it on the authority before the seed (apply_to). Never touches the `.tres`.
## Precedence: boot > flag > rules (the boot overwrites the fields read from_cli()).

## Wizard level of both wizards, 1-9. 0 = the rules' wizard_level.
var level := 0
## 1 on, 0 off, -1 = the rules' friendly_fire.
var friendly_fire := -1
## RFC-031 031d (F143): 1 on, 0 off, -1 = the rules' enable_drop_soul (P drops a soul).
var drop_soul := -1
## RFC-031 031d (F143): blue souls of every wizard at the start; -1 = the rules' starting_souls.
var starting_souls := -1
## RFC-034 034e: the seed of the match; 0 = the rules' `match_seed` (the one who simulates draws it). The room server draws it
## and puts it in the ticket (`--match-ticket-file`); `--match-seed=N` sets it by hand. The benches pass none.
var match_seed := 0
## RFC-049 049a (F290): the map of the match (a tag of the MapCatalog); empty = the one of `--map` or the default. It is not a rule of
## the round: `apply_to` and `is_empty` ignore it. SacrificeFlow._apply_match_choice is the only one that turns it into `MapCatalog.use`.
var map_tag: StringName = &""
## RFC-049 049b (F291): the game mode of the match (a tag of the GameModeCatalog); empty = the one of `--mode` or 1v1. Like `map_tag` it is not a
## rule of the round; SacrificeFlow._apply_match_choice is the only one that turns it into `GameModeCatalog.use`.
var mode_tag: StringName = &""


func copy() -> MatchSetup:
	var other := MatchSetup.new()
	other.level = level
	other.friendly_fire = friendly_fire
	other.drop_soul = drop_soul
	other.starting_souls = starting_souls
	other.match_seed = match_seed
	other.map_tag = map_tag
	other.mode_tag = mode_tag
	return other


func is_empty() -> bool:
	return level == 0 and friendly_fire < 0 and drop_soul < 0 and starting_souls < 0 and match_seed == 0


## A copy of this setup where every field `over` sets wins (boot > flag: the boot's setup over the flags' one).
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
	if over.map_tag != &"":
		merged.map_tag = over.map_tag
	if over.mode_tag != &"":
		merged.mode_tag = over.mode_tag
	return merged


## A copy of `rules` with the overrides of this setup. Without overrides (a bench, a run with no flags) it returns
## `rules` itself, so nothing that reads the world's rules changes. `rules` that are not MatchRules pass through.
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
	return copy


## --level=N (1-9, like sacengine app.d:276), --souls=N (app.d:278; the one owner of this flag, the bench ai_match
## included: it reaches the bench through HighNoon like any other match), and the option flags --friendly-fire /
## --no-friendly-fire and --drop-soul / --no-drop-soul (app.d:333-355: the flag is the name of the option field).
## Prints what it took. With both forms of a flag the --no- one wins (sacengine keeps the last one in argv; passing
## both is a usage error).
static func from_cli() -> MatchSetup:
	var setup := MatchSetup.new()
	var raw := MpBoot.user_value("level", "")
	if not raw.is_empty():
		var wanted := int(raw)
		if wanted >= 1 and wanted <= 9:
			setup.level = wanted
			print("nivel del mago %d (--level)" % wanted)
		else:
			push_warning("--level=%s: fuera de 1-9, se usa el de las reglas" % raw)
	if MpBoot.user_flag("no-friendly-fire"):
		setup.friendly_fire = 0
	elif MpBoot.user_flag("friendly-fire"):
		setup.friendly_fire = 1
	if MpBoot.user_flag("no-drop-soul"):
		setup.drop_soul = 0
	elif MpBoot.user_flag("drop-soul"):
		setup.drop_soul = 1
	var souls := MpBoot.user_value("souls", "")
	if not souls.is_empty():
		if souls.is_valid_int() and int(souls) >= 0:
			setup.starting_souls = int(souls)
			print("almas iniciales %d (--souls)" % setup.starting_souls)
		else:
			push_warning("--souls=%s: no es un número ≥ 0, se usan las de las reglas" % souls)
	var wanted_seed := MpBoot.user_value("match-seed", "")
	if not wanted_seed.is_empty():
		if wanted_seed.is_valid_int() and int(wanted_seed) > 0:
			setup.match_seed = int(wanted_seed)
			print("semilla de la partida %d (--match-seed)" % setup.match_seed)
		else:
			push_warning("--match-seed=%s: no es un número > 0, se usa el de las reglas" % wanted_seed)
	return setup
