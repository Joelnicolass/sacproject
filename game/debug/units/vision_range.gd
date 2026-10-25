extends Node

## 055c2 test bed of Vision: a Trogg of slot 1 (the Seer, sees 100 m, faces +Z) and five Druids of slot 2 standing still around it: three
## inside the range (50, 72 and 85 m, named so that the tree order is not the name order), one just outside (110 m) and one behind it (60 m).
## Drag any of them in the viewport and run again (F6). Headless it runs the checks, prints `VISION_RANGE PASS/FAIL {json}` and quits.
## Checks: who is in sight and in which order, the `seen`/`lost` order, a hand-set radius, the cone, cylinder against sphere, the physics
## area giving the same answer as walking the groups, the side's memory and its forgetting.
## The rules suite (debug/suite/vision_cases.gd) instances this scene and calls run_checks().

const TAG := "VISION_RANGE "
const GROUP := &"vision_range"

@export var seer: UnitBody
## In tree order (not in name order on purpose).
@export var foes: Array[UnitBody] = []
@export var far_foe: UnitBody
@export var behind_foe: UnitBody
@export var area_frames := 4


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	var report := await run_checks()
	print(TAG + ("PASS " if bool(report["ok"]) else "FAIL ") + JSON.stringify(report))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(report["ok"]) else 1)


## Runs every check and returns {ok, checks, ...}. The bodies stand still and only look when the checks say so.
func run_checks() -> Dictionary:
	var everyone: Array[UnitBody] = [seer, far_foe, behind_foe]
	everyone.append_array(foes)
	for body in everyone:
		body.set_physics_process(false)
		body.add_to_group(GROUP)
		body.vision.seen_groups = PackedStringArray([GROUP])
		body.vision.watching = false
	var eyes := seer.vision
	var checks := {}
	var home := {}
	for body in everyone:
		home[body] = body.global_position
	var seen_order: Array[String] = []
	var lost_order: Array[String] = []
	eyes.seen.connect(func(node: Node3D) -> void: seen_order.append(String(node.name)))
	eyes.lost.connect(func(node: Node3D) -> void: lost_order.append(String(node.name)))

	eyes.refresh()
	var sorted_all := _names(foes) + [String(behind_foe.name)]
	sorted_all.sort()
	var in_range := _names(eyes.in_sight())
	checks["range_100"] = in_range == sorted_all and not eyes.sees(far_foe)
	checks["tree_order_is_not_name_order"] = _names(foes) != _sorted(_names(foes))
	checks["in_sight_by_name"] = in_range == _sorted(in_range)
	checks["seen_in_name_order"] = seen_order == _sorted(seen_order) and seen_order.size() == sorted_all.size()
	eyes.refresh()
	checks["stable_second_look"] = _names(eyes.in_sight()) == in_range and seen_order.size() == sorted_all.size()

	eyes.radius_m = 120.0
	eyes.refresh()
	checks["radius_by_hand"] = eyes.sees(far_foe) and is_equal_approx(eyes.range_m(), 120.0)
	eyes.radius_m = 0.0
	eyes.refresh()
	checks["radius_back_to_type"] = not eyes.sees(far_foe) and is_equal_approx(eyes.range_m(), seer.type.vision_m)

	eyes.fov_deg = 90.0
	eyes.refresh()
	checks["cone_90"] = not eyes.sees(behind_foe) and eyes.sees(foes[0]) and eyes.sees(foes[1]) and eyes.sees(foes[2])
	eyes.fov_deg = 360.0
	eyes.refresh()

	foes[0].global_position += Vector3(0.0, 150.0, 0.0)
	eyes.refresh()
	var flat_ok := eyes.sees(foes[0])
	eyes.spherical = true
	eyes.refresh()
	checks["cylinder_flat_sphere_round"] = flat_ok and not eyes.sees(foes[0])
	eyes.spherical = false
	foes[0].global_position = home[foes[0]]
	eyes.refresh()

	var by_groups := _names(eyes.in_sight())
	eyes.use_area = true
	eyes.watching = true
	for _frame in area_frames:
		await get_tree().physics_frame
	eyes.refresh()
	checks["area_same_as_groups"] = _names(eyes.in_sight()) == by_groups
	eyes.use_area = false
	eyes.watching = false

	checks["side_sees_foe"] = VisionSides.sees(1, foes[0]) and not VisionSides.sees(2, seer)
	checks["own_side_always"] = VisionSides.sees(2, foes[0])
	eyes.memory.forget_ticks = 3
	lost_order.clear()
	for body in foes:
		body.global_position += Vector3(900.0, 0.0, 0.0)
	eyes.refresh()
	checks["lost_in_name_order"] = lost_order == _sorted(lost_order) and lost_order.size() == foes.size()
	checks["remembered_for_a_while"] = VisionSides.sees(1, foes[0])
	for _frame in 4:
		await get_tree().physics_frame
	checks["forgotten_after"] = not VisionSides.sees(1, foes[0])
	for body in everyone:
		body.global_position = home[body]
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {"ok": ok, "checks": checks, "in_range": in_range}


static func _names(nodes: Array) -> Array:
	var names := []
	for node: Node in nodes:
		names.append(String(node.name))
	return names


static func _sorted(names: Array) -> Array:
	var copy := names.duplicate()
	copy.sort()
	return copy
