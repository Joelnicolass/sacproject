extends "res://addons/mp_kit/tests/mp_test.gd"

## The view time travels with each frame (lag compensation rewinds to it); one that is not finite counts as unknown.


func test_view_travels_and_bad_ones_are_unknown() -> void:
	var a := MpInputFrame.sized(2)
	a.view = 12.5
	var b := a.next()
	b.view = 12.5 + 1.0 / 60.0
	var back := MpInputPacket.decode(MpInputPacket.encode([a, b]), 2)
	check(back.size() == 2 and is_equal_approx(back[0].view, 12.5) and absf(back[1].view - b.view) < 0.000001, "the view time travels with each frame")
	check(a.next().view == 12.5, "next() keeps it until the owner samples again")
	var bad := MpInputFrame.sized(2)
	bad.view = INF
	var got := MpInputPacket.decode(MpInputPacket.encode([bad]), 2)
	check(got.size() == 1 and got[0].view == 0.0, "a view time that is not finite counts as unknown")
