extends RefCounted

## 055c2 cases of rules_suite: the arithmetic of Vision (VisionRules) by hand, the order by name, and the live bed
## `debug/units/vision_range.tscn` (range, `seen`/`lost` order, hand-set radius, cone, cylinder against sphere, the physics area against
## walking the groups, the side's memory and its forgetting). Prints nothing by itself: rules_suite prints the verdict.

const RANGE_SCENE := preload("res://debug/units/vision_range.tscn")
const RangeBed := preload("res://debug/units/vision_range.gd")
const AHEAD := Vector3(0.0, 0.0, 1.0)


func run(host: Node3D) -> Dictionary:
	var out := {}
	out["vision_rules"] = _rules(host)
	out["vision_range"] = await _range(host)
	return out


## The shape, the cone, the memory and the order, with numbers worked out by hand.
func _rules(host: Node3D) -> Dictionary:
	var high := Vector3(60.0, 500.0, 80.0)
	var checks := {
		"cylinder_flat_edge": VisionRules.covers(false, Vector3.ZERO, high, 100.0, AHEAD, 360.0),
		"cylinder_just_out": not VisionRules.covers(false, Vector3.ZERO, Vector3(60.0, 0.0, 80.1), 100.0, AHEAD, 360.0),
		"sphere_counts_height": not VisionRules.covers(true, Vector3.ZERO, high, 100.0, AHEAD, 360.0),
		"cone_ahead": VisionRules.in_cone(AHEAD, Vector3(10.0, 0.0, 20.0), 90.0),
		"cone_behind": not VisionRules.in_cone(AHEAD, Vector3(0.0, 0.0, -10.0), 90.0),
		"cone_side_out": not VisionRules.in_cone(AHEAD, Vector3(20.0, 0.0, 10.0), 90.0),
		"cone_on_top": VisionRules.in_cone(AHEAD, Vector3.ZERO, 10.0),
		"mark_holds": not VisionRules.lapsed(10, 14, 5),
		"mark_lapses": VisionRules.lapsed(10, 15, 5),
		"mark_for_good": not VisionRules.lapsed(Vision.FOREVER, 1000000, 5),
		"forget_default_384": MatchClock.ticks_for(6.4) == 384,
	}
	var left := Node3D.new()
	left.name = "VisionLeft"
	var right := Node3D.new()
	right.name = "VisionRight"
	var first := Node3D.new()
	first.name = "Same"
	var second := Node3D.new()
	second.name = "Same"
	left.add_child(first)
	right.add_child(second)
	host.add_child(left)
	host.add_child(right)
	checks["same_name_breaks_by_path"] = VisionRules.by_name(first, second) and not VisionRules.by_name(second, first)
	var named := [second, first]
	named.sort_custom(VisionRules.by_name)
	checks["sort_is_stable_whatever_the_input"] = named == [first, second]
	left.free()
	right.free()
	return _verdict(checks)


func _range(host: Node3D) -> Dictionary:
	var bed := RANGE_SCENE.instantiate() as RangeBed
	host.add_child(bed)
	var report := await bed.run_checks()
	bed.free()
	return report


static func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {"ok": ok, "checks": checks}
