extends GutTest
## CastTime.seconds: 10 % off per wizard level above the entry (at most 5), in frames of 1/81 s.


func _creature(casting_time_s: float, book_level: int, tag := "test") -> CreatureType:
	var type := CreatureType.new()
	type.casting_time_s = casting_time_s
	type.book_level = book_level
	type.tag = tag
	return type


func test_null_entry_takes_no_time() -> void:
	assert_eq(CastTime.seconds(null, 3), 0.0)


func test_no_bonus_keeps_the_exported_time() -> void:
	assert_eq(CastTime.seconds(_creature(1.234, 2), 2), 1.234)
	assert_eq(CastTime.seconds(_creature(1.234, 2), 1), 1.234)


func test_each_level_above_takes_ten_percent_off() -> void:
	# 2 s = 162 frames; two levels above: (1620 - 324) / 10 = 129 frames.
	assert_almost_eq(CastTime.seconds(_creature(2.0, 1), 3), 129.0 / 81.0, 1e-6)


func test_bonus_stops_at_five_levels() -> void:
	# 162 frames, five levels off: 81 frames = 1 s, the same at level 5 and level 9.
	assert_almost_eq(CastTime.seconds(_creature(2.0, 0), 5), 1.0, 1e-6)
	assert_almost_eq(CastTime.seconds(_creature(2.0, 0), 9), 1.0, 1e-6)
	assert_eq(CastTime.bonus_levels(_creature(2.0, 0), 9), 5)


func test_basilisk_casts_in_nineteen_twentieths() -> void:
	# 162 frames * 19 / 20 = 153 frames, even with no level bonus.
	var basilisk := _creature(2.0, 1)
	basilisk.cast_time_factor = 0.95
	assert_almost_eq(CastTime.seconds(basilisk, 1), 153.0 / 81.0, 1e-6)


func test_frames_rounds_the_seconds() -> void:
	assert_eq(CastTime.frames(_creature(2.0, 1), 3), 129)
