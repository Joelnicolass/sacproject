extends "res://addons/mp_kit/tests/mp_test.gd"

## The view time travels with the frame; packets of an older client (no view) still work.


func test_view_travels_and_old_packets_work() -> void:
	var a := MpInputFrame.sized(2)
	a.view = 12.5
	var b := MpInputFrame.unpack(a.pack(), 2)
	check(b != null and is_equal_approx(b.view, 12.5), "the view time travels with the frame")
	check(a.next().view == 12.5, "next() keeps it until the owner samples again")
	var old := a.pack().slice(0, 5)
	var c := MpInputFrame.unpack(old, 2)
	check(c != null and c.view == 0.0, "a packet without the view time (an older client) is accepted, view 0")
	var bad := a.pack()
	bad[5] = "x"
	check(MpInputFrame.unpack(bad, 2) == null, "a view time of the wrong type is refused")
	bad[5] = INF
	var d := MpInputFrame.unpack(bad, 2)
	check(d != null and d.view == 0.0, "a view time that is not finite counts as unknown")
