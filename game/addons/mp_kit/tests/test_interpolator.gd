extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInterpolator: where a proxy is drawn between server states.


func _buffer() -> MpInterpolator:
	var b := MpInterpolator.new()
	b.push(1.0, Vector3(0, 0, 0), Quaternion.IDENTITY)
	b.push(2.0, Vector3(10, 0, 0), Quaternion(Vector3.BACK, PI / 2))
	return b


func test_between_states() -> void:
	var pose := _buffer().sample(1.5)
	check((pose[0] as Vector3).is_equal_approx(Vector3(5, 0, 0)), "halfway in time is halfway in space")
	check(is_equal_approx((pose[1] as Quaternion).get_euler().z, PI / 4), "rotation is blended too")


func test_edges() -> void:
	var b := _buffer()
	check((b.sample(0.0)[0] as Vector3).is_equal_approx(Vector3.ZERO), "before the first state, the first state")
	var ahead: Vector3 = b.sample(2.05)[0]
	check(ahead.is_equal_approx(Vector3(10.5, 0, 0)), "a little past the newest state it keeps going")
	var far: Vector3 = b.sample(10.0)[0]
	check(far.is_equal_approx(Vector3(10 + 10 * b.max_extrapolate_s, 0, 0)), "and then waits (capped extrapolation)")


func test_ignores_old_and_caps() -> void:
	var b := _buffer()
	b.push(1.5, Vector3(99, 0, 0), Quaternion.IDENTITY)
	check(b.size() == 2, "a state older than the newest is ignored")
	for i in MpInterpolator.CAPACITY + 5:
		b.push(3.0 + i, Vector3.ZERO, Quaternion.IDENTITY)
	check(b.size() == MpInterpolator.CAPACITY, "the history is capped")
