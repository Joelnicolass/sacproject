extends Node

## Read-only observer for the F140 check (RFC-031 031a2, MatchSetup). Never changes a rule. Tolerates scene == null.
##   rules()   one line: the product .tres as cached in memory (wizard_level, friendly_fire) and, when there is a world,
##             its rules (same object as the .tres or a copy), plus MatchState.friendly_fire.

const PRODUCT := "res://data/match_rules.tres"


func rules() -> String:
	var product := load(PRODUCT) as MatchRules
	var line := "pt140 tres level=%d ff=%s" % [product.wizard_level, product.friendly_fire]
	var world := get_tree().current_scene if get_tree() else null
	var world_rules: Variant = world.get("rules") if world != null and "rules" in world else null
	if world_rules is MatchRules:
		var r := world_rules as MatchRules
		line += " world level=%d ff=%s same=%s" % [r.wizard_level, r.friendly_fire, r == product]
	var state := get_tree().get_first_node_in_group(&"match_state") if get_tree() else null
	if state != null:
		line += " state ff=%s" % state.get("friendly_fire")
	print(line)
	return line
