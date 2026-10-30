extends GutTest
## MatchClock.ticks_for: whole physics ticks that cover a time in seconds.


func test_project_runs_sixty_ticks_per_second() -> void:
	assert_eq(MatchClock.TICKS_PER_SECOND, 60)


func test_exact_seconds() -> void:
	assert_eq(MatchClock.ticks_for(0.5), 30)
	assert_eq(MatchClock.ticks_for(1.0), 60)


func test_a_fraction_of_a_tick_rounds_up() -> void:
	assert_eq(MatchClock.ticks_for(0.501), 31)


func test_zero_and_negative_are_zero() -> void:
	assert_eq(MatchClock.ticks_for(0.0), 0)
	assert_eq(MatchClock.ticks_for(-2.0), 0)
