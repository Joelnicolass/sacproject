extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsUnit: who it belongs to, what it is to a player, and its order queue.

const MOVE := preload("res://addons/rts_kit/commands/commands.tres")


func _unit(slot := 1, team := -1) -> RtsUnit:
	var body := Node3D.new()
	root.add_child(body)
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	unit.team = team
	body.add_child(unit)
	return unit


func _order(command := &"move") -> RtsUnitOrder:
	return RtsUnitOrder.new(MOVE.find(command), null, Vector3.ZERO)


func test_found_from_its_body_and_colliders() -> void:
	var unit := _unit()
	check(RtsUnit.of(unit.body) == unit, "from the body")
	var collider := Node3D.new()
	unit.body.add_child(collider)
	check(RtsUnit.of(collider) == unit, "from a child of the body")
	check(RtsUnit.of(unit) == unit, "from itself")
	var bare := Node3D.new()
	check(RtsUnit.of(bare) == null and RtsUnit.of(null) == null, "nothing")
	bare.free()
	check(RtsUnit.all(tree).has(unit), "in the registry")


func test_relations_and_foes() -> void:
	var mine := _unit(1)
	var ally := _unit(2, 1)
	var enemy := _unit(3)
	var neutral := _unit(0)
	check(mine.relation_to(1, 1) == RtsUnit.OWN, "own")
	check(ally.relation_to(1, 1) == RtsUnit.ALLY, "a teammate's")
	check(enemy.relation_to(1, 1) == RtsUnit.ENEMY, "a foe's")
	check(neutral.relation_to(1, 1) == RtsUnit.NEUTRAL, "nobody's")
	check(mine.is_foe(enemy) and not mine.is_foe(ally) and not mine.is_foe(neutral) and not mine.is_foe(mine), "foes: another team, not neutral")
	check(mine.accepts(&"attack"), "takes everything by default")
	mine.refused = [&"attack"]
	check(not mine.accepts(&"attack") and mine.accepts(&"move"), "refuses what it lists")


func test_the_queue() -> void:
	var unit := _unit()
	var log: Array = []
	unit.order_started.connect(func(o: RtsUnitOrder, replaced: RtsUnitOrder) -> void: log.append(["start", o, replaced]))
	unit.order_ended.connect(func(o: RtsUnitOrder, result: StringName) -> void: log.append(["end", o, result]))
	unit.order_queued.connect(func(o: RtsUnitOrder) -> void: log.append(["queued", o]))
	var first := _order()
	var second := _order(&"attack")
	var third := _order(&"guard")
	check(unit.is_idle(), "idle at first")
	unit.give(first, true)
	check(unit.current_order() == first and log[-1] == ["start", first, null], "queueing on an idle unit starts at once")
	unit.give(second, true)
	unit.give(third, true)
	check(unit.current_order() == first and unit.queued_orders() == [second, third] and second.queued, "the rest wait")
	unit.complete()
	check(log[-2] == ["end", first, &"done"] and unit.current_order() == second, "complete: the next one starts")
	unit.fail(&"blocked")
	check(log[-2] == ["end", second, &"blocked"] and unit.current_order() == third, "fail: the next one starts too")
	unit.complete()
	check(unit.is_idle() and unit.queued_orders().is_empty(), "the queue ran out")
	unit.give(first)
	unit.give(second, true)
	log.clear()
	unit.give(third)
	check(log[0] == ["end", second, &"cancelled"] and log[1] == ["end", first, &"replaced"] and log[2] == ["start", third, first], "a plain order drops the queue and replaces the current one")
	unit.stop()
	check(unit.is_idle() and log[-1] == ["end", third, &"stopped"], "stop")
	unit.complete()
	check(log[-1] == ["end", third, &"stopped"], "complete on an idle unit does nothing")


func test_a_repeat_is_told_apart() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var a := RtsUnitOrder.new(MOVE.find(&"guard"), target, Vector3.ZERO)
	var b := RtsUnitOrder.new(MOVE.find(&"guard"), target, Vector3.ONE)
	var c := RtsUnitOrder.new(MOVE.find(&"guard"), null, Vector3.ONE)
	check(b.is_repeat_of(a) and not c.is_repeat_of(a) and not a.is_repeat_of(null), "same command, same target")


func test_selected_signal_only_on_change() -> void:
	var unit := _unit()
	var seen: Array = []
	unit.selected_changed.connect(func(on: bool) -> void: seen.append(on))
	unit.selected = true
	unit.selected = true
	unit.selected = false
	check(seen == [true, false], "emitted on change only: %s" % [seen])
