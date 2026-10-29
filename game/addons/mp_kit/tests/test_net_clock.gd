extends "res://addons/mp_kit/tests/mp_test.gd"

## MpNetClock: the offset to the server clock follows the least-delayed packet.


func test_offset_follows_fast_packets() -> void:
	MpNetClock.reset()
	var now := MpNetClock.local_time()
	MpNetClock.observe(now + 100.0)
	check(MpNetClock.is_known() and absf(MpNetClock.offset() - 100.0) < 0.05, "the first stamp sets the offset")
	MpNetClock.observe(MpNetClock.local_time() + 100.2)
	check(absf(MpNetClock.offset() - 100.2) < 0.05, "a less delayed packet moves it up at once")
	MpNetClock.observe(MpNetClock.local_time() + 99.9)
	check(MpNetClock.offset() > 100.15, "a slow packet does not drag it down")
	MpNetClock.observe(MpNetClock.local_time() + 50.0)
	check(absf(MpNetClock.offset() - 50.0) < 0.05, "a much lower offset (another server) resets it")
	MpNetClock.reset()
