extends GutTest
## CreatureType: book order and the walking fliers.


func _library_with(roles: Array[StringName]) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for role in roles:
		var anim := Animation.new()
		anim.length = 1.0
		library.add_animation(role, anim)
	return library


func _creature(run: float, fly: float, roles: Array[StringName]) -> CreatureType:
	var type := CreatureType.new()
	type.run_speed_m_s = run
	type.fly_speed_m_s = fly
	type.clips = _library_with(roles)
	return type


func test_order_key_is_level_then_slot() -> void:
	var type := CreatureType.new()
	type.book_level = 3
	type.book_slot = 7
	assert_eq(type.order_key(), 307)


func test_walks_and_flies_with_a_fly_clip_is_hybrid() -> void:
	assert_true(_creature(5.0, 8.0, [&"run", &"fly"]).is_hybrid_flier())


func test_without_fly_clip_is_not_hybrid() -> void:
	assert_false(_creature(5.0, 8.0, [&"run"]).is_hybrid_flier())


func test_only_walks_or_only_flies_is_not_hybrid() -> void:
	assert_false(_creature(5.0, 0.0, [&"fly"]).is_hybrid_flier())
	assert_false(_creature(0.0, 8.0, [&"fly"]).is_hybrid_flier())
