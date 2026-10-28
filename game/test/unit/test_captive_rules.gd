extends GutTest
## CaptiveRules.on_change: the look of a creature when a doctor takes it, pumps it or lets it go.

const MODE := UnitBody.Mode
const LOOK := CaptiveRules.Look


func _look(was: UnitBody.Mode, now: UnitBody.Mode, can_hang := true, ragdoll := false) -> int:
	return CaptiveRules.on_change(was, now, can_hang, ragdoll)


func test_death_shows_nothing() -> void:
	assert_eq(_look(MODE.HELD, MODE.DEAD), LOOK.NONE)


func test_taken_hangs_or_plays_clips() -> void:
	assert_eq(_look(MODE.IDLE, MODE.HELD, true), LOOK.HANG)
	assert_eq(_look(MODE.IDLE, MODE.HELD, false), LOOK.CLIPS)


func test_taken_while_reviving_fades_in_hanging() -> void:
	assert_eq(_look(MODE.REVIVING, MODE.HELD, true), LOOK.HANG_APPEAR)
	assert_eq(_look(MODE.REVIVING, MODE.HELD, false), LOOK.CLIPS)


func test_pumping_a_corpse() -> void:
	assert_eq(_look(MODE.DEAD, MODE.REVIVING, true, true), LOOK.KEEP_LYING)
	assert_eq(_look(MODE.DEAD, MODE.REVIVING, true, false), LOOK.STAND_APPEAR)


func test_pumping_a_living_body_plays_clips() -> void:
	assert_eq(_look(MODE.HELD, MODE.REVIVING), LOOK.CLIPS)


func test_revived_body_stands_up() -> void:
	assert_eq(_look(MODE.REVIVING, MODE.IDLE, true, true), LOOK.STAND_APPEAR)
	assert_eq(_look(MODE.REVIVING, MODE.IDLE, true, false), LOOK.LET_GO)


func test_let_go_and_unrelated_changes() -> void:
	assert_eq(_look(MODE.HELD, MODE.IDLE), LOOK.LET_GO)
	assert_eq(_look(MODE.IDLE, MODE.MOVE), LOOK.NONE)
