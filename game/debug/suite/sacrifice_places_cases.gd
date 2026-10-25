extends RefCounted

## 055g g1 case of rules_suite: the places of the sacrifice live in a scene (sacrifice_places.tscn) that is only read.
##   - facts_match_old_rules: the 13 distances SacrificeFacts reads are, bit for bit, the literals the old MatchRules fields held;
##   - barrier_variant: the inherited scene debug/sacrifice/barrier_places.tscn changes only the push (24 m);
##   - never_instanced: asking for the facts adds no node (no Area3D, same child count) to the tree;
##   - cached: the same scene gives the same SacrificeFacts, and the rules reach it through `sacrifice_places`;
##   - frame_warnings: the frame is quiet when complete and warns about a missing shape, a missing marker and a live Area3D.
## Prints SACRIFICE PLACES <case>=<bool>.

const BARRIER_SCENE := "res://debug/sacrifice/barrier_places.tscn"


func run(host: Node) -> Dictionary:
	var rules := MatchRules.new()
	var results := {
		"facts_match_old_rules": _facts_match_old_rules(rules),
		"barrier_variant": _barrier_variant(rules),
		"never_instanced": _never_instanced(host),
		"cached": _cached(rules),
		"frame_warnings": _frame_warnings(),
	}
	var ok := true
	for case_name: String in results:
		var passed: bool = results[case_name]
		ok = ok and passed
		print("SACRIFICE PLACES %s=%s" % [case_name, passed])
	return {"sacrifice_places": {"ok": ok, "cases": results}}


## (scene value, literal the old MatchRules fields held) per distance, in the order of the plan.
func _pairs(facts: SacrificeFacts) -> Dictionary[String, Array]:
	return {
		"ritual_radius": [facts.ring_m, 20.0],
		"ritual_walk_shrink": [facts.walk_shrink_m(), 3.0],
		"ritual_push_radius": [facts.push_m, 20.0],
		"ritual_push_inner": [facts.push_core_m, 5.0],
		"ritual_start_distance": [facts.carrier_stop_m, 20.0],
		"ritual_creature_height": [facts.hang_up_m, 15.0],
		"carry_height": [facts.carry_up_m, 3.5],
		"carry_distance": [facts.carry_back_m, 2.7],
		"desecrate_pickup_distance": [facts.pickup_m, 10.0],
		"convert_reach": [facts.pump_reach_m, 2.0],
		"doctor_drop_distance": [facts.drop_out_m, 20.0],
		"doctor_drop_height": [facts.drop_up_m, 15.0],
		"doctor_exit_depth": [facts.exit_down_m, 2.25],
	}


func _facts_match_old_rules(rules: MatchRules) -> bool:
	var pairs := _pairs(SacrificeFacts.of_rules(rules))
	var same := pairs.size() == 13
	for field: String in pairs:
		var pair: Array = pairs[field]
		var scene_value: float = pair[0]
		var rule_value: float = pair[1]
		if scene_value != rule_value:
			same = false
			print("SACRIFICE PLACES   %s differs: scene=%s rules=%s" % [field, scene_value, rule_value])
	return same


func _barrier_variant(rules: MatchRules) -> bool:
	var barrier := SacrificeFacts.of(load(BARRIER_SCENE) as PackedScene)
	var base := SacrificeFacts.of_rules(rules)
	var rest_same := true
	var barrier_pairs := _pairs(barrier)
	for field: String in barrier_pairs:
		if field == "ritual_push_radius":
			continue
		var pair: Array = barrier_pairs[field]
		var scene_value: float = pair[0]
		var rule_value: float = pair[1]
		rest_same = rest_same and scene_value == rule_value
	return barrier.push_m == 24.0 and base.push_m == 20.0 and rest_same


func _never_instanced(host: Node) -> bool:
	var root := host.get_tree().root
	var areas_before := root.find_children("*", "Area3D", true, false).size()
	var children_before := root.get_child_count()
	var fresh := ResourceLoader.load(BARRIER_SCENE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	SacrificeFacts.of(fresh)
	return root.find_children("*", "Area3D", true, false).size() == areas_before and root.get_child_count() == children_before


func _cached(rules: MatchRules) -> bool:
	var scene := load(BARRIER_SCENE) as PackedScene
	var rules_scene := SacrificeFacts.of_rules(rules)
	return SacrificeFacts.of(scene) == SacrificeFacts.of(scene) and rules_scene == SacrificeFacts.of(rules.sacrifice_places) \
		and SacrificeFacts.of(null) == rules_scene


func _frame_warnings() -> bool:
	var scene := load("res://scenes/sacrifice/sacrifice_places.tscn") as PackedScene
	var frame := scene.instantiate() as SacrificeFrame
	var quiet: bool = (frame.call("_get_configuration_warnings") as PackedStringArray).is_empty()
	frame.push = null
	frame.vortex = null
	var warnings: PackedStringArray = frame.call("_get_configuration_warnings")
	var warns_shape := _mentions(warnings, "`push`")
	var warns_marker := _mentions(warnings, "`vortex`")
	frame.push = frame.ring
	(frame.ring.get_parent() as Area3D).monitoring = true
	var warns_area := _mentions(frame.call("_get_configuration_warnings"), "Area3D")
	frame.free()
	return quiet and warns_shape and warns_marker and warns_area


func _mentions(warnings: PackedStringArray, text: String) -> bool:
	for line in warnings:
		if text in line:
			return true
	return false
