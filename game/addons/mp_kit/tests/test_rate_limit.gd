extends "res://addons/mp_kit/tests/mp_test.gd"

## MpRateLimit: a client cannot flood the server; a normal one never notices.


func test_burst_then_rate() -> void:
	var limit := MpRateLimit.new(10.0, 3.0)
	var sent := 0
	for i in 10:
		if limit.allow(5, 1000):
			sent += 1
	check(sent == 3, "a burst passes up to `burst` messages")
	check(not limit.allow(5, 1050), "then it waits for tokens")
	check(limit.allow(5, 1100), "10 per second: one more after 100 ms")


func test_peers_are_apart() -> void:
	var limit := MpRateLimit.new(1.0, 1.0)
	check(limit.allow(5, 0) and not limit.allow(5, 0), "peer 5 spent its token")
	check(limit.allow(6, 0), "peer 6 has its own")
	limit.forget(5)
	check(limit.allow(5, 0), "a forgotten peer starts full again")
