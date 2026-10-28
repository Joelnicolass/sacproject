extends GutTest

const Approach := preload("res://scenes/sacrifice/errand_states/approach.gd")
const REACH := 2.0
const MAX_REACH := 8.0
const TOL := 1.5


func _next(body_at: Vector3, soul_at: Vector3, stand_at: Vector3) -> int:
	return Approach.next_step(body_at, soul_at, stand_at, REACH, MAX_REACH, TOL)


func test_pumps_within_reach_of_the_soul() -> void:
	assert_eq(_next(Vector3(1, 0, 0), Vector3.ZERO, Vector3.ZERO), Approach.Next.PUMP)


func test_walks_while_far_from_a_reachable_soul() -> void:
	assert_eq(_next(Vector3(20, 0, 0), Vector3.ZERO, Vector3.ZERO), Approach.Next.WALK)


func test_walks_toward_the_closest_land_of_a_blocked_soul() -> void:
	# The soul lies 4 m inside a building; the land ends at (4, 0, 0) and the doctor is still far.
	assert_eq(_next(Vector3(20, 0, 0), Vector3.ZERO, Vector3(4, 0, 0)), Approach.Next.WALK)


func test_pumps_from_the_closest_land_of_a_blocked_soul() -> void:
	# It stands where the land ends: before, it asked for the same path again forever.
	assert_eq(_next(Vector3(4.5, 0, 0), Vector3.ZERO, Vector3(4, 0, 0)), Approach.Next.PUMP)


func test_gives_up_on_a_soul_too_deep_inside() -> void:
	assert_eq(_next(Vector3(10.2, 0, 0), Vector3.ZERO, Vector3(10, 0, 0)), Approach.Next.GIVE_UP)


func test_height_does_not_count() -> void:
	assert_eq(_next(Vector3(1, 30, 0), Vector3.ZERO, Vector3.ZERO), Approach.Next.PUMP)
