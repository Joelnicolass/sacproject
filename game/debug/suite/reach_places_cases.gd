extends RefCounted

## 055r r2 case of rules_suite: the reaches of the match live in a scene (reach_places.tscn) that is only read.
##   - facts_match_old_rules: the 9 reaches (and the leash origin) ReachFacts reads are, bit for bit, the doubles the old MatchRules held;
##   - far_variant: the inherited scene debug/match/far_reach_places.tscn changes only the fount (80 m);
##   - never_instanced: asking for the facts adds no node (no Area3D, same child count) to the tree;
##   - cached: the same scene gives the same ReachFacts, and the rules reach it through `reach_places`;
##   - frame_warnings: the frame is quiet when complete and warns about a missing shape, a missing marker and a live Area3D.
## Every case returns {ok, ...}; a failing one prints the values. Prints REACH PLACES <case>=<bool>.

const FAR_SCENE := "res://debug/match/far_reach_places.tscn"
const PLACES_SCENE := "res://scenes/match/reach_places.tscn"


func run(host: Node) -> Dictionary:
	var rules := MatchRules.new()
	var results: Dictionary[String, Dictionary] = {
		"facts_match_old_rules": _facts_match_old_rules(rules),
		"far_variant": _far_variant(rules),
		"never_instanced": _never_instanced(host),
		"cached": _cached(rules),
		"frame_warnings": _frame_warnings(),
	}
	var ok := true
	for case_name: String in results:
		var passed: bool = results[case_name].get("ok", false)
		ok = ok and passed
		print("REACH PLACES %s=%s" % [case_name, passed])
	return {"reach_places": {"ok": ok, "cases": results}}


## (scene value, the literal the old MatchRules field held) per reach, in the order of the plan.
func _pairs(facts: ReachFacts) -> Dictionary[String, Array]:
	return {
		"soul_reach": [facts.soul_m, 5.0],
		"soul_collect_height": [facts.soul_up_m, 5.0],
		"fount_reach": [facts.fount_m, 50.0],
		"altar_reach": [facts.altar_m, 50.0],
		"manahoar_aura": [facts.manahoar_aura_m, 40.0],
		"manahoar_peak": [facts.manahoar_peak_m, 50.0],
		"manahoar_end": [facts.manahoar_end_m, 1000.0],
		"guardian_arm": [facts.guardian_arm_m, 50.0],
		"guardian_leash": [facts.guardian_leash_m, 50.0],
		"guardian_return": [facts.guardian_return_m, 20.0],
	}


## The literals of the old rules fields the facts must equal; the plan's 9 plus the half height of the soul cylinder.
func _facts_match_old_rules(rules: MatchRules) -> Dictionary:
	var facts := ReachFacts.of_rules(rules)
	var pairs := _pairs(facts)
	var same := pairs.size() == 10
	var differs: PackedStringArray = []
	for field: String in pairs:
		var pair: Array = pairs[field]
		var scene_value: float = pair[0]
		var rule_value: float = pair[1]
		if scene_value != rule_value:
			same = false
			differs.append("%s scene=%s rules=%s" % [field, scene_value, rule_value])
	var origin_same: bool = facts.guardian_leash_from == Vector3(0.0, 0.9, 0.0)
	if not origin_same:
		print("REACH PLACES   leash_from differs: scene=%s rules=(0, 0.9, 0)" % [facts.guardian_leash_from])
	for line in differs:
		print("REACH PLACES   %s" % line)
	return {"ok": same and origin_same, "differs": differs}


func _far_variant(rules: MatchRules) -> Dictionary:
	var far := ReachFacts.of(load(FAR_SCENE) as PackedScene)
	var base := ReachFacts.of_rules(rules)
	var rest_same := true
	var far_pairs := _pairs(far)
	for field: String in far_pairs:
		if field == "fount_reach":
			continue
		var pair: Array = far_pairs[field]
		var scene_value: float = pair[0]
		var rule_value: float = pair[1]
		rest_same = rest_same and scene_value == rule_value
	var passed: bool = far.fount_m == 80.0 and base.fount_m == 50.0 and rest_same
	if not passed:
		print("REACH PLACES   far fount=%s base fount=%s rest_same=%s" % [far.fount_m, base.fount_m, rest_same])
	return {"ok": passed, "far_fount": far.fount_m, "base_fount": base.fount_m, "rest_same": rest_same}


func _never_instanced(host: Node) -> Dictionary:
	var root := host.get_tree().root
	var areas_before := root.find_children("*", "Area3D", true, false).size()
	var children_before := root.get_child_count()
	var fresh := ResourceLoader.load(FAR_SCENE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	ReachFacts.of(fresh)
	var areas_after := root.find_children("*", "Area3D", true, false).size()
	var children_after := root.get_child_count()
	var passed: bool = areas_after == areas_before and children_after == children_before
	if not passed:
		print("REACH PLACES   areas %s -> %s, root children %s -> %s" % [areas_before, areas_after, children_before, children_after])
	return {"ok": passed, "areas_before": areas_before, "areas_after": areas_after}


func _cached(rules: MatchRules) -> Dictionary:
	var scene := load(FAR_SCENE) as PackedScene
	var rules_facts := ReachFacts.of_rules(rules)
	var same_scene: bool = ReachFacts.of(scene) == ReachFacts.of(scene)
	var via_rules: bool = rules_facts == ReachFacts.of(rules.reach_places)
	var via_null: bool = ReachFacts.of(null) == rules_facts
	var passed := same_scene and via_rules and via_null
	if not passed:
		print("REACH PLACES   cache: same_scene=%s via_rules=%s via_null=%s" % [same_scene, via_rules, via_null])
	return {"ok": passed, "same_scene": same_scene, "via_rules": via_rules, "via_null": via_null}


func _frame_warnings() -> Dictionary:
	var scene := load(PLACES_SCENE) as PackedScene
	var frame := scene.instantiate() as ReachFrame
	var first: PackedStringArray = frame._get_configuration_warnings()
	var quiet := first.is_empty()
	frame.guardian_leash = null
	frame.guardian_leash_from = null
	var second: PackedStringArray = frame._get_configuration_warnings()
	var warns_shape := _mentions(second, "`guardian_leash`")
	var warns_marker := _mentions(second, "`guardian_leash_from`")
	frame.guardian_leash = frame.fount
	(frame.fount.get_parent() as Area3D).monitoring = true
	var third: PackedStringArray = frame._get_configuration_warnings()
	var warns_area := _mentions(third, "Area3D")
	frame.free()
	var passed := quiet and warns_shape and warns_marker and warns_area
	if not passed:
		print("REACH PLACES   warnings: quiet=%s (%s) shape=%s marker=%s area=%s" % [quiet, first, warns_shape, warns_marker, warns_area])
	return {"ok": passed, "quiet": quiet, "warns_shape": warns_shape, "warns_marker": warns_marker, "warns_area": warns_area}


func _mentions(warnings: PackedStringArray, text: String) -> bool:
	for line in warnings:
		if text in line:
			return true
	return false
