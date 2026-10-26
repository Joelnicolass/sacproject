extends RefCounted

## RFC-057 057b cases of terrain_cases: bodies go up AND down with the ground. A Trogg 5 m from the middle of a quake-like sink
## (4 m down and back in 0.5 s, faster than the floor snap follows) stays on the land every tick and is neither thrown nor flying;
## a body 5 m from a meteorite's dent stands on the new ground in the same tick; a body 3 m above the land (on a roof) does not move.
## The sink is a stamp of its own (the shape of the Quake's rebound), so the case does not wait on the Quake's scene. It borrows the
## world of TerrainCases (`cases`): its bed, its makers of bodies and its checks.

const METEOR := preload("res://scenes/spells/drops/meteor.tscn")
## A vertex of the lattice on land, away from the other cases' spots.
const CENTER := Vector2(1260.0, 1270.0)
const SINK_REACH_M := 50.0
const SINK_DEPTH_M := 4.0
const SINK_S := 0.5
## The ground is put back over the vertices within this of the dent.
const PUT_BACK_M := 20.0

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"carry_quake": _quake, "carry_dent": _dent, "carry_roof": _roof}


## A Trogg 5 m from the middle while the land sinks 4 m and comes back: |y - height_at| <= 0.5 m on every tick.
func _quake() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var at := CENTER + Vector2(5.0, 0.0)
	var trogg: UnitBody = _c._unit("ycro", Vector3(at.x, shape.height_at(at.x, at.y) + 0.1, at.y), 3)
	await _c._frames(10)
	var base := shape.height_at(trogg.global_position.x, trogg.global_position.z)
	var base_center := shape.height_at(CENTER.x, CENTER.y)
	var profile := _sink()
	var ticks := int(SINK_S * MatchClock.TICKS_PER_SECOND_F)
	var lag := 0.0
	var deepest := 0.0
	var loose := false
	for tick in ticks:
		shape.stamp(&"carry_quake", profile, CENTER, SINK_REACH_M, -SINK_DEPTH_M, float(tick) / MatchClock.TICKS_PER_SECOND_F)
		await _c._frames(1)
		var spot := trogg.global_position
		var ground := shape.height_at(spot.x, spot.z)
		lag = maxf(lag, absf(spot.y - ground))
		deepest = maxf(deepest, base - ground)
		loose = loose or trogg.is_flying() or BodyNudge.tumbling_of(trogg).is_on()
	shape.unstamp(&"carry_quake")
	await _c._frames(2)
	_c._note("carry quake lag / deepest", [lag, deepest])
	checks["the_land_sank_3m"] = deepest > 3.0
	checks["stays_on_the_land"] = lag <= 0.5
	checks["not_thrown_nor_flying"] = not loose
	checks["ground_back"] = shape.field().live_count() == 0 and absf(shape.height_at(CENTER.x, CENTER.y) - base_center) < 0.01
	trogg.queue_free()
	await _c._frames(2)
	return _c._verdict("carry_quake", checks)


## A body standing on the land 5 m from a dent is on the new ground in the same tick (no physics step between).
func _dent() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var at := CENTER + Vector2(5.0, 0.0)
	var ground := shape.height_at(at.x, at.y)
	var body: UnitBody = _c._tough(Vector3(at.x, ground, at.y), 3)
	var before := shape.field().permanent.duplicate()
	_dent_at(shape, CENTER)
	var now := shape.height_at(at.x, at.y)
	_c._note("carry dent y / ground before / after", [body.global_position.y, ground, now])
	checks["the_land_sank"] = now < ground - 0.5
	checks["on_the_new_ground"] = absf(body.global_position.y - now) <= 0.05
	body.queue_free()
	await _put_back(shape, before)
	return _c._verdict("carry_dent", checks)


## A body 3 m above the land (on a roof or another body) stays where it is when a dent sinks the land under it.
func _roof() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var at := CENTER + Vector2(-5.0, 0.0)
	var high := shape.height_at(at.x, at.y) + 3.0
	var body: UnitBody = _c._tough(Vector3(at.x, high, at.y), 3)
	var before := shape.field().permanent.duplicate()
	_dent_at(shape, CENTER)
	checks["the_land_sank"] = shape.height_at(at.x, at.y) < high - 3.5
	checks["roof_body_stays"] = absf(body.global_position.y - high) <= 0.01
	body.queue_free()
	await _put_back(shape, before)
	return _c._verdict("carry_roof", checks)


## The meteorite's own dent (its stamp and Reach), kept at `spot` through the API.
func _dent_at(shape: Terrain, spot: Vector2) -> void:
	var meteor := METEOR.instantiate() as Node3D
	var stamp := meteor.get_node("Dent") as TerrainStamp
	var cylinder := (stamp.get_node("Reach") as CollisionShape3D).shape as CylinderShape3D
	shape.keep_stamp(&"", stamp.profile, spot, cylinder.radius, cylinder.height)
	meteor.free()


## What stays goes back to `before` over the vertices the dent touched.
func _put_back(shape: Terrain, before: PackedFloat32Array) -> void:
	var rect := TerrainGrid.vertex_rect(CENTER, PUT_BACK_M)
	var restore := PackedFloat32Array()
	restore.resize(rect.get_area())
	for row in rect.size.y:
		for column in rect.size.x:
			var id := TerrainGrid.id_of(rect.position + Vector2i(column, row))
			restore[row * rect.size.x + column] = before[id] - shape.field().permanent[id]
	_c._keep(shape, CENTER, PUT_BACK_M, restore)
	await _c._frames(2)


## The shape of the Quake's rebound: (1 + cos(pi x)) / 2 across, sin(pi t / 0.5 s) in time; the peak is negative (it sinks).
func _sink() -> StampProfile:
	var profile := StampProfile.new()
	profile.radial = Curve.new()
	profile.timeline = Curve.new()
	profile.timeline.max_domain = SINK_S
	for step in 11:
		var share := float(step) / 10.0
		profile.radial.add_point(Vector2(share, (1.0 + cos(PI * share)) * 0.5))
		profile.timeline.add_point(Vector2(share * SINK_S, sin(PI * share)))
	return profile
