extends "res://addons/rts_kit/tests/rts_test.gd"

## The formations of the kit's catalog: exact slots for small groups, the shape of big ones.

const CATALOG := preload("res://addons/rts_kit/orders/formations/formations.tres")
const R2 := 1.4142135
const MOVE := RtsCommandType.Role.MOVE
const ATTACK := RtsCommandType.Role.ATTACK
const GUARD := RtsCommandType.Role.GUARD


func _slots(id: StringName, count: int, spacing: float, around := 0.0, role := MOVE) -> Array[Vector2]:
	return CATALOG.find(id).slots(count, spacing, around, role)


func _all_near(got: Array[Vector2], want: Array, what: String) -> void:
	var ok := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		ok = ok and near(got[i], want[i], 0.001)
	check(ok, "%s: %s" % [what, got])


func test_catalog() -> void:
	var ids: Array[StringName] = []
	for formation in CATALOG.formations:
		ids.append(formation.id)
	check(ids == [&"line", &"flank_left", &"flank_right", &"phalanx", &"semicircle", &"circle", &"wedge", &"skirmish"], "menu order: %s" % [ids])
	check(CATALOG.default_formation().id == &"line", "the default is the line")
	check(CATALOG.find(&"nope") == null and not CATALOG.has_id(&"nope"), "an unknown id")


func test_line() -> void:
	_all_near(_slots(&"line", 1, 2.0), [Vector2(0, 0)], "one unit on the point")
	_all_near(_slots(&"line", 5, 2.0), [Vector2(-4, 0), Vector2(-2, 0), Vector2(0, 0), Vector2(2, 0), Vector2(4, 0)], "five centered, left to right")
	var thirteen := _slots(&"line", 13, 2.0)
	check(near(thirteen[0], Vector2(-11, 0)) and near(thirteen[11], Vector2(11, 0)), "twelve in the first row")
	check(near(thirteen[12], Vector2(0, -2)), "the 13th alone, centered, one row back")
	var crowd := _slots(&"line", 150, 2.0)
	var rows := {}
	for slot in crowd:
		rows[slot.y] = int(rows.get(slot.y, 0)) + 1
	check(crowd.size() == 150 and rows.size() == 13 and int(rows[0.0]) == 12 and int(rows[-24.0]) == 6, "150: 13 rows, the last of 6")
	var line := CATALOG.find(&"line")
	check(line.row_count(150) == 13 and line.match_row_size(150) == 12 and line.match_row_size(5) == 5, "row count and row match size")
	check(near(line.row_width(5, 2.0), 8.0), "row width")


func test_line_guarding_opens_around_the_body() -> void:
	# Odd row: the left half steps out by the target distance, the right half by (distance - spacing).
	var guard := _slots(&"line", 3, 2.0, 3.0, GUARD)
	_all_near(guard, [Vector2(-5, 0), Vector2(-3, 0), Vector2(3, 0)], "three around a guarded body")
	var even := _slots(&"line", 4, 2.0, 3.0, GUARD)
	_all_near(even, [Vector2(-5, 0), Vector2(-3, 0), Vector2(3, 0), Vector2(5, 0)], "four around it")


func test_flanks() -> void:
	_all_near(_slots(&"flank_left", 3, 2.0), [Vector2(-6, 0), Vector2(-4, 0), Vector2(-2, 0)], "the left flank stands left of the point")
	_all_near(_slots(&"flank_right", 3, 2.0), [Vector2(2, 0), Vector2(4, 0), Vector2(6, 0)], "the right flank right of it")
	_all_near(_slots(&"flank_left", 2, 2.0, 5.0, MOVE), [Vector2(-7, 0), Vector2(-5, 0)], "a target pushes a flank out")
	_all_near(_slots(&"flank_left", 2, 2.0, 5.0, ATTACK), [Vector2(-4, 0), Vector2(-2, 0)], "but not on an attack")


func test_phalanx_and_skirmish() -> void:
	var phalanx := _slots(&"phalanx", 8, 2.0)
	check(near(phalanx[0], Vector2(-3, 0)) and near(phalanx[3], Vector2(3, 0)) and near(phalanx[4], Vector2(-3, -2)), "rows of four")
	var behind := _slots(&"phalanx", 4, 2.0, 3.0, GUARD)
	check(near(behind[0].y, -(6.0 + 3.0)), "guarding: behind the body (guard_back + distance)")
	var skirmish := _slots(&"skirmish", 4, 2.0)
	var dist := 0.5 * R2 * 2.0
	_all_near(skirmish, [Vector2(-3, 0), Vector2(-1, -dist), Vector2(1, 0), Vector2(3, -dist)], "every other one half a step back")
	check(CATALOG.find(&"skirmish").match_row_size(10) == 0, "a staggered line matches greedily")


func test_arcs() -> void:
	var r := 4.0 / PI
	_all_near(_slots(&"semicircle", 3, 2.0), [Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0)], "a semicircle behind the point")
	_all_near(_slots(&"semicircle", 1, 2.0), [Vector2(0, -1)], "one unit: half a spacing behind")
	var circle := _slots(&"circle", 4, 2.0)
	var rc := 8.0 / TAU
	_all_near(circle, [Vector2(-rc, 0), Vector2(0, -rc), Vector2(rc, 0), Vector2(0, rc)], "a circle")
	var wide := _slots(&"circle", 4, 2.0, 5.0)
	check(near(wide[0].length(), 5.0), "a circle opens to the target distance")


func test_wedge() -> void:
	var a := 0.5 * R2
	var tip := 3.0 * a
	_all_near(_slots(&"wedge", 5, 1.0), [Vector2(-2 * a, tip - 2 * a), Vector2(-a, tip - a), Vector2(0, tip), Vector2(a, tip - a), Vector2(2 * a, tip - 2 * a)], "a V, its tip ahead")
	var attack := _slots(&"wedge", 3, 1.0, 0.0, ATTACK)
	check(near(attack[1], Vector2(0, 0)), "attacking: the tip on the point")
