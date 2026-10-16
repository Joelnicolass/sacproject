class_name MatchSetup
extends RefCounted

## RFC-031 031a2 (F140): what the one who creates the match chose over the rules (boot, or the flags of this process).
## SacrificeFlow keeps one; HighNoon applies it on the authority before the seed (apply_to). Never touches the `.tres`.
## Precedence: boot > flag > rules (the boot overwrites the fields read from_cli()).

## Wizard level of both wizards, 1-9. 0 = the rules' wizard_level.
var level := 0
## 1 on, 0 off, -1 = the rules' friendly_fire.
var friendly_fire := -1


func copy() -> MatchSetup:
	var other := MatchSetup.new()
	other.level = level
	other.friendly_fire = friendly_fire
	return other


func is_empty() -> bool:
	return level == 0 and friendly_fire < 0


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
	return copy


## --level=N (1-9, like sacengine app.d:276) and --friendly-fire / --no-friendly-fire (app.d:333-355: the flag is the
## name of the option field). Prints what it took. With both flags --no-friendly-fire wins (sacengine keeps the last one
## in argv; passing both is a usage error).
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
	return setup
