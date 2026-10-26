extends "res://addons/mp_kit/tests/mp_test.gd"

## MpLagComp: a second of poses per node, where it was at a given time, and rewinding the others for a check.


func test_history_and_rewind() -> void:
	MpLagComp.clear()
	var target := Node2D.new()
	var shooter := Node2D.new()
	tree.root.add_child(target)
	tree.root.add_child(shooter)
	for i in 120:
		target.position = Vector2(i * 4.0, 0)
		MpLagComp.record(target, 10.0 + i / 60.0)
		MpLagComp.record(shooter, 10.0 + i / 60.0)
	var now := 10.0 + 119 / 60.0
	var seen: Vector2 = MpLagComp.position_at_like(target, now - 0.5)
	check(absf(seen.x - 4.0 * 89.0) < 0.5, "where the target was half a second ago (%.1f)" % seen.x)
	var mid: Vector2 = MpLagComp.position_at_like(target, 10.0 + 100.5 / 60.0)
	check(absf(mid.x - 402.0) < 0.01, "between two ticks it interpolates")
	var during: Array = []
	var result: Variant = MpLagComp.rewind(now - 0.5, func() -> int:
		during.append(target.position.x)
		return 7, shooter)
	check(result == 7 and absf(during[0] - 356.0) < 0.5, "inside rewind the target stands where it was seen")
	check(target.position.x == 476.0, "after rewind it is back")
	check(MpLagComp.clamp_view(now - 5.0, now) == now - MpLagComp.HISTORY_S, "a view too far back is clamped to the history")
	check(MpLagComp.clamp_view(now + 1.0, now) == now and MpLagComp.clamp_view(0.0, now) == now, "a view ahead or unknown is now")
	MpLagComp.enabled = false
	check((MpLagComp.position_at_like(target, now - 0.5) as Vector2).x == 476.0, "disabled: the present")
	MpLagComp.enabled = true
	target.free()
	shooter.free()
	MpLagComp.clear()


func test_old_poses_are_dropped() -> void:
	MpLagComp.clear()
	var node := Node3D.new()
	for i in 200:
		node.position = Vector3(i, 0, 0)
		MpLagComp.record(node, i / 60.0)
	var oldest: Vector3 = MpLagComp.position_at_like(node, 0.0)
	check(oldest.x >= 199 - 61, "only about HISTORY_S of poses is kept (oldest x %.0f)" % oldest.x)
	node.free()
	MpLagComp.clear()
