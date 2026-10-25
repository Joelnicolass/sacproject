extends "res://addons/mp_kit/tests/mp_test.gd"

## MpNetQuality.Stats: round trip, jitter and loss from pings, against numbers known in advance.


func test_steady_link() -> void:
	var s := MpNetQuality.Stats.new()
	for i in 20:
		s.on_sent(i, i * 0.25)
		s.on_reply(i, i * 0.25 + 0.040)
	check(absf(s.rtt_ms() - 40.0) < 0.5, "a steady 40 ms link measures 40 ms")
	check(s.jitter_ms() < 0.5 and s.loss() == 0.0, "no jitter, no loss")
	check(MpNetQuality.grade_of(s.rtt_ms(), s.jitter_ms(), s.loss()) == MpNetQuality.Grade.GOOD, "graded good")


func test_jitter_and_loss() -> void:
	var s := MpNetQuality.Stats.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		s.on_sent(i, i * 0.25)
		if i % 10 == 0:
			continue
		s.on_reply(i, i * 0.25 + 0.120 + rng.randf() * 0.060)
	s.expire(40 * 0.25 + 2.0)
	check(s.rtt_ms() > 125.0 and s.rtt_ms() < 175.0, "the median round trip is inside 120..180 ms (%.0f)" % s.rtt_ms())
	check(s.jitter_ms() > 15.0 and s.jitter_ms() < 32.0, "jitter about half the 60 ms spread (%.1f)" % s.jitter_ms())
	check(absf(s.loss() - 0.1) < 0.02, "one ping in ten lost (%.2f)" % s.loss())
	check(MpNetQuality.grade_of(s.rtt_ms(), s.jitter_ms(), s.loss()) == MpNetQuality.Grade.BAD, "graded bad")


func test_late_answers_and_percentile() -> void:
	var s := MpNetQuality.Stats.new()
	s.on_sent(1, 0.0)
	check(s.on_reply(9, 0.1) < 0.0, "an answer to a ping never sent is ignored")
	s.expire(2.0)
	check(s.on_reply(1, 2.1) < 0.0 and s.loss() == 1.0, "an expired ping is lost, its late answer ignored")
	var v := PackedFloat64Array([5, 1, 4, 2, 3])
	check(MpNetQuality.percentile(v, 0.5) == 3.0 and MpNetQuality.percentile(v, 1.0) == 5.0 and MpNetQuality.percentile(v, 0.0) == 1.0, "percentiles by nearest rank")
